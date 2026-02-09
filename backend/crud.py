from sqlalchemy.orm import Session
from . import models, schemas, auth
import os
import json

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

    # Check for DefaultUserModelsConfig.json
    config_path = "DefaultUserModelsConfig.json"
    if os.path.exists(config_path):
        try:
            with open(config_path, 'r', encoding='utf-8') as f:
                configs = json.load(f)
                if isinstance(configs, list):
                    for config_data in configs:
                        # Create model config from file data
                        # We map fields directly. Ensure JSON keys match model attributes or schema.
                        new_config = models.ModelConfig(
                            user_id=db_user.id,
                            name=config_data.get('name', 'Default'),
                            base_url=config_data.get('base_url', ''),
                            api_key=config_data.get('api_key', ''),
                            model_name=config_data.get('model_name', ''),
                            provider=config_data.get('provider', 'Other')
                        )
                        db.add(new_config)
                    db.commit()
                    # db.refresh(db_user) # Not strictly necessary unless we access db_user.model_configs immediately
        except Exception as e:
            print(f"Error loading default model configs: {e}")

    return db_user

def update_user_config(db: Session, user: models.User, config: schemas.UserUpdateConfig):
    if config.model_base_url is not None:
        user.model_base_url = config.model_base_url
    if config.model_api_key is not None:
        user.model_api_key = config.model_api_key
    if config.model_name is not None:
        user.model_name = config.model_name
    if config.model_provider is not None:
        user.model_provider = config.model_provider
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

def create_model_config(db: Session, config: schemas.ModelConfigCreate, user_id: int):
    db_config = models.ModelConfig(**config.dict(), user_id=user_id)
    db.add(db_config)
    db.commit()
    db.refresh(db_config)
    return db_config

def get_model_configs(db: Session, user_id: int):
    return db.query(models.ModelConfig).filter(models.ModelConfig.user_id == user_id).order_by(models.ModelConfig.display_order.asc(), models.ModelConfig.id.asc()).all()

def update_model_config(db: Session, config_id: int, config: schemas.ModelConfigCreate, user_id: int):
    db_config = db.query(models.ModelConfig).filter(models.ModelConfig.id == config_id, models.ModelConfig.user_id == user_id).first()
    if db_config:
        db_config.name = config.name
        db_config.base_url = config.base_url
        db_config.api_key = config.api_key
        db_config.model_name = config.model_name
        db_config.provider = config.provider
        db.commit()
        db.refresh(db_config)
    return db_config

def delete_model_config(db: Session, config_id: int, user_id: int):
    db_config = db.query(models.ModelConfig).filter(models.ModelConfig.id == config_id, models.ModelConfig.user_id == user_id).first()
    if db_config:
        db.delete(db_config)
        db.commit()
    return db_config

def update_model_config_orders(db: Session, orders: list[schemas.ModelConfigOrder], user_id: int):
    # This could be optimized, but loop is fine for small number of configs
    for order in orders:
        db_config = db.query(models.ModelConfig).filter(models.ModelConfig.id == order.id, models.ModelConfig.user_id == user_id).first()
        if db_config:
            db_config.display_order = order.display_order
    db.commit()
    return get_model_configs(db, user_id)
