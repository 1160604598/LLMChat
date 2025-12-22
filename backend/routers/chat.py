from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from typing import List
import httpx
import json
from .. import crud, models, schemas, auth, database

router = APIRouter(
    prefix="/chat",
    tags=["chat"],
)

@router.post("/conversations", response_model=schemas.Conversation)
def create_conversation(
    conversation: schemas.ConversationCreate, 
    db: Session = Depends(auth.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    return crud.create_conversation(db, conversation, current_user.id)

@router.get("/conversations", response_model=List[schemas.Conversation])
def get_conversations(
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(auth.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    return crud.get_conversations(db, current_user.id, skip, limit)

@router.get("/conversations/{conversation_id}", response_model=schemas.Conversation)
def get_conversation(
    conversation_id: int, 
    db: Session = Depends(auth.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    conversation = crud.get_conversation(db, conversation_id)
    if conversation is None or conversation.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return conversation

@router.post("/stream")
async def stream_chat(
    request: schemas.ChatRequest,
    db: Session = Depends(auth.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    # Determine config (use request config if provided, else user config)
    base_url = request.llm_config.model_base_url if request.llm_config and request.llm_config.model_base_url else current_user.model_base_url
    api_key = request.llm_config.model_api_key if request.llm_config and request.llm_config.model_api_key else current_user.model_api_key
    model_name = request.llm_config.model_name if request.llm_config and request.llm_config.model_name else current_user.model_name

    if not base_url:
         raise HTTPException(status_code=400, detail="Model Base URL not configured")

    # If conversation_id is provided, save user message
    if request.conversation_id:
        conversation = crud.get_conversation(db, request.conversation_id)
        if not conversation or conversation.user_id != current_user.id:
             raise HTTPException(status_code=404, detail="Conversation not found")
        crud.create_message(db, schemas.MessageCreate(role="user", content=request.message), request.conversation_id)
        
        # Load history? For simplicity, we might just send the current message or last N messages.
        # Let's send history.
        history = crud.get_messages(db, request.conversation_id)
        messages_payload = [{"role": msg.role, "content": msg.content} for msg in history]
        # Ensure the last message is the new one (it is, because we just saved it)
    else:
        # Temporary chat without saving? Or create new?
        # Requirement says "save dialogue". So we should probably require conversation_id or create one.
        # But for now let's handle the case where it's just a request.
        messages_payload = [{"role": "user", "content": request.message}]

    # Prepare external API request
    headers = {
        "Content-Type": "application/json",
    }
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    payload = {
        "model": model_name,
        "messages": messages_payload,
        "stream": True
    }

    async def event_generator():
        full_response = ""
        client = httpx.AsyncClient(timeout=60.0)
        try:
            # Handle potential trailing slash in base_url
            url = f"{base_url.rstrip('/')}/chat/completions"
            
            # If the user provided a full URL including /chat/completions, use it directly?
            # Standard OpenAI base_url usually ends with /v1
            # Let's assume the user configures the BASE URL (e.g. https://api.openai.com/v1)
            
            async with client.stream("POST", url, headers=headers, json=payload) as response:
                if response.status_code != 200:
                    error_msg = await response.aread()
                    yield f"Error: {response.status_code} - {error_msg.decode()}".encode()
                    return

                async for line in response.aiter_lines():
                    if line.startswith("data: "):
                        # Pass through the raw data line including "data: " prefix
                        # This maintains the OpenAI SSE format
                        yield f"{line}\n\n".encode()
                        
                        data_str = line[6:]
                        if data_str.strip() == "[DONE]":
                            break
                        try:
                            data = json.loads(data_str)
                            if "choices" in data and len(data["choices"]) > 0:
                                delta = data["choices"][0].get("delta", {})
                                if "content" in delta:
                                    full_response += delta["content"]
                        except json.JSONDecodeError:
                            continue
        except Exception as e:
            # Return error in SSE format or plain text?
            # Frontend expects stream. Let's send a custom error event or just text.
            # But we promised OpenAI format.
            error_json = json.dumps({"error": str(e)})
            yield f"data: {error_json}\n\n".encode()
        finally:
            await client.aclose()
            # Save assistant message if conversation_id exists
            if request.conversation_id and full_response:
                new_db = database.SessionLocal()
                try:
                    crud.create_message(new_db, schemas.MessageCreate(role="assistant", content=full_response), request.conversation_id)
                finally:
                    new_db.close()

    return StreamingResponse(event_generator(), media_type="text/event-stream")
