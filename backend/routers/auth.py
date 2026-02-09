from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta
from typing import List
from .. import crud, models, schemas, auth

router = APIRouter(
    prefix="/auth",
    tags=["auth"],
)

@router.post("/register", response_model=schemas.User)
def register(user: schemas.UserCreate, db: Session = Depends(auth.get_db)):
    db_user = crud.get_user_by_username(db, username=user.username)
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    return crud.create_user(db=db, user=user)

@router.post("/token", response_model=schemas.Token)
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(auth.get_db)):
    user = crud.get_user_by_username(db, username=form_data.username)
    if not user or not auth.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@router.get("/me", response_model=schemas.User)
async def read_users_me(current_user: models.User = Depends(auth.get_current_user)):
    return current_user

@router.put("/config", response_model=schemas.User)
async def update_config(
    config: schemas.UserUpdateConfig, 
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    return crud.update_user_config(db, current_user, config)

@router.post("/models", response_model=schemas.ModelConfig)
def create_model_config(
    config: schemas.ModelConfigCreate,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    return crud.create_model_config(db, config, current_user.id)

@router.get("/models", response_model=List[schemas.ModelConfig])
def get_model_configs(
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    return crud.get_model_configs(db, current_user.id)

@router.put("/models/reorder", response_model=List[schemas.ModelConfig])
def reorder_model_configs(
    orders: List[schemas.ModelConfigOrder],
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    return crud.update_model_config_orders(db, orders, current_user.id)

@router.put("/models/{config_id}", response_model=schemas.ModelConfig)
def update_model_config(
    config_id: int,
    config: schemas.ModelConfigCreate,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    db_config = crud.update_model_config(db, config_id, config, current_user.id)
    if not db_config:
        raise HTTPException(status_code=404, detail="Config not found")
    return db_config

@router.delete("/models/{config_id}", response_model=schemas.ModelConfig)
def delete_model_config(
    config_id: int,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    return crud.delete_model_config(db, config_id, current_user.id)
