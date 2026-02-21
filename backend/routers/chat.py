from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from typing import List
import httpx
import json
import uuid
import traceback
from datetime import datetime
from .. import crud, models, schemas, auth, database
from ..utils import logger

router = APIRouter(
    prefix="/chat",
    tags=["chat"],
)

@router.post("/conversations", response_model=schemas.Conversation)
def create_conversation(
    conversation: schemas.ConversationCreate, 
    request: Request,
    db: Session = Depends(auth.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    new_conversation = crud.create_conversation(db, conversation, current_user.id)
    logger.log_audit(
        db, 
        event_type="CREATE_CONVERSATION", 
        status="SUCCESS", 
        user_id=current_user.id,
        target_type="CONVERSATION",
        target_id=new_conversation.id,
        details={"title": conversation.title},
        request=request
    )
    return new_conversation

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
    request: Request,
    db: Session = Depends(auth.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    conversation = crud.get_conversation(db, conversation_id)
    if conversation is None or conversation.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Conversation not found")
    crud.delete_conversation(db, conversation_id)
    
    logger.log_audit(
        db, 
        event_type="DELETE_CONVERSATION", 
        status="SUCCESS", 
        user_id=current_user.id,
        target_type="CONVERSATION",
        target_id=conversation_id,
        request=request
    )
    return {"status": "success"}

@router.post("/stream")
async def stream_chat(
    chat_request: schemas.ChatRequest,
    request: Request,
    db: Session = Depends(auth.get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    request_id = str(uuid.uuid4())
    start_time = datetime.utcnow()
    
    # Determine config
    if chat_request.llm_config:
        base_url = chat_request.llm_config.model_base_url
        api_key = chat_request.llm_config.model_api_key
        model_name = chat_request.llm_config.model_name
        model_provider = chat_request.llm_config.model_provider
    else:
        base_url = current_user.model_base_url
        api_key = current_user.model_api_key
        model_name = current_user.model_name
        model_provider = current_user.model_provider

    if not base_url:
         raise HTTPException(status_code=400, detail="Model Base URL not configured")

    # If conversation_id is provided, save user message
    if chat_request.conversation_id:
        conversation = crud.get_conversation(db, chat_request.conversation_id)
        if not conversation or conversation.user_id != current_user.id:
             raise HTTPException(status_code=404, detail="Conversation not found")
        crud.create_message(db, schemas.MessageCreate(role="user", content=chat_request.message), chat_request.conversation_id)
        
        history = crud.get_messages(db, chat_request.conversation_id)
        messages_payload = [{"role": msg.role, "content": msg.content} for msg in history]
    else:
        messages_payload = [{"role": "user", "content": chat_request.message}]

    # Prepare external API request
    headers = {
        "Content-Type": "application/json",
    }
    
    payload = {
        "model": model_name,
        "stream": True,
        "stream_options": {"include_usage": True} # Try to get usage info if supported
    }

    if model_provider == "Anthropic":
        if api_key:
            headers["x-api-key"] = api_key
        headers["anthropic-version"] = "2023-06-01"
        
        system_message = None
        filtered_messages = []
        for msg in messages_payload:
            if msg['role'] == 'system':
                system_message = msg['content']
            else:
                filtered_messages.append(msg)
        
        if system_message:
            payload['system'] = system_message
            
        if not filtered_messages:
            filtered_messages.append({"role": "user", "content": "Hello"})
        elif filtered_messages[0]['role'] != 'user':
            filtered_messages.insert(0, {"role": "user", "content": "..."})
            
        payload['messages'] = filtered_messages
        
        if "claude-3-7" in model_name or "thinking" in model_name:
             payload['max_tokens'] = 16384
             payload['thinking'] = {
                "type": "enabled",
                "budget_tokens": 8192
             }
        else:
             payload['max_tokens'] = 4096
    else:
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"
        payload["messages"] = messages_payload

    # Variables for logging
    request_headers_log = headers.copy()
    request_payload_log = payload.copy()
    target_url = ""

    async def event_generator():
        nonlocal target_url
        full_response = ""
        full_reasoning = ""
        response_status_code = 0
        response_headers_log = {}
        error_occurred = None
        stack_trace = None
        
        # Token usage from stream
        prompt_tokens = 0
        completion_tokens = 0
        total_tokens = 0

        client = httpx.AsyncClient(timeout=600.0)
        try:
            if model_provider == "Anthropic":
                target_url = f"{base_url.rstrip('/')}/messages"
            else:
                target_url = f"{base_url.rstrip('/')}/chat/completions"
            
            async with client.stream("POST", target_url, headers=headers, json=payload) as response:
                response_status_code = response.status_code
                response_headers_log.update(dict(response.headers))
                
                if response.status_code != 200:
                    error_msg = await response.aread()
                    error_text = f"Error: {response.status_code} - {error_msg.decode()}"
                    error_occurred = error_text
                    
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
                                        chunk = {
                                            "choices": [{"delta": {"content": text}}]
                                        }
                                        yield f"data: {json.dumps(chunk)}\n\n".encode()
                                    elif delta.get("type") == "thinking_delta":
                                        thinking = delta.get("thinking", "")
                                        full_reasoning += thinking
                                        chunk = {
                                            "choices": [{"delta": {"reasoning_content": thinking}}]
                                        }
                                        yield f"data: {json.dumps(chunk)}\n\n".encode()
                                elif data.get("type") == "message_stop":
                                    yield f"data: [DONE]\n\n".encode()
                                elif data.get("type") == "message_start":
                                    # Try to get usage from message_start if available
                                    usage = data.get("message", {}).get("usage", {})
                                    prompt_tokens = usage.get("input_tokens", 0)
                                elif data.get("type") == "message_delta":
                                    # Try to get usage from message_delta
                                    usage = data.get("usage", {})
                                    completion_tokens = usage.get("output_tokens", 0)
                                elif data.get("type") == "error":
                                    error_text = f"Error: {data.get('error', {}).get('message', 'Unknown error')}"
                                    error_occurred = error_text
                                    chunk = {
                                        "choices": [{"delta": {"content": error_text}}]
                                    }
                                    yield f"data: {json.dumps(chunk)}\n\n".encode()
                            except json.JSONDecodeError:
                                continue
                    else:
                        if line.startswith("data: "):
                            yield f"{line}\n\n".encode()
                            
                            data_str = line[6:]
                            if data_str.strip() == "[DONE]":
                                break
                            try:
                                data = json.loads(data_str)
                                
                                # Try to capture usage from OpenAI format
                                if "usage" in data and data["usage"]:
                                    usage = data["usage"]
                                    prompt_tokens = usage.get("prompt_tokens", prompt_tokens)
                                    completion_tokens = usage.get("completion_tokens", completion_tokens)
                                    total_tokens = usage.get("total_tokens", total_tokens)

                                if "choices" in data and len(data["choices"]) > 0:
                                    delta = data["choices"][0].get("delta", {})
                                    if "content" in delta and delta["content"] is not None:
                                        full_response += delta["content"]
                                    if "reasoning_content" in delta and delta["reasoning_content"] is not None:
                                        full_reasoning += delta["reasoning_content"]
                            except json.JSONDecodeError:
                                continue
        except Exception as e:
            error_occurred = str(e)
            stack_trace = traceback.format_exc()
            error_json = json.dumps({"error": str(e)})
            yield f"data: {error_json}\n\n".encode()
        finally:
            await client.aclose()
            end_time = datetime.utcnow()
            
            # Calculate total tokens if not provided
            if total_tokens == 0:
                total_tokens = prompt_tokens + completion_tokens

            # Save assistant message
            assistant_message_id = None
            if chat_request.conversation_id and (full_response or full_reasoning):
                new_db = database.SessionLocal()
                try:
                    msg = crud.create_message(new_db, schemas.MessageCreate(
                        role="assistant", 
                        content=full_response,
                        reasoning_content=full_reasoning if full_reasoning else None
                    ), chat_request.conversation_id)
                    assistant_message_id = msg.id
                except Exception:
                    pass # Log saving error?
                finally:
                    new_db.close()
            
            # Log usage
            new_db = database.SessionLocal()
            try:
                logger.log_llm_usage(
                    db=new_db,
                    user_id=current_user.id,
                    model_name=model_name,
                    provider=model_provider,
                    endpoint_url=target_url,
                    request_headers=request_headers_log,
                    request_payload=request_payload_log,
                    start_time=start_time,
                    end_time=end_time,
                    status_code=response_status_code,
                    conversation_id=chat_request.conversation_id,
                    message_id=assistant_message_id,
                    response_headers=response_headers_log,
                    response_payload=full_response, # We store the accumulated text content, not the raw SSE chunks
                    prompt_tokens=prompt_tokens,
                    completion_tokens=completion_tokens,
                    total_tokens=total_tokens,
                    error_message=error_occurred,
                    stack_trace=stack_trace,
                    request_id=request_id
                )
            except Exception as e:
                # Last resort error logging, maybe print to stderr
                print(f"Failed to write usage log: {e}")
            finally:
                new_db.close()

    return StreamingResponse(event_generator(), media_type="text/event-stream")
