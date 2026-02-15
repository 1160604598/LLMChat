# LLM 对话应用 (LLM Chat Application)

一个全栈大语言模型（LLM）对话应用，支持流式输出（Streaming），体验类似 ChatGPT。基于 Python FastAPI 后端和 Flutter Windows 桌面端构建。

![Screenshot](png/windows_client.png)
![Screenshot](png/chrome.png)
![Screenshot](png/apk.jpg)

## ✨ 主要特性

*   **💬 流式对话体验**: 支持 OpenAI 格式的流式响应（SSE），实现打字机效果，响应迅速。
*   **📝 Markdown 渲染**: 完美支持代码高亮、表格、列表等 Markdown 格式。
*   **📋 一键复制**: 支持消息内容选择复制及一键复制代码块或整条回复。
*   **🗂️ 多会话管理**: 支持创建多个独立会话，自动保存历史记录。
*   **🔐 用户系统**: 完整的用户注册、登录认证流程。
*   **⚙️ 灵活配置**: 
    *   **模型配置**: 支持自定义 Base URL、API Key 和模型名称（兼容 OpenAI, Ollama, vLLM 等）。
    *   **服务地址**: 登录界面可动态配置后端服务器地址，方便远程连接。
    *   **个性化**: 支持中英文切换及明暗主题模式。
*   **📦 绿色免安装**: Windows 版本打包为便携式文件夹，内置所有运行环境。
*   **🌐 全平台支持**: 支持 Windows, Android 和 Web 平台。
*   **🔄 自动更新**: 
    *   **Android**: 支持应用内检查更新、下载 APK 并自动调用系统安装器进行覆盖安装。
    *   **Windows**: 支持应用内检查更新、下载新版安装包（绿色版暂支持下载提示）。

## 🏗️ 架构

- **后端**: Python FastAPI (异步处理, SQLAlchemy ORM, Pydantic)
- **数据库**: SQLite (轻量级本地存储)
- **前端**: Flutter (Windows Desktop, Web, Android, Provider 状态管理, Material 3 设计)

## 🚀 快速开始 (Windows Release)

如果您只想运行程序，可以直接使用构建好的发布包：

1. 进入 `dist` 文件夹。
2. 双击运行 **`start_app.bat`**。
3. 该脚本会自动启动后端服务 (`llm_chat_server.exe`) 和前端客户端 (`llm_chat.exe`)。

## 🛠️ 开发与构建指南

### 1. 后端开发 (Backend)

**方式一：使用脚本 (推荐)**
在项目根目录运行：
```powershell
.\start_backend.ps1
```

