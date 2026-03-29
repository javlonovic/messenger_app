import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendRequestStatus { pending, accepted, rejected }

class FriendRequestModel {
  final String id;
  final String fromUid;
  final String toUid;
  final FriendRequestStatus status;
  final DateTime sentAt;

  FriendRequestModel({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    required this.sentAt,
  });

  factory FriendRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return FriendRequestModel(
      id: id,
      fromUid: map['fromUid'] ?? '',
      toUid: map['toUid'] ?? '',
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => FriendRequestStatus.pending,
      ),
      sentAt: map['sentAt'] != null
          ? (map['sentAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'fromUid': fromUid,
    'toUid': toUid,
    'status': status.name,
    'sentAt': sentAt,
  };
}
