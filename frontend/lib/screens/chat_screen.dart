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

    // 1. Detect user intent: Cancel following if user scrolls up
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        if (_isFollowingBottom) {
          setState(() {
            _isFollowingBottom = false;
            _showScrollToBottomButton = true;
          });
        }
      } else if (notification.direction == ScrollDirection.forward) {
        // Optional: If user scrolls down manually, we can potentially hide the button
        // if they reach bottom, which is handled in ScrollUpdateNotification
      }
    }

    // 2. Detect position: Resume following if reached bottom
    if (notification is ScrollUpdateNotification) {
      // Explicitly check for upward scroll in update notification to catch drag events immediately
      if (notification.scrollDelta != null && notification.scrollDelta! < 0) {
        if (_isFollowingBottom) {
          setState(() {
            _isFollowingBottom = false;
            _showScrollToBottomButton = true;
          });
        }
      }

      // If close to bottom, consider it as reached bottom
      // But ONLY if we are scrolling down (positive delta). 
      // This prevents the "sticky bottom" effect when user starts scrolling up from the bottom.
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
      
      // Update button visibility
      if (!_isFollowingBottom) {
        if (notification.metrics.extentAfter > 200) {
          if (!_showScrollToBottomButton) setState(() => _showScrollToBottomButton = true);
        } else {
          // If user scrolled down close to bottom but didn't trigger extentAfter < 50 check above yet
          // (e.g. at 60), we might want to hide button or keep it? 
          // Let's keep it simple: only hide when truly close (<50) which sets _isFollowingBottom = true
        }
      } else {
        // If following bottom, ensure button is hidden
         if (_showScrollToBottomButton) setState(() => _showScrollToBottomButton = false);
      }
    }
    return false;
  }

  Future<void> _scrollToBottom({bool isStreaming = false}) async {
    if (!_scrollController.hasClients) return;
    
    if (isStreaming) {
      // Use jumpTo during streaming to ensure we stay pinned to the bottom
      // animateTo can lag behind if updates are too frequent
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

    // Auto scroll to bottom when messages change
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
