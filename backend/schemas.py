from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class MessageBase(BaseModel):
    role: str
    content: str

class MessageCreate(MessageBase):
    pass

class Message(MessageBase):
    id: int
    created_at: datetime
    conversation_id: int

    class Config:
        orm_mode = True

class ConversationBase(BaseModel):
    title: str

class ConversationCreate(ConversationBase):
    pass

class Conversation(ConversationBase):
    id: int
    created_at: datetime
    user_id: int
    messages: List[Message] = []

    class Config:
        orm_mode = True

class UserBase(BaseModel):
    username: str

class UserCreate(UserBase):
    password: str

class UserUpdateConfig(BaseModel):
    model_base_url: Optional[str] = None
    model_api_key: Optional[str] = None
    model_name: Optional[str] = None

class User(UserBase):
    id: int
    model_base_url: Optional[str]
    model_api_key: Optional[str]
    model_name: Optional[str]
    conversations: List[Conversation] = []

    class Config:
        orm_mode = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None

class ChatRequest(BaseModel):
    message: str
    conversation_id: Optional[int] = None
    llm_config: Optional[UserUpdateConfig] = Field(default=None, alias="model_config") # Optional override
