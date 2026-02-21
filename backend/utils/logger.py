import json
import traceback
from datetime import datetime
from fastapi import Request
from sqlalchemy.orm import Session
from .. import models

def log_audit(
    db: Session,
    event_type: str,
    status: str,
    user_id: int = None,
    target_type: str = None,
    target_id: int = None,
    details: dict = None,
    request: Request = None,
    request_id: str = None
):
    ip_address = None
    user_agent = None
    if request:
        ip_address = request.client.host if request.client else None
        user_agent = request.headers.get("user-agent")

    audit_log = models.AuditLog(
        request_id=request_id,
        user_id=user_id,
        event_type=event_type,
        target_type=target_type,
        target_id=target_id,
        status=status,
        ip_address=ip_address,
        user_agent=user_agent,
        details=json.dumps(details) if details else None,
        created_at=datetime.utcnow()
    )
    db.add(audit_log)
    db.commit()
    db.refresh(audit_log)
    return audit_log

def log_llm_usage(
    db: Session,
    user_id: int,
    model_name: str,
    provider: str,
    endpoint_url: str,
    request_headers: dict,
    request_payload: dict,
    start_time: datetime,
    end_time: datetime,
    status_code: int,
    conversation_id: int = None,
    message_id: int = None,
    response_headers: dict = None,
    response_payload: str = None, # JSON string or raw text
    prompt_tokens: int = 0,
    completion_tokens: int = 0,
    total_tokens: int = 0,
    error_message: str = None,
    stack_trace: str = None,
    request_id: str = None
):
    duration_ms = int((end_time - start_time).total_seconds() * 1000)
    
    llm_log = models.LLMUsageLog(
        request_id=request_id,
        user_id=user_id,
        conversation_id=conversation_id,
        message_id=message_id,
        model_name=model_name,
        provider=provider,
        endpoint_url=endpoint_url,
        request_headers=json.dumps(request_headers) if request_headers else None,
        request_payload=json.dumps(request_payload) if request_payload else None,
        response_headers=json.dumps(response_headers) if response_headers else None,
        response_payload=response_payload,
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
        total_tokens=total_tokens,
        start_time=start_time,
        end_time=end_time,
        duration_ms=duration_ms,
        status_code=status_code,
        error_message=error_message,
        stack_trace=stack_trace
    )
    db.add(llm_log)
    db.commit()
    db.refresh(llm_log)
    return llm_log
