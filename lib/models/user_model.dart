import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String email;
  final String bio;
  final String profilePicUrl;
  final List<String> friends;
  final bool isOnline;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final String? fcmToken;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    this.bio = '',
    this.profilePicUrl = '',
    this.friends = const [],
    this.isOnline = false,
    required this.createdAt,
    this.lastSeen,
    this.fcmToken,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      bio: map['bio'] ?? '',
      profilePicUrl: map['profilePicUrl'] ?? '',
      friends: List<String>.from(map['friends'] ?? []),
      isOnline: map['isOnline'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as Timestamp).toDate()
          : null,
      fcmToken: map['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'username': username,
        'email': email,
        'bio': bio,
        'profilePicUrl': profilePicUrl,
        'friends': friends,
        'isOnline': isOnline,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
        'fcmToken': fcmToken,
      };
}
