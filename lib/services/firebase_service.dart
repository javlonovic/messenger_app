import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/friend_request_model.dart';

class FriendshipInfo {
  final String status;
  final String? requestId;
  const FriendshipInfo(this.status, {this.requestId});
}

class FirebaseService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;
  static const _cloudinaryCloudName = 'dmpgksik9';
  static const _cloudinaryUploadPreset = 'messenger_unsigned';

  static User? get currentUser => _auth.currentUser;
  static String? get currentUid => _auth.currentUser?.uid;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<UserCredential> register(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  static Future<UserCredential> login(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  static Future<void> signOut() async {
    await updateOnlineStatus(false);
    await _auth.signOut();
  }

  // ── Presence ──────────────────────────────────────────────────────────────

  static Future<void> updateOnlineStatus(bool isOnline) async {
    if (currentUid == null) return;
    await _db.collection('users').doc(currentUid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateFcmToken() async {
    if (currentUid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db.collection('users').doc(currentUid).update({'fcmToken': token});
      }
    } catch (_) {}
  }

  // ── User Profile ──────────────────────────────────────────────────────────

  static Future<UserModel?> getCurrentUserProfile() async {
    if (currentUid == null) return null;
    final doc = await _db.collection('users').doc(currentUid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  static Stream<UserModel?> streamCurrentUser() {
    if (currentUid == null) return Stream.value(null);
    return _db.collection('users').doc(currentUid).snapshots().map(
          (d) => d.exists ? UserModel.fromMap(d.data()!) : null,
        );
  }

  static Stream<UserModel?> streamUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
          (d) => d.exists ? UserModel.fromMap(d.data()!) : null,
        );
  }

  static Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (currentUid == null) throw Exception('User not authenticated');
    await _db.collection('users').doc(currentUid).update(updates);
  }

  static Future<void> createUserProfile(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  static Future<List<UserModel>> searchUsers(String query) async {
    final snap = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data()))
        .where((u) => u.uid != currentUid)
        .toList();
  }

  static Future<UserModel?> getUserById(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  // ── Media Upload (Cloudinary) ─────────────────────────────────────────────

  static Future<String> uploadMedia(String filePath, String resourceType) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/$resourceType/upload',
    );
    final bytes = await File(filePath).readAsBytes();
    final fileName = filePath.split('/').last;
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      String msg = 'Upload failed (${streamed.statusCode})';
      try {
        final e = jsonDecode(body)['error']?['message'] as String?;
        if (e != null) msg = e;
      } catch (_) {}
      throw Exception(msg);
    }
    final url = jsonDecode(body)['secure_url'] as String?;
    if (url == null) throw Exception('No URL in Cloudinary response');
    return url;
  }

  static Future<String> uploadChatMedia({
    required String receiverId,
    required String filePath,
    required String mediaType,
  }) => uploadMedia(filePath, mediaType == 'video' ? 'video' : 'image');

  // ── Friends ───────────────────────────────────────────────────────────────

  static Future<FriendshipInfo> getFriendshipInfo(String otherUserId) async {
    if (currentUid == null) return const FriendshipInfo('none');
    final sent = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: currentUid)
        .where('toUid', isEqualTo: otherUserId)
        .get();
    if (sent.docs.isNotEmpty) {
      final status = sent.docs.first.data()['status'];
      return FriendshipInfo(
        status == 'pending' ? 'sent_pending' : status,
        requestId: sent.docs.first.id,
      );
    }
    final received = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: otherUserId)
        .where('toUid', isEqualTo: currentUid)
        .get();
    if (received.docs.isNotEmpty) {
      final status = received.docs.first.data()['status'];
      return FriendshipInfo(
        status == 'pending' ? 'received_pending' : status,
        requestId: received.docs.first.id,
      );
    }
    final me = await getCurrentUserProfile();
    if (me != null && me.friends.contains(otherUserId)) {
      return const FriendshipInfo('friends');
    }
    return const FriendshipInfo('none');
  }

  static Future<void> sendFriendRequest(String toUid) async {
    if (currentUid == null) throw Exception('User not authenticated');
    final existing = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: currentUid)
        .where('toUid', isEqualTo: toUid)
        .get();
    if (existing.docs.isNotEmpty) throw Exception('Friend request already sent');
    await _db.collection('friend_requests').add({
      'fromUid': currentUid,
      'toUid': toUid,
      'status': 'pending',
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> acceptFriendRequest(String requestId, String fromUid) async {
    if (currentUid == null) throw Exception('User not authenticated');
    final batch = _db.batch();
    batch.update(_db.collection('friend_requests').doc(requestId), {'status': 'accepted'});
    batch.update(_db.collection('users').doc(currentUid), {
      'friends': FieldValue.arrayUnion([fromUid])
    });
    batch.update(_db.collection('users').doc(fromUid), {
      'friends': FieldValue.arrayUnion([currentUid])
    });
    await batch.commit();
  }

  static Future<void> rejectFriendRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).update({'status': 'rejected'});
  }

  static Stream<List<FriendRequestModel>> getFriendRequests() {
    return _db
        .collection('friend_requests')
        .where('toUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => FriendRequestModel.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      return list;
    });
  }

  static Stream<List<FriendRequestModel>> getSentFriendRequests() {
    return _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => FriendRequestModel.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      return list;
    });
  }

  static Future<List<UserModel>> getFriendUsers() async {
    final me = await getCurrentUserProfile();
    if (me == null || me.friends.isEmpty) return [];
    final ids = me.friends.toSet().toList();
    final List<UserModel> result = [];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
      final snap = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
      result.addAll(snap.docs.map((d) => UserModel.fromMap(d.data())));
    }
    return result;
  }

  // ── Chat List ─────────────────────────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> streamChatList() {
    if (currentUid == null) return Stream.value([]);
    return _db
        .collection('chats')
        .where('participants', arrayContains: currentUid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── Typing Indicator ──────────────────────────────────────────────────────

  static Future<void> setTyping(String chatId, bool isTyping) async {
    if (currentUid == null) return;
    await _db.collection('chats').doc(chatId).set({
      'typing': {currentUid: isTyping}
    }, SetOptions(merge: true));
  }

  static Stream<bool> streamTyping(String chatId, String otherUid) {
    return _db.collection('chats').doc(chatId).snapshots().map((d) {
      if (!d.exists) return false;
      final typing = d.data()?['typing'] as Map<String, dynamic>? ?? {};
      return typing[otherUid] == true;
    });
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  static String getChatId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  static Future<void> sendMessage(
    String receiverId, {
    String text = '',
    String? mediaUrl,
    String? mediaType,
    String? replyToId,
    String? replyToText,
  }) async {
    final uid = currentUid;
    if (uid == null) throw Exception('User not authenticated');
    if (text.trim().isEmpty && mediaUrl == null) throw Exception('Cannot send empty message');
    final chatId = getChatId(uid, receiverId);
    final cleanText = text.trim();
    final msg = {
      'senderId': uid,
      'receiverId': receiverId,
      'text': cleanText,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'isDeleted': false,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'reactions': {},
    };
    await _db.collection('chats').doc(chatId).collection('messages').add(msg);
    await _db.collection('chats').doc(chatId).set({
      'participants': [uid, receiverId],
      'lastMessage': cleanText.isNotEmpty ? cleanText : (mediaType == 'image' ? '📷 Photo' : '🎥 Video'),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': uid,
      'unread_$receiverId': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  static Future<void> markMessagesRead(String chatId, String otherUid) async {
    if (currentUid == null) return;
    // Reset unread counter
    await _db.collection('chats').doc(chatId).update({'unread_$currentUid': 0});
    // Mark unread messages from other user as read
    final unread = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isEqualTo: otherUid)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  static Future<void> editMessage(String chatId, String messageId, String newText) async {
    await _db.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
      'text': newText,
      'edited': true,
    });
  }

  static Future<void> deleteMessage(String chatId, String messageId) async {
    await _db.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
      'text': 'This message was deleted',
      'isDeleted': true,
      'mediaUrl': null,
      'mediaType': null,
    });
  }

  static Future<void> toggleReaction(String chatId, String messageId, String emoji) async {
    final uid = currentUid;
    if (uid == null) return;
    final ref = _db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    final doc = await ref.get();
    final reactions = Map<String, dynamic>.from(doc.data()?['reactions'] ?? {});
    final users = List<String>.from(reactions[emoji] ?? []);
    if (users.contains(uid)) {
      users.remove(uid);
    } else {
      users.add(uid);
    }
    if (users.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = users;
    }
    await ref.update({'reactions': reactions});
  }

  static Stream<List<MessageModel>> getMessages(String otherUserId) {
    final uid = currentUid;
    if (uid == null) return Stream.value([]);
    final chatId = getChatId(uid, otherUserId);
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => MessageModel.fromMap(d.data(), d.id)).toList());
  }

  // ── Account ───────────────────────────────────────────────────────────────

  static Future<void> deleteCurrentUserAccount() async {
    final uid = currentUid;
    final user = currentUser;
    if (uid == null || user == null) throw Exception('User not authenticated');
    final sent = await _db.collection('friend_requests').where('fromUid', isEqualTo: uid).get();
    final received = await _db.collection('friend_requests').where('toUid', isEqualTo: uid).get();
    for (final doc in [...sent.docs, ...received.docs]) {
      await doc.reference.delete();
    }
    final withMe = await _db.collection('users').where('friends', arrayContains: uid).get();
    for (final doc in withMe.docs) {
      await doc.reference.update({'friends': FieldValue.arrayRemove([uid])});
    }
    await _db.collection('users').doc(uid).delete();
    await user.delete();
  }
}
