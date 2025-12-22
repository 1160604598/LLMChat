import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ChatProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  Conversation? _currentConversation;
  bool _isLoading = false;
  bool _isStreaming = false;

  List<Conversation> get conversations => _conversations;
  List<Message> get messages => _messages;
  Conversation? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  bool get isStreaming => _isStreaming;

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
    notifyListeners();
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
        _currentConversation = await _apiService.createConversation(title);
        _conversations.insert(0, _currentConversation!);
      }

      final streamResponse = await _apiService.streamChat(content, _currentConversation!.id);
      
      // Add empty assistant message
      _messages.add(Message(role: 'assistant', content: ''));
      int assistantMsgIndex = _messages.length - 1;
      notifyListeners();

      streamResponse.stream.transform(utf8.decoder).listen((data) {
        _messages[assistantMsgIndex] = Message(
          role: 'assistant', 
          content: _messages[assistantMsgIndex].content + data,
          conversationId: _currentConversation!.id
        );
        notifyListeners();
      }, onDone: () {
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
