class ChatRoomModel {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;

  const ChatRoomModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
  });

  factory ChatRoomModel.fromMap(Map<String, dynamic> map) {
    return ChatRoomModel(
      id: map['id'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'],
      lastMessageAt: map['lastMessageAt'] != null
          ? (map['lastMessageAt'] as dynamic).toDate()
          : null,
      lastMessageSenderId: map['lastMessageSenderId'],
    );
  }

  String otherUserId(String currentUserId) =>
      participants.firstWhere((p) => p != currentUserId,
          orElse: () => '');
}