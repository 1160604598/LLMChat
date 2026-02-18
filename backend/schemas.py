from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class MessageBase(BaseModel):
    role: str
    content: str
    reasoning_content: Optional[str] = None

class MessageCreate(MessageBase):
    pass

class Message(MessageBase):
    id: int
    created_at: datetime
    conversation_id: int

    class Config:
        from_attributes = True

class ConversationBase(BaseModel):
    title: str
    model_config_id: Optional[int] = None

class ConversationCreate(ConversationBase):
    pass

class Conversation(ConversationBase):
    id: int
    created_at: datetime
    user_id: int
    messages: List[Message] = []

    class Config:
        from_attributes = True

class UserBase(BaseModel):
    username: str

class UserCreate(UserBase):
    password: str

class UserUpdateConfig(BaseModel):
    model_base_url: Optional[str] = None
    model_api_key: Optional[str] = None
    model_name: Optional[str] = None
    model_provider: Optional[str] = None

class ModelConfigBase(BaseModel):
    name: str
    base_url: str
    api_key: Optional[str] = None
    model_name: str
    provider: str

class ModelConfigCreate(ModelConfigBase):
    pass

class ModelConfig(ModelConfigBase):
    id: int
    user_id: int
    display_order: int = 0

    class Config:
        from_attributes = True

class ModelConfigOrder(BaseModel):
    id: int
    display_order: int

class User(UserBase):
    id: int
    model_base_url: Optional[str]
    model_api_key: Optional[str]
    model_name: Optional[str]
    model_provider: Optional[str]
    conversations: List[Conversation] = []
    model_configs: List[ModelConfig] = []

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None

class ChatRequest(BaseModel):
    message: str
    conversation_id: Optional[int] = None
    llm_config: Optional[UserUpdateConfig] = Field(default=None, alias="model_config") # Optional override
