import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user.dart';
import 'auth_provider.dart';

class ChatProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  Conversation? _currentConversation;
  ModelConfig? _selectedModelConfig;
  bool _isLoading = false;
  bool _isStreaming = false;
  AuthProvider? _authProvider;

  void updateAuth(AuthProvider auth) {
    _authProvider = auth;
    
    if (auth.user != null) {
      // Validate currently selected config
      if (_selectedModelConfig != null) {
        final exists = auth.user!.modelConfigs.any((c) => c.id == _selectedModelConfig!.id);
        if (!exists) {
          _selectedModelConfig = null;
        }
      }

      // Auto-select first model if none selected and available
      if (_selectedModelConfig == null && auth.user!.modelConfigs.isNotEmpty) {
           _selectedModelConfig = auth.user!.modelConfigs.first;
      }
    }
  }

  List<Conversation> get conversations => _conversations;
  List<Message> get messages => _messages;
  Conversation? get currentConversation => _currentConversation;
  ModelConfig? get selectedModelConfig => _selectedModelConfig;
  bool get isLoading => _isLoading;
  bool get isStreaming => _isStreaming;

  void selectModelConfig(ModelConfig? config) {
    _selectedModelConfig = config;
    notifyListeners();
  }

  Future<void> loadConversations() async {
    _isLoading = true;
    notifyListeners();
    try {
      _conversations = await _apiService.getConversations();
    } catch (e) {
      print(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectConversation(Conversation conversation) async {
    _currentConversation = conversation;
    
    // Select model config used in conversation
    if (conversation.modelConfigId != null && _authProvider != null && _authProvider!.user != null) {
      try {
        final config = _authProvider!.user!.modelConfigs.firstWhere((c) => c.id == conversation.modelConfigId);
        _selectedModelConfig = config;
      } catch (e) {
        // Config might be deleted
        _selectedModelConfig = null;
      }
    } else {
      // Fallback or keep current? 
      // Requirement: "automatically switch to the model used". 
      // If none used (old chat), maybe null or default?
      // Let's reset to null if not found to avoid confusion, or keep default if we want sticky behavior.
      // But explicit requirement suggests matching history.
      _selectedModelConfig = null;
    }

    _isLoading = true;
    notifyListeners();
    try {
      _messages = await _apiService.getMessages(conversation.id);
    } catch (e) {
      print(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createNewConversation() async {
    _currentConversation = null;
    _messages = [];
    
    // Default select first model if available
    if (_authProvider != null && _authProvider!.user != null && _authProvider!.user!.modelConfigs.isNotEmpty) {
       // If no model selected, or if we want to reset to default?
       // Requirement: "if models added, should default select a model"
       // Let's select the first one if _selectedModelConfig is null, OR always reset?
       // "New conversation" usually implies fresh start. 
       // If I am in a "GPT-4" chat and click new chat, do I expect "GPT-4" or "Default"?
       // Usually "Default" or "Last used".
       // User says: "If added models, should default select a model".
       // Let's select the first one.
       if (_selectedModelConfig == null) {
         _selectedModelConfig = _authProvider!.user!.modelConfigs.first;
       }
    }
    
    notifyListeners();
  }

  Future<void> deleteConversation(int conversationId) async {
    try {
      await _apiService.deleteConversation(conversationId);
      _conversations.removeWhere((c) => c.id == conversationId);
      if (_currentConversation?.id == conversationId) {
        _currentConversation = null;
        _messages = [];
      }
      notifyListeners();
    } catch (e) {
      print(e);
      rethrow;
    }
  }

  Future<void> sendMessage(String content) async {
    if (_isStreaming) return;

    // Add user message immediately to UI
    _messages.add(Message(role: 'user', content: content));
    notifyListeners();

    _isStreaming = true;
    notifyListeners();

    try {
      // If no conversation selected, create one (or handle on backend if supported)
      // Backend expects conversation_id for saving. 
      // If we want to support "new chat" that saves on first message:
      if (_currentConversation == null) {
        // Simple title generation
        String title = content.length > 20 ? content.substring(0, 20) + '...' : content;
        _currentConversation = await _apiService.createConversation(title, modelConfigId: _selectedModelConfig?.id);
        _conversations.insert(0, _currentConversation!);
      }

      final streamResponse = await _apiService.streamChat(content, _currentConversation!.id, _selectedModelConfig);
      
      // Add empty assistant message
      _messages.add(Message(role: 'assistant', content: ''));
      int assistantMsgIndex = _messages.length - 1;
      notifyListeners();

      final stopwatch = Stopwatch()..start();
      bool isThinking = true;
      Timer? timer;

      // Start a timer to update reasoning time periodically
      timer = Timer.periodic(Duration(milliseconds: 100), (t) {
        if (!isThinking) {
          t.cancel();
          return;
        }
        
        // Update reasoning time in UI even if no new content
        final currentMsg = _messages[assistantMsgIndex];
        // Only update if we have started reasoning (i.e. reasoningContent is not null/empty) 
        // OR if we assume initial state is reasoning (which we do for now for models that support it)
        // Actually, better to wait until we receive the first chunk of reasoning or content?
        // But the user wants "autonomous refresh", implying we should see the timer count up.
        // Let's update only if we have at least some reasoning content OR we are waiting.
        // But modifying _messages triggers rebuild.
        
        if (currentMsg.reasoningContent != null && currentMsg.reasoningContent!.isNotEmpty) {
           _messages[assistantMsgIndex] = Message(
              role: 'assistant',
              content: currentMsg.content,
              reasoningContent: currentMsg.reasoningContent,
              reasoningTimeMs: stopwatch.elapsedMilliseconds,
              conversationId: _currentConversation!.id
           );
           notifyListeners();
        }
      });

      streamResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') {
             // Stop timer if done
             if (isThinking) {
                stopwatch.stop();
                isThinking = false;
                timer?.cancel();
             }
             return;
          }

          try {
            final json = jsonDecode(data);
            if (json['choices'] != null && (json['choices'] as List).isNotEmpty) {
              final delta = json['choices'][0]['delta'];
              if (delta != null) {
                final content = delta['content'];
                final reasoning = delta['reasoning_content'];
                
                // If we receive content, it means reasoning might be over or interleaved
                // But usually reasoning comes first. 
                // Let's stop timer when we first receive real content if reasoning was happening.
                // However, deepseek sometimes interleaves. 
                // A simple heuristic: if we have reasoning content, update time.
                // If we get content, we don't necessarily stop counting reasoning time if reasoning continues.
                // BUT, typically reasoning happens before content.
                // Let's track if we are currently receiving reasoning.
                
                if (content != null && content.isNotEmpty && isThinking && (reasoning == null || reasoning.isEmpty)) {
                   isThinking = false;
                   stopwatch.stop();
                   timer?.cancel();
                }

                if (content != null || reasoning != null) {
                  final currentMsg = _messages[assistantMsgIndex];
                  
                  // Update reasoning time only if we are still in thinking phase or just finished
                  int? reasoningTime;
                  // If currently reasoning (or just finished), update time.
                  // If we already stopped thinking, use the stored time (from currentMsg) or final stopwatch time?
                  // Using stopwatch.elapsedMilliseconds is safer if isThinking was true.
                  
                  if (currentMsg.reasoningContent != null || reasoning != null) {
                      // If we are thinking, use current elapsed. 
                      // If we stopped thinking (isThinking=false), we should probably keep the last time.
                      // But here we are inside the stream loop.
                      if (isThinking) {
                         reasoningTime = stopwatch.elapsedMilliseconds;
                      } else {
                         reasoningTime = currentMsg.reasoningTimeMs;
                      }
                  }
                  
                  _messages[assistantMsgIndex] = Message(
                    role: 'assistant', 
                    content: currentMsg.content + (content ?? ''),
                    reasoningContent: (currentMsg.reasoningContent ?? '') + (reasoning ?? ''),
                    reasoningTimeMs: reasoningTime,
                    conversationId: _currentConversation!.id
                  );
                  notifyListeners();
                }
              }
            }
          } catch (e) {
            print('Error parsing stream: $e');
          }
        }
      }, onDone: () {
        if (isThinking) {
           stopwatch.stop();
           timer?.cancel();
        }
        _isStreaming = false;
        notifyListeners();
      }, onError: (error) {
        _messages[assistantMsgIndex] = Message(
          role: 'assistant', 
          content: _messages[assistantMsgIndex].content + "\n[Error: $error]",
          conversationId: _currentConversation!.id
        );
        _isStreaming = false;
        notifyListeners();
      });

    } catch (e) {
      _isStreaming = false;
      _messages.add(Message(role: 'system', content: 'Error: $e'));
      notifyListeners();
    }
  }
}
