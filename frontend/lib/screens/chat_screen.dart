import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../providers/chat_provider.dart';
import 'settings_screen.dart';
import '../l10n/app_localizations.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottomButton = false;
  bool _isFollowingBottom = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<ChatProvider>(context, listen: false).loadConversations());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    // 1. 检测用户意图：如果用户向上滚动，取消自动跟随
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        if (_isFollowingBottom) {
          setState(() {
            _isFollowingBottom = false;
            _showScrollToBottomButton = true;
          });
        }
      } else if (notification.direction == ScrollDirection.forward) {
        // 可选：如果用户手动向下滚动，我们可能隐藏按钮
        // 如果他们到达底部，这将在 ScrollUpdateNotification 中处理
      }
    }

    // 2. 检测位置：如果到达底部，恢复自动跟随
    if (notification is ScrollUpdateNotification) {
      // 在更新通知中明确检查向上滚动，以便立即捕获拖拽事件
      if (notification.scrollDelta != null && notification.scrollDelta! < 0) {
        if (_isFollowingBottom) {
          setState(() {
            _isFollowingBottom = false;
            _showScrollToBottomButton = true;
          });
        }
      }

      // 如果接近底部，视为已到达底部
      // 但仅当我们向下滚动时（正 delta）。
      // 这防止了用户从底部开始向上滚动时的“粘性底部”效果。
      if (notification.metrics.extentAfter < 100) {
        if (notification.scrollDelta != null && notification.scrollDelta! > 0) {
          if (!_isFollowingBottom) {
            setState(() {
              _isFollowingBottom = true;
              _showScrollToBottomButton = false;
            });
          }
        }
      }
      
      // 更新按钮可见性
      if (!_isFollowingBottom) {
        if (notification.metrics.extentAfter > 200) {
          if (!_showScrollToBottomButton) setState(() => _showScrollToBottomButton = true);
        } else {
          // 如果用户向下滚动接近底部但尚未触发上面的 extentAfter < 50 检查
          // (例如在 60)，我们可能想要隐藏按钮还是保留它？
          // 让我们保持简单：仅在真正接近 (<50) 时隐藏，这会设置 _isFollowingBottom = true
        }
      } else {
        // 如果正在跟随底部，确保按钮被隐藏
         if (_showScrollToBottomButton) setState(() => _showScrollToBottomButton = false);
      }
    }
    return false;
  }

  Future<void> _scrollToBottom({bool isStreaming = false}) async {
    if (!_scrollController.hasClients) return;
    
    if (isStreaming) {
      // 在流式传输期间使用 jumpTo 以确保我们保持固定在底部
      // 如果更新太频繁，animateTo 可能会滞后
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    } else {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    // 当消息改变时自动滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isFollowingBottom) {
        _scrollToBottom(isStreaming: chatProvider.isStreaming);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(chatProvider.currentConversation?.title ?? S.of(context).newChat),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              chatProvider.createNewConversation();
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(child: Center(child: Text(S.of(context).conversations))),
            Expanded(
              child: ListView.builder(
                itemCount: chatProvider.conversations.length,
                itemBuilder: (context, index) {
                  final conv = chatProvider.conversations[index];
                  return ListTile(
                    title: Text(conv.title),
                    selected: chatProvider.currentConversation?.id == conv.id,
                    onTap: () {
                      chatProvider.selectConversation(conv);
                      Navigator.pop(context);
                    },
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.grey),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(S.of(context).confirmDelete),
                            content: Text(S.of(context).areYouSure),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(S.of(context).cancel),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  chatProvider.deleteConversation(conv.id);
                                },
                                child: Text(S.of(context).delete, style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatProvider.isLoading
                ? Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: _onScrollNotification,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: chatProvider.messages.length,
                          itemBuilder: (context, index) {
                            final msg = chatProvider.messages[index];
                            final isUser = msg.role == 'user';
                            final theme = Theme.of(context);
                            final isDark = theme.brightness == Brightness.dark;

                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? (isDark
                                          ? theme.colorScheme.primary.withOpacity(0.2)
                                          : theme.colorScheme.primary.withOpacity(0.1))
                                      : (isDark ? Colors.grey[800] : Colors.grey[200]),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectionArea(
                                      child: MarkdownBody(data: msg.content),
                                    ),
                                    if (!isUser) ...[
                                      SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: InkWell(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: msg.content));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(S.of(context).copied),
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                          },
                                          child: Icon(Icons.copy, size: 16, color: Colors.grey[600]),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_showScrollToBottomButton)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: FloatingActionButton(
                            mini: true,
                            child: Icon(Icons.arrow_downward),
                            onPressed: _scrollToBottom,
                          ),
                        ),
                    ],
                  ),
          ),
          if (chatProvider.isStreaming)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: S.of(context).typeMessage,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        setState(() {
                          _isFollowingBottom = true;
                          _showScrollToBottomButton = false;
                        });
                        chatProvider.sendMessage(value);
                        _messageController.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: chatProvider.isStreaming
                      ? null
                      : () {
                          if (_messageController.text.trim().isNotEmpty) {
                            setState(() {
                              _isFollowingBottom = true;
                              _showScrollToBottomButton = false;
                            });
                            chatProvider.sendMessage(_messageController.text);
                            _messageController.clear();
                          }
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
