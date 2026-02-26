import 'package:flutter/material.dart';
import '../Service_Providers/Chat service.dart';
import '../Model/Message model.dart';
import '../Model/chat room model.dart';
import '../Firebase/Auth provider.dart';
  
class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  AuthProvider? _authProvider;
  bool _isSending = false;
  String? _error;

  bool get isSending => _isSending;
  String? get error => _error;

  void updateAuth(AuthProvider auth) {
    _authProvider = auth;
  }

  Stream<List<ChatRoomModel>> getChatRooms() {
    return _chatService.getChatRooms();
  }

  Stream<List<MessageModel>> getMessages(String roomId, String otherUserId) {
    return _chatService.getMessages(roomId, otherUserId);
  }

  Future<String> getOrCreateRoom(String otherUserId) {
    return _chatService.getOrCreateChatRoom(otherUserId);
  }

  Future<bool> sendMessage({
    required String roomId,
    required String recipientId,
    required String text,
  }) async {
    _isSending = true;
    _error = null;
    notifyListeners();
    try {
      await _chatService.sendMessage(
        roomId: roomId,
        recipientId: recipientId,
        plaintext: text,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String roomId) async {
    await _chatService.markAsRead(roomId);
  }
}