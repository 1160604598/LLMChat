# 打包 Web 发布文件
$releaseDir = "web_release"
if (Test-Path $releaseDir) {
    Remove-Item $releaseDir -Recurse -Force
}
New-Item -ItemType Directory -Path $releaseDir | Out-Null

# 1. 复制 Web 前端文件
$webSource = "frontend/build/web"
if (-not (Test-Path $webSource)) {
    Write-Host "Error: Frontend web build not found. Please run 'flutter build web --release' first." -ForegroundColor Red
    exit 1
}
New-Item -ItemType Directory -Path "$releaseDir/www" | Out-Null
Copy-Item "$webSource/*" "$releaseDir/www" -Recurse -Force

# 2. 创建简单的 Web 服务器脚本 (Python)
# 注意：Here-String 的结束标记 '@ 必须顶格，不能有缩进
$pyServerContent = @'
import http.server
import socketserver
import os
import sys

# Default Port
PORT = 8080

# Web Root Directory
if getattr(sys, 'frozen', False):
    # Running as compiled executable
    application_path = os.path.dirname(sys.executable)
else:
    # Running as script
    application_path = os.path.dirname(os.path.abspath(__file__))

WEB_DIR = os.path.join(application_path, 'www')

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        # Disable cache
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

try:
    print(f"Starting Web Server...")
    print(f"Root Directory: {WEB_DIR}")
    
    # Allow address reuse
    socketserver.TCPServer.allow_reuse_address = True
    
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"\n✅ Web Server running at: http://localhost:{PORT}")
        print(f"   (Network IP: http://0.0.0.0:{PORT})")
        print("\nPress Ctrl+C to stop the server.")
        httpd.serve_forever()
except OSError as e:
    print(f"\n❌ Error starting server on port {PORT}: {e}")
    print("Tip: The port might be in use. Try changing the PORT variable in this script.")
    input("Press Enter to exit...")
except KeyboardInterrupt:
    print("\nServer stopped.")
'@

$pyServerContent | Set-Content -Path "$releaseDir/start_web_client.py" -Encoding UTF8

# 3. 尝试使用 PyInstaller 打包 Python 脚本为 exe
if (Get-Command "pyinstaller" -ErrorAction SilentlyContinue) {
    Write-Host "PyInstaller found. Building standalone executable..." -ForegroundColor Yellow
    Push-Location $releaseDir
    try {
        pyinstaller --onefile --clean --name start_web_client start_web_client.py
        
        if (Test-Path "dist/start_web_client.exe") {
            Move-Item "dist/start_web_client.exe" "." -Force
            Remove-Item "build" -Recurse -Force
            Remove-Item "dist" -Recurse -Force
            Remove-Item "start_web_client.spec" -Force
            Write-Host "Standalone executable created: start_web_client.exe" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Error during PyInstaller build: $_" -ForegroundColor Red
    }
    finally {
        Pop-Location
    }
} else {
    Write-Host "PyInstaller not found. Skipping executable build." -ForegroundColor Yellow
    Write-Host "To build .exe, install PyInstaller: pip install pyinstaller" -ForegroundColor Gray
}

# 4. 创建说明文档
$readmeContent = @'
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
     Click the **Settings Icon (⚙️)** in the top right.
     Enter your backend API URL in "Server URL".
     Example: `http://192.168.1.100:8000`
     Click "Save".
'@

$readmeContent | Set-Content -Path "$releaseDir/README.txt" -Encoding UTF8

Write-Host "Web release package created in '$releaseDir'" -ForegroundColor Green
Write-Host "You can now copy the '$releaseDir' folder to your offline server." -ForegroundColor Cyan
