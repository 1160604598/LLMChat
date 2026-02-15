# Android APK 构建脚本
# 请在 PowerShell 中运行此脚本

# ================= 配置区域 =================

# 1. Android SDK 路径
# 请修改为您实际的 SDK 路径 (注意: 路径中不要包含空格)
$AndroidSdkPath = "D:\SDK\AndroidSDK" 

# 2. Java JDK 路径 (JDK 17)
# 如果您的环境变量中没有设置 JAVA_HOME，或者版本不对，请在此指定
# 例如: $JavaHomePath = "C:\Program Files\Java\jdk-17"
$JavaHomePath = "D:\SDK\jdk17\jdk-17.0.18+8"

# ===========================================

Write-Host "Building LLM Chat Android Release..." -ForegroundColor Cyan

# 0. 关键环境修复: 确保系统命令可用 (解决 findstr 找不到的问题)
$sysRoot = $env:SystemRoot
if (-not $sysRoot) { $sysRoot = "C:\Windows" }
$env:PATH = "$sysRoot\system32;$sysRoot;$sysRoot\System32\Wbem;" + $env:PATH

# 1. 配置 Java 环境
if ($JavaHomePath -and (Test-Path $JavaHomePath)) {
    $env:JAVA_HOME = $JavaHomePath
    $env:PATH = "$JavaHomePath\bin;" + $env:PATH
    Write-Host "Using configured JDK: $JavaHomePath" -ForegroundColor Green
} elseif (-not $env:JAVA_HOME) {
    Write-Host "Warning: JAVA_HOME is not set. Build might fail if Java is not in PATH." -ForegroundColor Yellow
} else {
    Write-Host "Using system JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Gray
}

# 验证 Java 版本
try {
    java -version 2>&1 | Select-Object -First 1 | Write-Host -ForegroundColor Gray
} catch {
    Write-Host "Error: Java not found. Please install JDK 17 and set `$JavaHomePath in this script." -ForegroundColor Red
    exit 1
}

# 2. 配置 Android SDK 环境
if (-not (Test-Path $AndroidSdkPath)) {
    Write-Host "Error: Android SDK path not found: $AndroidSdkPath" -ForegroundColor Red
    Write-Host "Please edit this script and set the correct `$AndroidSdkPath variable." -ForegroundColor Yellow
    exit 1
}

$env:ANDROID_HOME = $AndroidSdkPath
$env:ANDROID_SDK_ROOT = $AndroidSdkPath
# 将关键工具加入 PATH
$env:PATH = "$AndroidSdkPath\platform-tools;$AndroidSdkPath\cmdline-tools\latest\bin;$AndroidSdkPath\emulator;" + $env:PATH

Write-Host "Android SDK configured: $AndroidSdkPath" -ForegroundColor Green

# 3. 准备 dist 目录
$distDir = "$PSScriptRoot\dist"
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir | Out-Null
    Write-Host "Dist directory created: $distDir" -ForegroundColor Green
}

# 4. 构建前端 (Android)
Write-Host "`nBuilding Android APK..." -ForegroundColor Yellow
Set-Location "$PSScriptRoot\frontend"

# 设置中国镜像源
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

# 检查 Flutter 环境
Write-Host "Checking Flutter environment..."
flutter doctor

# 检查是否安装了必要的 SDK 组件
if (-not (Test-Path "$AndroidSdkPath\platforms")) {
    Write-Host "Warning: 'platforms' directory not found in SDK." -ForegroundColor Yellow
    Write-Host "You might need to run: sdkmanager 'platforms;android-34'" -ForegroundColor Yellow
}
if (-not (Test-Path "$AndroidSdkPath\build-tools")) {
    Write-Host "Warning: 'build-tools' directory not found in SDK." -ForegroundColor Yellow
    Write-Host "You might need to run: sdkmanager 'build-tools;34.0.0'" -ForegroundColor Yellow
}

# 开始构建
# 使用 --verbose 查看详细输出，如果不需要可以去掉
Write-Host "Running flutter build apk..."
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    # 5. 复制构建产物
    $apkSource = "build\app\outputs\flutter-apk\app-release.apk"
    
    if (Test-Path $apkSource) {
        # 从 pubspec.yaml 读取版本号
        $pubspecContent = Get-Content "$PSScriptRoot\frontend\pubspec.yaml" -Raw
        if ($pubspecContent -match 'version:\s*([\d\.]+)\+(\d+)') {
            $versionName = $matches[1]
            # $versionCode = $matches[2]
            $versionString = $versionName
        } else {
            $versionString = "unknown"
        }

        $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
        # 格式: llm_chat_1.0.7_20260215-1230.apk
        $apkDest = "$distDir\llm_chat_${versionString}_${timestamp}.apk"
        
        Copy-Item $apkSource $apkDest -Force
        Write-Host "`nSuccess! APK copied to: $apkDest" -ForegroundColor Green
        
        # 同时也复制一份通用名称的，方便查找
        Copy-Item $apkSource "$distDir\llm_chat.apk" -Force
    } else {
        Write-Host "`nError: Build successful but APK not found at: $apkSource" -ForegroundColor Red
    }
} else {
    Write-Host "`nError: Flutter build failed." -ForegroundColor Red
    Write-Host "Troubleshooting:"
    Write-Host "1. Check if JDK 17 is installed and configured."
    Write-Host "2. Check if Android SDK components are installed (build-tools, platforms)."
    Write-Host "3. Accept licenses: sdkmanager --licenses"
}

Set-Location "$PSScriptRoot"
Write-Host "`nDone." -ForegroundColor Cyan
