import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String? mediaUrl;
  final String? mediaType;
  final DateTime timestamp;
  final bool isRead;
  final bool isDeleted;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.mediaUrl,
    this.mediaType,
    required this.timestamp,
    this.isRead = false,
    this.isDeleted = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      text: map['text'] ?? '',
      mediaUrl: map['mediaUrl'],
      mediaType: map['mediaType'],
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'receiverId': receiverId,
    'text': text,
    'mediaUrl': mediaUrl,
    'mediaType': mediaType,
    'timestamp': FieldValue.serverTimestamp(),
    'isRead': isRead,
    'isDeleted': isDeleted,
  };

  bool get hasImage => mediaType == 'image' && mediaUrl != null;
  bool get hasVideo => mediaType == 'video' && mediaUrl != null;
}
