// lib/models/message_model.dart
class MessageModel {
  final String id;
  final String roomId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'text', 'image', 'error'

  const MessageModel({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isRead,
    this.type = 'text',
  });
}