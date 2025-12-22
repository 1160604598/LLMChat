from sqlalchemy.orm import Session
from . import models, schemas, auth

def get_user(db: Session, user_id: int):
    return db.query(models.User).filter(models.User.id == user_id).first()

def get_user_by_username(db: Session, username: str):
    return db.query(models.User).filter(models.User.username == username).first()

def create_user(db: Session, user: schemas.UserCreate):
    hashed_password = auth.get_password_hash(user.password)
    db_user = models.User(username=user.username, hashed_password=hashed_password)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def update_user_config(db: Session, user: models.User, config: schemas.UserUpdateConfig):
    if config.model_base_url is not None:
        user.model_base_url = config.model_base_url
    if config.model_api_key is not None:
        user.model_api_key = config.model_api_key
    if config.model_name is not None:
        user.model_name = config.model_name
    db.commit()
    db.refresh(user)
    return user

def create_conversation(db: Session, conversation: schemas.ConversationCreate, user_id: int):
    db_conversation = models.Conversation(**conversation.dict(), user_id=user_id)
    db.add(db_conversation)
    db.commit()
    db.refresh(db_conversation)
    return db_conversation

def get_conversations(db: Session, user_id: int, skip: int = 0, limit: int = 100):
    return db.query(models.Conversation).filter(models.Conversation.user_id == user_id).offset(skip).limit(limit).all()

def get_conversation(db: Session, conversation_id: int):
    return db.query(models.Conversation).filter(models.Conversation.id == conversation_id).first()

def delete_conversation(db: Session, conversation_id: int):
    db_conversation = db.query(models.Conversation).filter(models.Conversation.id == conversation_id).first()
    if db_conversation:
        db.delete(db_conversation)
        db.commit()
    return db_conversation

def create_message(db: Session, message: schemas.MessageCreate, conversation_id: int):
    db_message = models.Message(**message.dict(), conversation_id=conversation_id)
    db.add(db_message)
    db.commit()
    db.refresh(db_message)
    return db_message

def get_messages(db: Session, conversation_id: int):
    return db.query(models.Message).filter(models.Message.conversation_id == conversation_id).all()