**方式二：手动运行**
```bash
cd backend
# 安装依赖
pip install -r requirements.txt
# 启动开发服务器
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 2. 前端开发 (Frontend)

```bash
cd frontend
# 获取依赖
flutter pub get
# 运行桌面版
flutter run -d windows
```

### 3. 打包发布 (Build for Release)

本项目支持构建 Windows 桌面版、Android 移动版和 Web 网页版。

#### Windows 桌面版
本项目提供了一键打包脚本，可生成无需安装环境的绿色版程序。

**环境要求**:
- Python 3.8+ (已添加到 PATH)
- Flutter SDK (已添加到 PATH)
- Visual Studio 2019+ (C++ 桌面开发工作负载)

**构建步骤**:
在 PowerShell 中运行项目根目录下的脚本：
```powershell
.\build_release.ps1
```

**产物说明**:
脚本运行成功后，会在 `dist/` 目录下生成：
- `llm_chat_server.exe`: 打包后的 Python 后端。
- `llm_chat.exe`: 编译后的 Flutter 客户端。
- `data/`: 包含前端资源、依赖库等。
- `start_app.bat`: 一键启动脚本。

只需将整个 `dist` 文件夹分发给用户即可。

#### Android 移动版 (推荐使用 GitHub Actions)
由于本地配置 Android 开发环境较为繁琐，本项目已配置 GitHub Actions 自动构建流程。

1. **推送代码**: 将代码提交到 GitHub 仓库。
2. **自动构建**: 提交后会自动触发 `Build Android` 工作流。
3. **下载 APK**: 构建完成后，在 GitHub Actions 页面下载 `app-release` 构件（Artifact）。

**本地构建 (可选)**:
如果需要在本地构建 APK，请确保已安装 Android Studio 和 Android SDK，并配置好 JDK 17。
本项目提供了便捷脚本 `build_android.ps1`，自动处理环境配置和签名。

**使用方法**:
1. 修改 `build_android.ps1` 中的 SDK 和 JDK 路径。
2. 运行脚本：
```powershell
.\build_android.ps1
```
生成的 APK 位于: `dist/llm_chat_<version>_<timestamp>.apk` (例如 `llm_chat_1.0.7_20260215-1200.apk`)。

**签名说明**:
默认使用项目内置的 `frontend/android/app/upload-keystore.jks` 进行签名。
*   Alias: `upload`
*   Store Password: `123456`
*   Key Password: `123456`

#### Web 网页版
提供一键打包脚本，构建 Flutter Web 前端并生成轻量级 Python Web Server。

**构建步骤**:
在 PowerShell 中运行：
```powershell
.\package_web.ps1
```

**产物说明**:
脚本运行成功后，会在 `web_release/` 目录下生成：
- `www/`: 编译后的 Flutter Web 静态资源。
- `start_web_client.exe`: 打包后的 Web 服务器（无需 Python 环境即可运行）。
- `start_web_client.py`: Web 服务器源码。

双击 `start_web_client.exe` 即可启动 Web 客户端（默认端口 9000）。

## ⚙️ 使用说明

### 连接配置
1. **服务器地址**: 在登录界面右上角点击 ⚙️ 图标，可修改后端 API 地址（默认为 `http://127.0.0.1:8000`）。
2. **模型参数**: 登录后点击右上角 ⚙️ 图标，配置 LLM 参数：
    *   **Base URL**: 例如 `https://api.openai.com/v1` 或本地 `http://localhost:11434/v1`
    *   **API Key**: 你的 API 密钥
    *   **Model Name**: 模型名称（如 `gpt-4`, `llama3`）
3.  **预设模型配置**: 可以在项目根目录创建 `DefaultUserModelsConfig.json` 文件，新注册的用户将自动继承该文件中的模型配置列表。

### 常见问题
*   **注册失败**: 确保后端服务已启动且数据库文件 (`sql_app.db`) 有写入权限。
*   **无法连接**: 检查防火墙设置，或确认登录界面的服务器地址配置正确。

### 🚀 自动更新配置指南

本项目支持简单的应用内自动更新机制。

#### 1. 准备更新包

将新版本的安装包（APK 或 EXE）放置在后端的 `backend/static/` 目录下：
*   Android: `backend/static/app-release.apk`
*   Windows: `backend/static/llm_chat_setup.exe`

#### 2. 修改版本信息

编辑后端根目录下的 `backend/update_config.json` 文件（**支持热更新，无需重启服务**）：

```json
{
    "version": "1.1.0",
    "build_number": 10,
    "changelog": "1. Added auto-update feature.\n2. Bug fixes and performance improvements.",
    "download_url_android": "http://<YOUR_SERVER_IP>:8000/static/app-release.apk",
    "download_url_windows": "http://<YOUR_SERVER_IP>:8000/static/llm_chat_setup.exe",
    "force_update": false
}
```

*注意：`download_url` 建议配置为客户端可访问的公网 IP 或域名地址。*

#### 3. 客户端版本号

客户端当前版本号在 `frontend/pubspec.yaml` 中定义：

```yaml
version: 1.0.3+1 # 格式：版本名称+构建号
```

当后端返回的 `build_number` 大于客户端的构建号（`+`号后面的数字）时，客户端会弹出更新提示。

### ⚠️ 常见连接问题

*   **WRONG_VERSION_NUMBER 错误**:
    这是因为客户端尝试使用 HTTPS 连接到 HTTP 服务器。
    请在登录页面的设置中，确保服务器地址以 `http://` 开头（例如 `http://192.168.1.5:8000`），而不是 `https://`。
