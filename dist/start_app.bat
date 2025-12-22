@echo off
start "" "llm_chat_server.exe"
echo Starting Backend Server...
timeout /t 2 >nul
start "" "llm_chat.exe"
