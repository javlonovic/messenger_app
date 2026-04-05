import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  static User? get currentUser => _auth.currentUser;
  static String? get currentUid => _auth.currentUser?.uid;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<UserCredential> register(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  static Future<UserCredential> login(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  static Future<void> signOut() => _auth.signOut();

  static Future<void> updateOnlineStatus(bool isOnline) async {
    if (currentUid == null) return;
    await _db.collection('users').doc(currentUid).update({'isOnline': isOnline});
  }

  static Future<UserModel?> getCurrentUserProfile() async {
    if (currentUid == null) return null;
    final doc = await _db.collection('users').doc(currentUid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  static Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (currentUid == null) throw Exception('User not authenticated');
    await _db.collection('users').doc(currentUid).update(updates);
  }

  static Future<void> createUserProfile(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  static Stream<List<UserModel>> getUsers() {
    return _db.collection('users').snapshots().map((snap) =>
        snap.docs.map((d) => UserModel.fromMap(d.data())).toList());
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

  static Future<FriendshipInfo> getFriendshipInfo(String otherUserId) async {
    if (currentUid == null) return const FriendshipInfo('none');
    final sentRequest = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: currentUid)
        .where('toUid', isEqualTo: otherUserId)
        .get();
    if (sentRequest.docs.isNotEmpty) {
      final status = sentRequest.docs.first.data()['status'];
      if (status == 'pending') {
        return FriendshipInfo('sent_pending', requestId: sentRequest.docs.first.id);
      }
      return FriendshipInfo(status, requestId: sentRequest.docs.first.id);
    }
    final receivedRequest = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: otherUserId)
        .where('toUid', isEqualTo: currentUid)
        .get();
    if (receivedRequest.docs.isNotEmpty) {
      final status = receivedRequest.docs.first.data()['status'];
      if (status == 'pending') {
        return FriendshipInfo('received_pending', requestId: receivedRequest.docs.first.id);
      }
      return FriendshipInfo(status, requestId: receivedRequest.docs.first.id);
    }
    final me = await getCurrentUserProfile();
    if (me != null && me.friends.contains(otherUserId)) return const FriendshipInfo('friends');
    return const FriendshipInfo('none');
  }

  static Future<void> sendFriendRequest(String toUid) async {
    if (currentUid == null) throw Exception('User not authenticated');
    final existingRequest = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: currentUid)
        .where('toUid', isEqualTo: toUid)
        .get();
    if (existingRequest.docs.isNotEmpty) throw Exception('Friend request already sent');
    final me = await getCurrentUserProfile();
    if (me != null && me.friends.contains(toUid)) throw Exception('Already friends');
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
    try {
      await _db.collection('friend_requests').doc(requestId).update({'status': 'rejected'});
    } catch (e) {
      throw Exception('Failed to reject friend request: $e');
    }
  }

  static Stream<List<FriendRequestModel>> getFriendRequests() {
    return _db
        .collection('friend_requests')
        .where('toUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final requests = snap.docs
              .map((d) => FriendRequestModel.fromMap(d.data(), d.id))
              .toList();
          requests.sort((a, b) => b.sentAt.compareTo(a.sentAt));
          return requests;
        });
  }

  static Stream<List<FriendRequestModel>> getSentFriendRequests() {
    return _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final requests = snap.docs
              .map((d) => FriendRequestModel.fromMap(d.data(), d.id))
              .toList();
          requests.sort((a, b) => b.sentAt.compareTo(a.sentAt));
          return requests;
        });
  }

  static Future<List<UserModel>> getFriendUsers() async {
    final me = await getCurrentUserProfile();
    if (me == null || me.friends.isEmpty) return [];
    final friendIds = me.friends.toSet().toList();
    final List<UserModel> friendUsers = [];
    for (var i = 0; i < friendIds.length; i += 10) {
      final chunk = friendIds.sublist(i, i + 10 > friendIds.length ? friendIds.length : i + 10);
      final snap = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snap.docs) {
        friendUsers.add(UserModel.fromMap(doc.data()));
      }
    }
    return friendUsers;
  }

  static Future<UserModel?> getUserById(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  static String _getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return ids.join('_');
  }

  static const _cloudinaryCloudName = 'dmpgksik9';
  static const _cloudinaryUploadPreset = 'messenger_unsigned';

  static Future<String> uploadChatMedia({
    required String receiverId,
    required String filePath,
    required String mediaType,
  }) async {
    final uid = currentUid;
    if (uid == null) throw Exception('User not authenticated');

    final chatId = _getChatId(uid, receiverId);
    final resourceType = mediaType == 'video' ? 'video' : 'image';
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/$resourceType/upload',
    );

    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final fileName = filePath.split('/').last;

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..fields['folder'] = 'messenger_app/$chatId'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
      String errorMsg = 'Upload failed (${streamedResponse.statusCode}): $body';
      try {
        final errJson = jsonDecode(body) as Map<String, dynamic>;
        final msg = errJson['error']?['message'] as String?;
        if (msg != null) errorMsg = msg;
      } catch (_) {}
      throw Exception(errorMsg);
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final secureUrl = json['secure_url'] as String?;
    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('No URL in Cloudinary response: $body');
    }
    return secureUrl;
  }

  static Future<void> sendMessage(
    String receiverId, {
    String text = '',
    String? mediaUrl,
    String? mediaType,
  }) async {
    final uid = currentUid;
    if (uid == null) throw Exception('User not authenticated');
    if (text.trim().isEmpty && mediaUrl == null) {
      throw Exception('Cannot send an empty message');
    }
    final chatId = _getChatId(uid, receiverId);
    final cleanText = text.trim();
    final message = {
      'senderId': uid,
      'receiverId': receiverId,
      'text': cleanText,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'isDeleted': false,
    };
    await _db.collection('chats').doc(chatId).collection('messages').add(message);
    await _db.collection('chats').doc(chatId).set({
      'lastMessage': cleanText.isNotEmpty
          ? cleanText
          : (mediaType == 'image' ? '[Image]' : '[Video]'),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': uid,
    }, SetOptions(merge: true));
  }

  static Future<void> editMessage(String chatId, String messageId, String newText) async {
    try {
      await _db.collection('chats').doc(chatId).collection('messages').doc(messageId).update({'text': newText});
    } catch (e) {
      throw Exception('Failed to edit message: $e');
    }
  }

  static Future<void> deleteMessage(String chatId, String messageId) async {
    await _db.collection('chats').doc(chatId).collection('messages').doc(messageId)
        .update({
          'text': 'This message was deleted',
          'isDeleted': true,
          'mediaUrl': null,
          'mediaType': null,
        });
  }

  static Stream<List<MessageModel>> getMessages(String otherUserId) {
    final uid = currentUid;
    if (uid == null) return Stream.value([]);
    final chatId = _getChatId(uid, otherUserId);
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MessageModel.fromMap(d.data(), d.id))
            .toList());
  }

  static Future<void> deleteCurrentUserAccount() async {
    final uid = currentUid;
    final user = currentUser;
    if (uid == null || user == null) {
      throw Exception('User not authenticated');
    }

    // Remove pending/old friend requests involving this user.
    final sentRequests = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: uid)
        .get();
    final receivedRequests = await _db
        .collection('friend_requests')
        .where('toUid', isEqualTo: uid)
        .get();
    for (final doc in [...sentRequests.docs, ...receivedRequests.docs]) {
      await doc.reference.delete();
    }

    // Remove this user from other users' friend lists.
    final usersWithMeAsFriend = await _db
        .collection('users')
        .where('friends', arrayContains: uid)
        .get();
    for (final doc in usersWithMeAsFriend.docs) {
      await doc.reference.update({
        'friends': FieldValue.arrayRemove([uid]),
      });
    }

    // Delete own profile doc first.
    await _db.collection('users').doc(uid).delete();

    // Finally remove auth account.
    await user.delete();
  }
}
