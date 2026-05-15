import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────
// ChatUser MODEL
// ─────────────────────────────────────────────────────────────
class ChatUser {
  final String uid;
  final String displayName;
  final String email;
  final String role;
  final String? photoURL;
  final bool isOnline;
  final DateTime? lastSeen;

  ChatUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    this.photoURL,
    this.isOnline = false,
    this.lastSeen,
  });

  factory ChatUser.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final fullName = (d['full_name'] ?? '').toString().trim();
    final email = (d['email'] ?? '').toString();
    return ChatUser(
      uid: doc.id,
      displayName: fullName.isNotEmpty ? fullName : email.split('@')[0],
      email: email,
      role: d['role'] ?? 'member',
      photoURL: d['photoURL'],
      isOnline: d['isOnline'] ?? false,
      lastSeen: (d['lastSeen'] as Timestamp?)?.toDate(),
    );
  }

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }
}

// ─────────────────────────────────────────────────────────────
// ChatRoom MODEL
// ─────────────────────────────────────────────────────────────
class ChatRoom {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastUpdated;
  final DateTime? createdAt;

  ChatUser? otherUser;
  int unreadCount;

  ChatRoom({
    required this.chatId,
    required this.participants,
    required this.lastMessage,
    this.lastUpdated,
    this.createdAt,
    this.otherUser,
    this.unreadCount = 0,
  });

  factory ChatRoom.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      chatId: doc.id,
      participants: List<String>.from(d['participants'] ?? []),
      lastMessage: d['last_message'] ?? '',
      lastUpdated: (d['last_updated'] as Timestamp?)?.toDate(),
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ChatMessage MODEL
// ─────────────────────────────────────────────────────────────
class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final DateTime? createdAt;
  final bool isEdited;
  final DateTime? editedAt;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    this.createdAt,
    this.isEdited = false,
    this.editedAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: doc.id,
      text: (data['text'] ?? '').toString(),
      senderId: (data['sender_id'] ?? '').toString(),
      isEdited: data['is_edited'] ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      editedAt: (data['edited_at'] as Timestamp?)?.toDate(),
    );
  }
}