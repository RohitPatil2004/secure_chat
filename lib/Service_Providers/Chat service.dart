import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../Model/Message model.dart';
import '../Model/chat room model.dart';
import '../Encryption/Encryption service.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  String get _currentUserId => _auth.currentUser!.uid;

  // ─── Chat Rooms ───────────────────────────────────────────────────────────

  /// Get or create a 1-on-1 chat room between two users
  Future<String> getOrCreateChatRoom(String otherUserId) async {
    // Create deterministic room ID from sorted user IDs
    final ids = [_currentUserId, otherUserId]..sort();
    final roomId = '${ids[0]}_${ids[1]}';

    final roomRef = _db.collection('chatRooms').doc(roomId);
    final roomDoc = await roomRef.get();

    if (!roomDoc.exists) {
      await roomRef.set({
        'id': roomId,
        'participants': ids,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageAt': null,
      });
    }

    return roomId;
  }

  /// Stream of chat rooms for current user
  Stream<List<ChatRoomModel>> getChatRooms() {
    return _db
        .collection('chatRooms')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatRoomModel.fromMap(d.data())).toList());
  }

  // ─── Messages ─────────────────────────────────────────────────────────────

  /// Send an E2E encrypted message
  Future<void> sendMessage({
    required String roomId,
    required String recipientId,
    required String plaintext,
  }) async {
    // Fetch recipient's public key
    final recipientDoc =
        await _db.collection('users').doc(recipientId).get();
    final recipientPublicKey = recipientDoc.data()?['publicKey'] as String?;
    if (recipientPublicKey == null) throw Exception('Recipient public key not found');

    // Encrypt message for recipient
    final encryptedForRecipient =
        E2EEncryptionService.encryptMessage(plaintext, recipientPublicKey);

    // Also encrypt for sender (so sender can read their own sent messages)
    final senderPublicKeyPem =
        await E2EEncryptionService.getStoredPublicKeyPem();
    Map<String, String>? encryptedForSender;
    if (senderPublicKeyPem != null) {
      encryptedForSender =
          E2EEncryptionService.encryptMessage(plaintext, senderPublicKeyPem);
    }

    final messageId = _uuid.v4();
    final message = {
      'id': messageId,
      'roomId': roomId,
      'senderId': _currentUserId,
      'recipientId': recipientId,
      // Recipient's copy
      'encryptedMessage': encryptedForRecipient['encryptedMessage'],
      'encryptedKey': encryptedForRecipient['encryptedKey'],
      'iv': encryptedForRecipient['iv'],
      // Sender's copy (for sent messages display)
      'senderEncryptedMessage': encryptedForSender?['encryptedMessage'],
      'senderEncryptedKey': encryptedForSender?['encryptedKey'],
      'senderIv': encryptedForSender?['iv'],
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };

    final batch = _db.batch();

    // Add message
    batch.set(
        _db.collection('chatRooms').doc(roomId).collection('messages').doc(messageId),
        message);

    // Update room last message (store preview as encrypted hint)
    batch.update(_db.collection('chatRooms').doc(roomId), {
      'lastMessage': '🔒 Encrypted message',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': _currentUserId,
    });

    await batch.commit();
  }

  /// Stream and decrypt messages for a chat room
  Stream<List<MessageModel>> getMessages(
      String roomId, String otherUserId) {
    return _db
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .asyncMap((snap) async {
      final messages = <MessageModel>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        try {
          String decryptedText;
          final isMine = data['senderId'] == _currentUserId;

          if (isMine) {
            // Decrypt sender's own copy
            decryptedText = await E2EEncryptionService.decryptMessage(
              data['senderEncryptedMessage'],
              data['senderEncryptedKey'],
              data['senderIv'],
            );
          } else {
            // Decrypt recipient copy
            decryptedText = await E2EEncryptionService.decryptMessage(
              data['encryptedMessage'],
              data['encryptedKey'],
              data['iv'],
            );
          }

          messages.add(MessageModel(
            id: data['id'],
            roomId: data['roomId'],
            senderId: data['senderId'],
            text: decryptedText,
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            isRead: data['isRead'] ?? false,
            type: data['type'] ?? 'text',
          ));
        } catch (e) {
          // If decryption fails, show placeholder
          messages.add(MessageModel(
            id: data['id'] ?? '',
            roomId: roomId,
            senderId: data['senderId'] ?? '',
            text: '[Unable to decrypt message]',
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            isRead: false,
            type: 'error',
          ));
        }
      }
      return messages;
    });
  }

  /// Mark messages as read
  Future<void> markAsRead(String roomId) async {
    final unread = await _db
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .where('recipientId', isEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}