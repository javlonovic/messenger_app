import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/friend_request_model.dart';

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

  static Future<String> getFriendshipStatus(String otherUserId) async {
    final sentRequest = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: currentUid)
        .where('toUid', isEqualTo: otherUserId)
        .get();
    if (sentRequest.docs.isNotEmpty) {
      return sentRequest.docs.first.data()['status'];
    }
    final receivedRequest = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: otherUserId)
        .where('toUid', isEqualTo: currentUid)
        .get();
    if (receivedRequest.docs.isNotEmpty) {
      return receivedRequest.docs.first.data()['status'];
    }
    final me = await getCurrentUserProfile();
    if (me != null && me.friends.contains(otherUserId)) return 'friends';
    return 'none';
  }

  static Future<void> sendFriendRequest(String toUid) async {
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
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FriendRequestModel.fromMap(d.data(), d.id))
            .toList());
  }

  static Future<List<UserModel>> getFriendUsers() async {
    final me = await getCurrentUserProfile();
    if (me == null || me.friends.isEmpty) return [];
    final friendIds = me.friends;
    final List<UserModel> friendUsers = [];
    for (final friendId in friendIds) {
      final userDoc = await _db.collection('users').doc(friendId).get();
      if (userDoc.exists) friendUsers.add(UserModel.fromMap(userDoc.data()!));
    }
    return friendUsers;
  }

  static String _getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return ids.join('_');
  }

  static Future<void> sendMessage(String receiverId, String text) async {
    final chatId = _getChatId(currentUid!, receiverId);
    final message = {
      'senderId': currentUid,
      'receiverId': receiverId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'isDeleted': false,
    };
    await _db.collection('chats').doc(chatId).collection('messages').add(message);
    await _db.collection('chats').doc(chatId).set({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': currentUid,
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
        .update({'text': 'This message was deleted', 'isDeleted': true});
  }

  static Stream<List<MessageModel>> getMessages(String otherUserId) {
    final chatId = _getChatId(currentUid!, otherUserId);
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
}
