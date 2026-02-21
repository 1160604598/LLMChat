from sqlalchemy import Boolean, Column, ForeignKey, Integer, String, Text, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from .database import Base

class User(Base):
    """
    用户表：存储系统注册用户及其全局配置
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)  # 用户ID，主键
    username = Column(String, unique=True, index=True)  # 用户名，唯一
    hashed_password = Column(String)                    # 加密后的密码
    
    # 用户默认的模型配置（当没有选择特定配置时使用）
    model_base_url = Column(String, default="https://api.openai.com/v1")  # 模型API的基础URL
    model_api_key = Column(String, default="")                            # 模型API Key
    model_name = Column(String, default="gpt-3.5-turbo")                  # 默认使用的模型名称
    model_provider = Column(String, default="OpenAI")                     # 模型提供商 (OpenAI, Anthropic等)

    # 关联关系
    conversations = relationship("Conversation", back_populates="owner")
    model_configs = relationship("ModelConfig", back_populates="owner", cascade="all, delete-orphan", order_by="ModelConfig.display_order")

class ModelConfig(Base):
    """
    模型配置表：用户保存的自定义模型参数预设
    """
    __tablename__ = "model_configs"

    id = Column(Integer, primary_key=True, index=True) # 配置ID
    user_id = Column(Integer, ForeignKey("users.id"))  # 所属用户ID
    name = Column(String, default="Default")           # 配置显示的名称 (如 "我的GPT-4")
    base_url = Column(String)                          # API基础URL
    api_key = Column(String)                           # API Key
    model_name = Column(String)                        # 模型标识符 (如 gpt-4, claude-3-opus)
    provider = Column(String)                          # 提供商类型 (OpenAI, Anthropic, Ollama, Custom)
    display_order = Column(Integer, default=0)         # 显示排序权重
    
    owner = relationship("User", back_populates="model_configs")

class Conversation(Base):
    """
    对话表：存储一次完整的聊天会话
    """
    __tablename__ = "conversations"

    id = Column(Integer, primary_key=True, index=True) # 会话ID
    title = Column(String, default="New Chat")         # 会话标题 (通常由AI生成或用户修改)
    created_at = Column(DateTime, default=datetime.utcnow) # 创建时间
    user_id = Column(Integer, ForeignKey("users.id"))  # 所属用户ID
    model_config_id = Column(Integer, ForeignKey("model_configs.id"), nullable=True) # 使用的模型配置ID (可选)

    owner = relationship("User", back_populates="conversations")
    model_config = relationship("ModelConfig")
    messages = relationship("Message", back_populates="conversation", cascade="all, delete-orphan")

class Message(Base):
    """
    消息表：存储对话中的每一条消息记录
    """
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True) # 消息ID
    role = Column(String)                              # 角色: user (用户), assistant (AI), system (系统提示)
    content = Column(Text)                             # 消息正文内容
    reasoning_content = Column(Text, nullable=True)    # 推理内容 (用于DeepSeek R1等具有思维链的模型)
    created_at = Column(DateTime, default=datetime.utcnow) # 发送时间
    conversation_id = Column(Integer, ForeignKey("conversations.id")) # 所属会话ID

    conversation = relationship("Conversation", back_populates="messages")

class AuditLog(Base):
    """
    审计日志表：记录关键的系统操作行为
    """
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True) # 日志ID
    request_id = Column(String, index=True, nullable=True) # 请求追踪ID (Trace ID)，用于关联同一请求的所有日志
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True) # 操作用户ID (登录失败等情况可能为空)
    
    event_type = Column(String, index=True) # 事件类型: LOGIN, LOGOUT, REGISTER, UPDATE_CONFIG, CREATE_CONVERSATION 等
    target_type = Column(String, index=True, nullable=True) # 操作目标类型: USER, CONVERSATION, MESSAGE, MODEL_CONFIG
    target_id = Column(Integer, nullable=True) # 操作目标的ID
    
    status = Column(String) # 操作结果状态: SUCCESS, FAILURE
    ip_address = Column(String, nullable=True) # 客户端IP地址
    user_agent = Column(String, nullable=True) # 客户端User-Agent信息
    
    details = Column(Text, nullable=True) # 详细信息 (JSON格式存储额外参数)
    created_at = Column(DateTime, default=datetime.utcnow) # 操作时间

    user = relationship("User")

class LLMUsageLog(Base):
    """
    LLM调用日志表：详细记录每一次大模型API调用的技术细节
    """
    __tablename__ = "llm_usage_logs"

    id = Column(Integer, primary_key=True, index=True) # 日志ID
    request_id = Column(String, index=True, nullable=True) # 请求追踪ID
    user_id = Column(Integer, ForeignKey("users.id"))      # 调用用户ID
    conversation_id = Column(Integer, ForeignKey("conversations.id"), nullable=True) # 关联的会话ID
    message_id = Column(Integer, ForeignKey("messages.id"), nullable=True) # 关联生成的AI回复消息ID
    
    # 模型上下文信息
    model_name = Column(String)  # 实际调用的模型名称 (如 gpt-4-0125-preview)
    provider = Column(String)    # 提供商 (OpenAI, Anthropic)
    endpoint_url = Column(String) # 实际请求的API接口地址
    
    # 原始请求与响应数据 (用于完全复现和调试)
    request_headers = Column(Text, nullable=True)  # 请求头 (JSON格式)
    request_payload = Column(Text)                 # 发送给API的完整请求体 (JSON格式)
    response_headers = Column(Text, nullable=True) # API返回的响应头 (JSON格式)
    response_payload = Column(Text)                # API返回的完整响应内容 (拼接后的文本或JSON)
    
    # Token消耗统计
    prompt_tokens = Column(Integer, default=0)     # 提问(输入)消耗的Token数
    completion_tokens = Column(Integer, default=0) # 回答(输出)消耗的Token数
    total_tokens = Column(Integer, default=0)      # 总Token数
    
    # 性能与状态指标
    start_time = Column(DateTime)    # 请求开始时间
    end_time = Column(DateTime)      # 请求结束时间
    duration_ms = Column(Integer)    # 总耗时 (毫秒)
    status_code = Column(Integer)    # HTTP状态码 (200表示成功)
    error_message = Column(Text, nullable=True) # 错误信息 (如果失败)
    stack_trace = Column(Text, nullable=True)   # 异常堆栈追踪 (用于排查代码错误)

    user = relationship("User")
    conversation = relationship("Conversation")
    message = relationship("Message")
