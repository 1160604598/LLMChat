# LLM Chat Web Offline Deployment Guide (Frontend Only)

This directory contains the Web frontend files, which can be run directly on an offline server.

## Directory Structure
- www/                  : Frontend web files (HTML/JS/WASM)
- start_web_client.exe  : Executable to start web server (listens on 8080)
- start_web_client.py   : Source script (reference only)

## Deployment Steps

1. **Preparation**
   - Ensure the backend API service is running (note its IP and port, e.g., `http://192.168.1.100:8000`).

2. **Start Web Service**
   - **Method A: Use exe (Recommended)**
     Double-click `start_web_client.exe`.
     (It starts a simple Web Server on port 8080)

   - **Method B: Use Nginx**
     Copy contents of `www` to Nginx root (e.g., `/usr/share/nginx/html`).

3. **Access & Configure**
   - Open `http://localhost:8080` in browser.
   - **Important Configuration**:
     Click the **Settings Icon (鈿欙笍)** in the top right.
     Enter your backend API URL in "Server URL".
     Example: `http://192.168.1.100:8000`
     Click "Save".
