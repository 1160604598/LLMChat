# LLM Chat Windows 发行版构建脚本
# 请在 PowerShell 中运行此脚本

Write-Host "Building LLM Chat Windows Release..." -ForegroundColor Cyan

# 0. 修复 PATH (如果存在 %SystemRoot%，展开它)
$env:PATH = $env:PATH -replace "%SystemRoot%", "C:\Windows" -replace "%SYSTEMROOT%", "C:\Windows"

# 1. 创建 dist 目录
$distDir = "$PSScriptRoot\dist"
if (Test-Path $distDir) {
    Remove-Item $distDir -Recurse -Force
}
New-Item -ItemType Directory -Path $distDir | Out-Null
Write-Host "Dist directory created: $distDir" -ForegroundColor Green

# 2. 构建后端
Write-Host "`n[1/3] Building Backend (Python/FastAPI)..." -ForegroundColor Yellow
cd backend
# 检查是否安装了 pyinstaller
if (-not (Get-Command "pyinstaller" -ErrorAction SilentlyContinue)) {
    Write-Host "Installing PyInstaller..."
    pip install pyinstaller
}

# 构建可执行文件
$pyinstallerArgs = @(
    "--onefile",
    "--clean",
    "--name", "llm_chat_server",
    "--paths", "..",
    "--hidden-import=uvicorn.logging",
    "--hidden-import=uvicorn.loops",
    "--hidden-import=uvicorn.loops.auto",
    "--hidden-import=uvicorn.protocols",
    "--hidden-import=uvicorn.protocols.http",
    "--hidden-import=uvicorn.protocols.http.auto",
    "--hidden-import=uvicorn.lifespan",
    "--hidden-import=uvicorn.lifespan.on",
    "--hidden-import=sqlalchemy.sql.default_comparator",
    "--hidden-import=passlib.handlers.bcrypt",
    "--hidden-import=python_multipart",
    "--hidden-import=jose",
    "--collect-all=sqlalchemy",
    "--collect-all=passlib",
    "run_server.py"
)

Write-Host "Running PyInstaller..."
& pyinstaller $pyinstallerArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "PyInstaller failed!" -ForegroundColor Red
    exit 1
}

# 移动后端 exe 到 dist
if (Test-Path "dist\llm_chat_server.exe") {
    Move-Item "dist\llm_chat_server.exe" "$distDir\"
    Write-Host "Backend build successful." -ForegroundColor Green
} else {
    Write-Host "Backend build failed!" -ForegroundColor Red
}
cd ..

# 3. 构建前端
Write-Host "`n[2/3] Building Frontend (Flutter)..." -ForegroundColor Yellow
cd frontend

# 设置中国镜像源
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

# 设置 PATH
# 添加 Flutter
$flutterBin = "C:\tools\flutter\bin"
if (Test-Path $flutterBin) {
    $env:PATH = "$flutterBin;$flutterBin\cache\dart-sdk\bin;" + $env:PATH
}
# 添加 VS 2026 CMake (如果存在)
$vsCmake = "D:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
if (Test-Path $vsCmake) {
    $env:PATH = "$vsCmake;" + $env:PATH
}

# 检查环境
flutter doctor

# 构建
Write-Host "Start Flutter build..."
# 使用 --verbose 查看错误详情
flutter build windows --release --verbose

if ($LASTEXITCODE -eq 0) {
    # 复制构建产物
    $buildDir = "build\windows\x64\runner\Release"
    if (-not (Test-Path $buildDir)) {
        $buildDir = "build\windows\runner\Release"
    }
    
    if (Test-Path $buildDir) {
        Copy-Item "$buildDir\*" "$distDir\" -Recurse -Force
        
        # 验证并修复缺失的依赖 (某些构建环境的常见问题)
        $dllSrc = "$PSScriptRoot\frontend\windows\flutter\ephemeral\flutter_windows.dll"
        if (-not (Test-Path "$distDir\flutter_windows.dll") -and (Test-Path $dllSrc)) {
             Write-Host "Manual copy flutter_windows.dll..." -ForegroundColor Yellow
             Copy-Item $dllSrc "$distDir\" -Force
        }
        
        $dataDir = "$distDir\data"
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir | Out-Null
        }
        
        $icuSrc = "$PSScriptRoot\frontend\windows\flutter\ephemeral\icudtl.dat"
        if (-not (Test-Path "$dataDir\icudtl.dat") -and (Test-Path $icuSrc)) {
             Write-Host "Manual copy icudtl.dat..." -ForegroundColor Yellow
             Copy-Item $icuSrc "$dataDir\" -Force
        }
        
        $assetsSrc = "$PSScriptRoot\frontend\build\flutter_assets"
        if (-not (Test-Path "$dataDir\flutter_assets") -and (Test-Path $assetsSrc)) {
             Write-Host "Manual copy flutter_assets..." -ForegroundColor Yellow
             Copy-Item $assetsSrc "$dataDir\" -Recurse -Force
        }
        
        $appSoSrc = "$PSScriptRoot\frontend\build\windows\app.so"
        if (-not (Test-Path "$dataDir\app.so") -and (Test-Path $appSoSrc)) {
             Write-Host "Manual copy app.so..." -ForegroundColor Yellow
             Copy-Item $appSoSrc "$dataDir\" -Force
        }

        Write-Host "Frontend build and copy completed." -ForegroundColor Green
    } else {
        Write-Host "Error: Build successful but output directory not found: $buildDir" -ForegroundColor Red
    }
} else {
    Write-Host "Frontend build failed." -ForegroundColor Red
    Write-Host "If the error is 'Visual Studio not found', it might be because this Flutter version doesn't support VS 2026."
    Write-Host "Trying manual CMake build as a fallback..."
    
    # 后备方案: 手动 CMake 构建
    # 这有风险，但如果问题仅仅是 Flutter 的 VS 检测机制，这可能会奏效
    try {
        Write-Host "Try manual CMake build..."
        $env:CMAKE_GENERATOR = "Visual Studio 18 2026"
        
        # 我们需要确保 ephemeral 文件已生成。
        # 'flutter build windows' 可能失败了，但生成了配置？
        # 如果没有，我们可能需要手动运行 'flutter assemble'。
        
        # 尝试直接运行 cmake
        cmake -S windows -B build/windows/x64 -G "Visual Studio 18 2026" -A x64 -DFLUTTER_TARGET_PLATFORM=windows-x64
        cmake --build build/windows/x64 --config Release
        cmake --install build/windows/x64 --config Release --prefix "$distDir\install"
        
        if (Test-Path "$distDir\install") {
             Copy-Item "$distDir\install\*" "$distDir\" -Recurse -Force
             Write-Host "Manual CMake build successful!" -ForegroundColor Green
        }
    } catch {
        Write-Host "Manual CMake build also failed: $_" -ForegroundColor Red
    }
}
cd ..

# 4. 创建启动脚本
Write-Host "`n[3/3] Creating launcher script..." -ForegroundColor Yellow
$launcherContent = @"
@echo off
start "" "llm_chat_server.exe"
echo Starting Backend Server...
timeout /t 2 >nul
start "" "llm_chat.exe"
"@
Set-Content -Path "$distDir\start_app.bat" -Value $launcherContent

Write-Host "`nBuild process completed." -ForegroundColor Cyan
