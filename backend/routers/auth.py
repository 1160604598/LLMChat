from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta
from typing import List
from .. import crud, models, schemas, auth
from ..utils import logger

router = APIRouter(
    prefix="/auth",
    tags=["auth"],
)

@router.post("/register", response_model=schemas.User)
def register(user: schemas.UserCreate, request: Request, db: Session = Depends(auth.get_db)):
    db_user = crud.get_user_by_username(db, username=user.username)
    if db_user:
        logger.log_audit(
            db, 
            event_type="REGISTER", 
            status="FAILURE", 
            details={"username": user.username, "reason": "Username already registered"},
            request=request
        )
        raise HTTPException(status_code=400, detail="Username already registered")
    
    new_user = crud.create_user(db=db, user=user)
    logger.log_audit(
        db, 
        event_type="REGISTER", 
        status="SUCCESS", 
        user_id=new_user.id,
        target_type="USER",
        target_id=new_user.id,
        details={"username": user.username},
        request=request
    )
    return new_user

@router.post("/token", response_model=schemas.Token)
def login_for_access_token(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(), 
    db: Session = Depends(auth.get_db)
):
    user = crud.get_user_by_username(db, username=form_data.username)
    if not user or not auth.verify_password(form_data.password, user.hashed_password):
        # Log failure (without user_id if not found, or with user_id if password wrong)
        user_id = user.id if user else None
        logger.log_audit(
            db, 
            event_type="LOGIN", 
            status="FAILURE", 
            user_id=user_id,
            details={"username": form_data.username, "reason": "Incorrect username or password"},
            request=request
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token_expires = timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    
    logger.log_audit(
        db, 
        event_type="LOGIN", 
        status="SUCCESS", 
        user_id=user.id,
        request=request
    )
    
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/logout")
def logout(
    request: Request,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    logger.log_audit(
        db, 
        event_type="LOGOUT", 
        status="SUCCESS", 
        user_id=current_user.id,
        request=request
    )
    return {"status": "success"}

@router.get("/me", response_model=schemas.User)
async def read_users_me(current_user: models.User = Depends(auth.get_current_user)):
    return current_user

@router.put("/config", response_model=schemas.User)
async def update_config(
    config: schemas.UserUpdateConfig, 
    request: Request,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    updated_user = crud.update_user_config(db, current_user, config)
    logger.log_audit(
        db, 
        event_type="UPDATE_CONFIG", 
        status="SUCCESS", 
        user_id=current_user.id,
        target_type="USER",
        target_id=current_user.id,
        details=config.dict(exclude_unset=True),
        request=request
    )
    return updated_user

@router.post("/models", response_model=schemas.ModelConfig)
def create_model_config(
    config: schemas.ModelConfigCreate,
    request: Request,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    new_config = crud.create_model_config(db, config, current_user.id)
    logger.log_audit(
        db, 
        event_type="CREATE_MODEL_CONFIG", 
        status="SUCCESS", 
        user_id=current_user.id,
        target_type="MODEL_CONFIG",
        target_id=new_config.id,
        details=config.dict(),
        request=request
    )
    return new_config

@router.get("/models", response_model=List[schemas.ModelConfig])
def get_model_configs(
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    return crud.get_model_configs(db, current_user.id)

@router.put("/models/reorder", response_model=List[schemas.ModelConfig])
def reorder_model_configs(
    orders: List[schemas.ModelConfigOrder],
    request: Request,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    result = crud.update_model_config_orders(db, orders, current_user.id)
    logger.log_audit(
        db, 
        event_type="REORDER_MODEL_CONFIGS", 
        status="SUCCESS", 
        user_id=current_user.id,
        details={"orders": [o.dict() for o in orders]},
        request=request
    )
    return result

@router.put("/models/{config_id}", response_model=schemas.ModelConfig)
def update_model_config(
    config_id: int,
    config: schemas.ModelConfigCreate,
    request: Request,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    db_config = crud.update_model_config(db, config_id, config, current_user.id)
    if not db_config:
        logger.log_audit(
            db, 
            event_type="UPDATE_MODEL_CONFIG", 
            status="FAILURE", 
            user_id=current_user.id,
            target_type="MODEL_CONFIG",
            target_id=config_id,
            details={"config": config.dict(), "reason": "Config not found"},
            request=request
        )
        raise HTTPException(status_code=404, detail="Config not found")
    
    logger.log_audit(
        db, 
        event_type="UPDATE_MODEL_CONFIG", 
        status="SUCCESS", 
        user_id=current_user.id,
        target_type="MODEL_CONFIG",
        target_id=config_id,
        details=config.dict(),
        request=request
    )
    return db_config

@router.delete("/models/{config_id}", response_model=schemas.ModelConfig)
def delete_model_config(
    config_id: int,
    request: Request,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    result = crud.delete_model_config(db, config_id, current_user.id)
    if not result:
        # Assuming crud.delete_model_config raises error or returns None if not found
        # But looking at previous code, it might return the deleted object or raise
        pass
        
    logger.log_audit(
        db, 
        event_type="DELETE_MODEL_CONFIG", 
        status="SUCCESS", 
        user_id=current_user.id,
        target_type="MODEL_CONFIG",
        target_id=config_id,
        request=request
    )
    return result
