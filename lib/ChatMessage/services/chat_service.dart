import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mukammalpakistanparty/models/chat_models.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get currentUid => _auth.currentUser!.uid;

  // ── Access check ─────────────────────────────────────────────────────────
  Future<bool> canUserChat() async {
    final uid = currentUid;

    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return false;
    final role = userDoc.data()?['role'] ?? 'member';

    if (role == 'admin') return true;

    final roleDoc = await _db.collection('roles').doc(role).get();
    final canChat = roleDoc.data()?['permissions']?['can_chat'] ?? false;
    if (!canChat) return false;

    final appSnap = await _db
        .collection('membership_applications')
        .where('user_id', isEqualTo: uid)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();

    return appSnap.docs.isNotEmpty;
  }

  // ── Approved members list ─────────────────────────────────────────────────
  Future<List<ChatUser>> getApprovedMembers() async {
    final uid = currentUid;

    final appsSnap = await _db
        .collection('membership_applications')
        .where('status', isEqualTo: 'approved')
        .get();
    final approvedIds = appsSnap.docs
        .map((d) => d.data()['user_id'] as String?)
        .whereType<String>()
        .toSet();

    final adminSnap = await _db
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();
    final adminIds = adminSnap.docs.map((d) => d.id).toSet();

    final allIds = {...approvedIds, ...adminIds}..remove(uid);
    if (allIds.isEmpty) return [];

    final List<ChatUser> users = [];
    final chunks = _chunk(allIds.toList(), 10);
    for (final chunk in chunks) {
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      users.addAll(snap.docs.map(ChatUser.fromDoc));
    }

    users.sort((a, b) => a.displayName.compareTo(b.displayName));
    return users;
  }

  // ── Real-time member list ─────────────────────────────────────────────────
  Stream<List<ChatUser>> approvedMembersStream() {
    final controller = StreamController<List<ChatUser>>.broadcast();

    getApprovedMembers().then((initial) {
      controller.add(initial);
      _db
          .collection('users')
          .where('isOnline', isEqualTo: true)
          .snapshots()
          .listen((snap) async {
        final fresh = await getApprovedMembers();
        if (!controller.isClosed) controller.add(fresh);
      });
    });

    return controller.stream;
  }

  // ── Chat rooms for current user (sorted by last_updated desc) ────────────
  Stream<List<ChatRoom>> myChatRoomsStream() {
    return _db
        .collection('chats')
        .where('participants', arrayContains: currentUid)
        .orderBy('last_updated', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ChatRoom.fromDoc).toList());
  }

  // ── Get or create a 1-on-1 chat room ─────────────────────────────────────
  Future<String> getOrCreateChatRoom(String otherUid) async {
    final participants = [currentUid, otherUid]..sort();

    final existing = await _db
        .collection('chats')
        .where('participants', isEqualTo: participants)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return existing.docs.first.id;

    final ref = await _db.collection('chats').add({
      'participants': participants,
      'created_at': FieldValue.serverTimestamp(),
      'last_message': '',
      'last_updated': FieldValue.serverTimestamp(),
      'unread_count': {},
    });
    await ref.update({'chat_id': ref.id});
    return ref.id;
  }

  // ── Messages stream (chronological) ──────────────────────────────────────
  Stream<List<ChatMessage>> messagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
  }

  // ── Send message ──────────────────────────────────────────────────────────
  Future<void> sendMessage(String chatId, String text) async {
    final batch = _db.batch();

    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    batch.set(msgRef, {
      'text': text,
      'sender_id': currentUid,
      'created_at': FieldValue.serverTimestamp(),
      'is_edited': false,
    });

    final chatDoc = await _db.collection('chats').doc(chatId).get();
    final participants =
    List<String>.from(chatDoc.data()?['participants'] ?? []);
    final others = participants.where((p) => p != currentUid).toList();

    final Map<String, dynamic> unreadUpdate = {};
    for (final uid in others) {
      unreadUpdate['unread_count.$uid'] = FieldValue.increment(1);
    }

    batch.update(_db.collection('chats').doc(chatId), {
      'last_message': text,
      'last_updated': FieldValue.serverTimestamp(),
      ...unreadUpdate,
    });

    await batch.commit();
  }

  // ── Delete a message ──────────────────────────────────────────────────────
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      debugPrint('deleteMessage error: $e');
    }
  }

  // ── Mark chat as read ─────────────────────────────────────────────────────
  Future<void> markChatAsRead(String chatId) async {
    try {
      final docRef = _db.collection('chats').doc(chatId);
      final doc = await docRef.get();
      if (!doc.exists) return;
      await docRef.set({
        'unread_count': {currentUid: 0},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('markChatAsRead error: $e');
    }
  }

  // ── Unread count stream ───────────────────────────────────────────────────
  Stream<int> unreadCountStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return 0;
      final unread = doc.data()?['unread_count'];
      if (unread == null || unread is! Map) return 0;
      return (unread[currentUid] ?? 0) as int;
    });
  }

  // ── Online presence ───────────────────────────────────────────────────────
  Future<void> setOnline() async {
    await _db.collection('users').doc(currentUid).update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setOffline() async {
    await _db.collection('users').doc(currentUid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(
          i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }
}