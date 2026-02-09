from sqlalchemy import Boolean, Column, ForeignKey, Integer, String, Text, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from .database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    
    # Store model config as JSON string or individual fields
    # Simple approach: Store base_url and api_key
    model_base_url = Column(String, default="https://api.openai.com/v1")
    model_api_key = Column(String, default="")
    model_name = Column(String, default="gpt-3.5-turbo")
    model_provider = Column(String, default="OpenAI")

    conversations = relationship("Conversation", back_populates="owner")
    model_configs = relationship("ModelConfig", back_populates="owner", cascade="all, delete-orphan", order_by="ModelConfig.display_order")

class ModelConfig(Base):
    __tablename__ = "model_configs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String, default="Default")
    base_url = Column(String)
    api_key = Column(String)
    model_name = Column(String)
    provider = Column(String) # OpenAI, Anthropic, Ollama, Custom
    display_order = Column(Integer, default=0)
    
    owner = relationship("User", back_populates="model_configs")

class Conversation(Base):
    __tablename__ = "conversations"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, default="New Chat")
    created_at = Column(DateTime, default=datetime.utcnow)
    user_id = Column(Integer, ForeignKey("users.id"))
    model_config_id = Column(Integer, ForeignKey("model_configs.id"), nullable=True)

    owner = relationship("User", back_populates="conversations")
    model_config = relationship("ModelConfig")
    messages = relationship("Message", back_populates="conversation", cascade="all, delete-orphan")

class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    role = Column(String) # user, assistant, system
    content = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    conversation_id = Column(Integer, ForeignKey("conversations.id"))

    conversation = relationship("Conversation", back_populates="messages")
