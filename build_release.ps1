# Build Script for LLM Chat Windows Distribution
# Run this script in PowerShell

Write-Host "Building LLM Chat for Windows..." -ForegroundColor Cyan

# 0. Fix PATH (Expand %SystemRoot% if present)
$env:PATH = $env:PATH -replace "%SystemRoot%", "C:\Windows" -replace "%SYSTEMROOT%", "C:\Windows"

# 1. Create dist directory
$distDir = "$PSScriptRoot\dist"
if (Test-Path $distDir) {
    Remove-Item $distDir -Recurse -Force
}
New-Item -ItemType Directory -Path $distDir | Out-Null
Write-Host "Created dist directory at $distDir" -ForegroundColor Green

# 2. Build Backend
Write-Host "`n[1/3] Building Backend (Python/FastAPI)..." -ForegroundColor Yellow
cd backend
# Check if pyinstaller is installed
if (-not (Get-Command "pyinstaller" -ErrorAction SilentlyContinue)) {
    Write-Host "Installing PyInstaller..."
    pip install pyinstaller
}

# Build executable
pyinstaller --onefile --clean --name "llm_chat_server" `
    --paths .. `
    --hidden-import=uvicorn.logging `
    --hidden-import=uvicorn.loops `
    --hidden-import=uvicorn.loops.auto `
    --hidden-import=uvicorn.protocols `
    --hidden-import=uvicorn.protocols.http `
    --hidden-import=uvicorn.protocols.http.auto `
    --hidden-import=uvicorn.lifespan `
    --hidden-import=uvicorn.lifespan.on `
    --hidden-import=sqlalchemy.sql.default_comparator `
    --hidden-import=passlib.handlers.bcrypt `
    --hidden-import=python_multipart `
    --hidden-import=jose `
    --collect-all=sqlalchemy `
    --collect-all=passlib `
    run_server.py

# Move backend exe to dist
if (Test-Path "dist\llm_chat_server.exe") {
    Move-Item "dist\llm_chat_server.exe" "$distDir\"
    Write-Host "Backend built successfully." -ForegroundColor Green
} else {
    Write-Host "Backend build failed!" -ForegroundColor Red
}
cd ..

# 3. Build Frontend
Write-Host "`n[2/3] Building Frontend (Flutter)..." -ForegroundColor Yellow
cd frontend

# Set Chinese mirror
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

# Setup PATH
# Add Flutter
$flutterBin = "C:\tools\flutter\bin"
if (Test-Path $flutterBin) {
    $env:PATH = "$flutterBin;$flutterBin\cache\dart-sdk\bin;" + $env:PATH
}
# Add VS 2026 CMake
$vsCmake = "D:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
if (Test-Path $vsCmake) {
    $env:PATH = "$vsCmake;" + $env:PATH
}

# Check Environment
flutter doctor

# Build
Write-Host "Starting Flutter Build..."
# We use --verbose to see errors if it fails
flutter build windows --release --verbose

if ($LASTEXITCODE -eq 0) {
    # Copy build artifacts
    $buildDir = "build\windows\x64\runner\Release"
    if (-not (Test-Path $buildDir)) {
        $buildDir = "build\windows\runner\Release"
    }
    
    if (Test-Path $buildDir) {
        Copy-Item "$buildDir\*" "$distDir\" -Recurse -Force
        
        # Verify and fix missing dependencies (common issue with some build envs)
        $dllSrc = "$PSScriptRoot\frontend\windows\flutter\ephemeral\flutter_windows.dll"
        if (-not (Test-Path "$distDir\flutter_windows.dll") -and (Test-Path $dllSrc)) {
             Write-Host "Manually copying flutter_windows.dll..." -ForegroundColor Yellow
             Copy-Item $dllSrc "$distDir\" -Force
        }
        
        $dataDir = "$distDir\data"
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir | Out-Null
        }
        
        $icuSrc = "$PSScriptRoot\frontend\windows\flutter\ephemeral\icudtl.dat"
        if (-not (Test-Path "$dataDir\icudtl.dat") -and (Test-Path $icuSrc)) {
             Write-Host "Manually copying icudtl.dat..." -ForegroundColor Yellow
             Copy-Item $icuSrc "$dataDir\" -Force
        }
        
        $assetsSrc = "$PSScriptRoot\frontend\build\flutter_assets"
        if (-not (Test-Path "$dataDir\flutter_assets") -and (Test-Path $assetsSrc)) {
             Write-Host "Manually copying flutter_assets..." -ForegroundColor Yellow
             Copy-Item $assetsSrc "$dataDir\" -Recurse -Force
        }
        
        $appSoSrc = "$PSScriptRoot\frontend\build\windows\app.so"
        if (-not (Test-Path "$dataDir\app.so") -and (Test-Path $appSoSrc)) {
             Write-Host "Manually copying app.so..." -ForegroundColor Yellow
             Copy-Item $appSoSrc "$dataDir\" -Force
        }

        Write-Host "Frontend built and copied." -ForegroundColor Green
    } else {
        Write-Host "Error: Build succeeded but output directory not found at $buildDir" -ForegroundColor Red
    }
} else {
    Write-Host "Frontend build failed." -ForegroundColor Red
    Write-Host "If the error is 'Visual Studio not found', it might be because VS 2026 is not supported by this Flutter version."
    Write-Host "Trying manual CMake build as fallback..."
    
    # Fallback: Manual CMake Build
    # This is risky but might work if the issue is just Flutter's VS detection
    try {
        Write-Host "Attempting manual CMake build..."
        $env:CMAKE_GENERATOR = "Visual Studio 18 2026"
        
        # We need to ensure ephemeral files are generated.
        # 'flutter build windows' might have failed BUT generated the config?
        # If not, we might need to run 'flutter assemble' manually.
        
        # Try running cmake directly
        cmake -S windows -B build/windows/x64 -G "Visual Studio 18 2026" -A x64 -DFLUTTER_TARGET_PLATFORM=windows-x64
        cmake --build build/windows/x64 --config Release
        cmake --install build/windows/x64 --config Release --prefix "$distDir\install"
        
        if (Test-Path "$distDir\install") {
             Copy-Item "$distDir\install\*" "$distDir\" -Recurse -Force
             Write-Host "Manual CMake build succeeded!" -ForegroundColor Green
        }
    } catch {
        Write-Host "Manual CMake build also failed: $_" -ForegroundColor Red
    }
}
cd ..

# 4. Create Launcher Script
Write-Host "`n[3/3] Creating Launcher Script..." -ForegroundColor Yellow
$launcherContent = @"
@echo off
start "" "llm_chat_server.exe"
echo Starting Backend Server...
timeout /t 2 >nul
start "" "llm_chat.exe"
"@
Set-Content -Path "$distDir\start_app.bat" -Value $launcherContent

Write-Host "`nBuild Process Finished." -ForegroundColor Cyan
