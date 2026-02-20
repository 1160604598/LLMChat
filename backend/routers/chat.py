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

@router.delete("/conversations/{conversation_id}")
def delete_conversation(
    conversation_id: int,
    db: Session = Depends(auth.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    conversation = crud.get_conversation(db, conversation_id)
    if conversation is None or conversation.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Conversation not found")
    crud.delete_conversation(db, conversation_id)
    return {"status": "success"}

@router.post("/stream")
async def stream_chat(
    request: schemas.ChatRequest,
    db: Session = Depends(auth.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    # Determine config
    # If llm_config is present, we use it. We assume the client sends a complete valid config or nothing.
    # Note: request.llm_config is a Pydantic model UserUpdateConfig where fields are Optional.
    # But when selecting a specific model config in frontend, we send all fields.
    
    if request.llm_config:
        # Use request config, defaulting to None/Empty if missing in the request object (but keys should be there)
        # We assume the user wants to use EXACTLY what's in llm_config
        base_url = request.llm_config.model_base_url
        api_key = request.llm_config.model_api_key
        model_name = request.llm_config.model_name
        model_provider = request.llm_config.model_provider
    else:
        # Fallback to user default config
        base_url = current_user.model_base_url
        api_key = current_user.model_api_key
        model_name = current_user.model_name
        model_provider = current_user.model_provider

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
    
    payload = {
        "model": model_name,
        "stream": True
    }

    if model_provider == "Anthropic":
        if api_key:
            headers["x-api-key"] = api_key
        headers["anthropic-version"] = "2023-06-01"
        
        # Anthropic separates system prompt
        system_message = None
        filtered_messages = []
        for msg in messages_payload:
            if msg['role'] == 'system':
                system_message = msg['content']
            else:
                filtered_messages.append(msg)
        
        if system_message:
            payload['system'] = system_message
            
        # Ensure at least one message is present and starts with user
        if not filtered_messages:
            filtered_messages.append({"role": "user", "content": "Hello"})
        elif filtered_messages[0]['role'] != 'user':
            # Insert a dummy user message if the first message is not user (e.g. only assistant history)
            filtered_messages.insert(0, {"role": "user", "content": "..."})
            
        payload['messages'] = filtered_messages
        
        # Enable thinking if model supports it (e.g. claude-3-7-sonnet or explicit "thinking" in name)
        # Using a budget of 8192 tokens for thinking
        if "claude-3-7" in model_name or "thinking" in model_name:
             payload['max_tokens'] = 16384
             payload['thinking'] = {
                "type": "enabled",
                "budget_tokens": 8192
             }
        else:
             payload['max_tokens'] = 4096
    else:
        # Default to OpenAI
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"
        payload["messages"] = messages_payload

    async def event_generator():
        full_response = ""
        full_reasoning = ""
        client = httpx.AsyncClient(timeout=600.0)
        try:
            # Handle potential trailing slash in base_url
            if model_provider == "Anthropic":
                url = f"{base_url.rstrip('/')}/messages"
            else:
                url = f"{base_url.rstrip('/')}/chat/completions"
            
            # If the user provided a full URL including /chat/completions, use it directly?
            # Standard OpenAI base_url usually ends with /v1
            # Let's assume the user configures the BASE URL (e.g. https://api.openai.com/v1)
            
            async with client.stream("POST", url, headers=headers, json=payload) as response:
                if response.status_code != 200:
                    error_msg = await response.aread()
                    error_text = f"Error: {response.status_code} - {error_msg.decode()}"
                    # Send error as a content chunk so it appears in the chat
                    chunk = {
                        "choices": [{"delta": {"content": error_text}}]
                    }
                    yield f"data: {json.dumps(chunk)}\n\n".encode()
                    return

                async for line in response.aiter_lines():
                    if model_provider == "Anthropic":
                        if line.startswith("data:"):
                            data_str = line[5:].strip()
                            try:
                                data = json.loads(data_str)
                                if data.get("type") == "content_block_delta":
                                    delta = data.get("delta", {})
                                    if delta.get("type") == "text_delta":
                                        text = delta.get("text", "")
                                        full_response += text
                                        # Convert to OpenAI format
                                        chunk = {
                                            "choices": [{"delta": {"content": text}}]
                                        }
                                        yield f"data: {json.dumps(chunk)}\n\n".encode()
                                    elif delta.get("type") == "thinking_delta":
                                        thinking = delta.get("thinking", "")
                                        full_reasoning += thinking
                                        # Convert to OpenAI reasoning_content format
                                        chunk = {
                                            "choices": [{"delta": {"reasoning_content": thinking}}]
                                        }
                                        yield f"data: {json.dumps(chunk)}\n\n".encode()
                                elif data.get("type") == "message_stop":
                                    yield f"data: [DONE]\n\n".encode()
                                elif data.get("type") == "error":
                                    # Handle Anthropic specific error event if any
                                    error_text = f"Error: {data.get('error', {}).get('message', 'Unknown error')}"
                                    chunk = {
                                        "choices": [{"delta": {"content": error_text}}]
                                    }
                                    yield f"data: {json.dumps(chunk)}\n\n".encode()
                            except json.JSONDecodeError:
                                continue
                    else:
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
                                    
                                    # Pass through content
                                    if "content" in delta and delta["content"] is not None:
                                        full_response += delta["content"]
                                        
                                    # Pass through reasoning_content (DeepSeek R1 etc)
                                    if "reasoning_content" in delta and delta["reasoning_content"] is not None:
                                        full_reasoning += delta["reasoning_content"]
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
            if request.conversation_id and (full_response or full_reasoning):
                new_db = database.SessionLocal()
                try:
                    crud.create_message(new_db, schemas.MessageCreate(
                        role="assistant", 
                        content=full_response,
                        reasoning_content=full_reasoning if full_reasoning else None
                    ), request.conversation_id)
                finally:
                    new_db.close()

    return StreamingResponse(event_generator(), media_type="text/event-stream")
