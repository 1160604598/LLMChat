from fastapi import APIRouter
from pydantic import BaseModel
import json
import os

router = APIRouter(
    prefix="/system",
    tags=["system"],
)

class UpdateInfo(BaseModel):
    version: str
    build_number: int
    changelog: str
    download_url_android: str
    download_url_windows: str
    force_update: bool

CONFIG_FILE = "backend/update_config.json"

@router.get("/check-update", response_model=UpdateInfo)
async def check_update():
    # Load config dynamically from file
    config = {}
    # Use absolute path or relative to main.py execution
    # Try multiple paths to be safe
    possible_paths = [
        "backend/update_config.json", 
        "update_config.json",
        os.path.join(os.path.dirname(__file__), "..", "update_config.json")
    ]
    
    loaded = False
    for path in possible_paths:
        if os.path.exists(path):
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                    loaded = True
                    break
            except Exception as e:
                print(f"Error reading config file {path}: {e}")
    
    if not loaded:
        print("Warning: update_config.json not found in any expected location.")
            
    # Default fallback values
    return UpdateInfo(
        version=config.get("version", "1.0.0"),
        build_number=config.get("build_number", 0),
        changelog=config.get("changelog", "No changes"),
        download_url_android=config.get("download_url_android", ""),
        download_url_windows=config.get("download_url_windows", ""),
        force_update=config.get("force_update", False)
    )
