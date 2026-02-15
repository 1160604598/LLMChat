from fastapi import FastAPI
from . import models, database
from .routers import auth, chat, system
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

models.Base.metadata.create_all(bind=database.engine)

app = FastAPI()

# Create static directory if it doesn't exist
os.makedirs("backend/static", exist_ok=True)
app.mount("/static", StaticFiles(directory="backend/static"), name="static")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(chat.router)
app.include_router(system.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to LLMChat API"}
