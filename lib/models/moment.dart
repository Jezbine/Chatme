import 'user_profile.dart';

class Moment {
  final String id;
  final String userId;
  final String content;
  final String? imageUrl;
  final String visibility;
  final DateTime createdAt;
  final UserProfile? author;
  int likeCount;
  int commentCount;
  bool likedByMe;

  Moment({
    required this.id,
    required this.userId,
    required this.content,
    this.imageUrl,
    this.visibility = 'public',
    required this.createdAt,
    this.author,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
  });

  factory Moment.fromJson(Map<String, dynamic> json) => Moment(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        imageUrl: json['image_url'] as String?,
        visibility: (json['visibility'] as String?) ?? 'public',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class MomentComment {
  final String id;
  final String momentId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final UserProfile? author;

  MomentComment({
    required this.id,
    required this.momentId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.author,
  });

  factory MomentComment.fromJson(Map<String, dynamic> json) => MomentComment(
        id: json['id'] as String,
        momentId: json['moment_id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class WalletTransaction {
  final String id;
  final String? senderId;
  final String? receiverId;
  final double amount;
  final String type;
  final String note;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    this.senderId,
    this.receiverId,
    required this.amount,
    this.type = 'transfer',
    this.note = '',
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) => WalletTransaction(
        id: json['id'] as String,
        senderId: json['sender_id'] as String?,
        receiverId: json['receiver_id'] as String?,
        amount: ((json['amount'] as num?) ?? 0).toDouble(),
        type: (json['type'] as String?) ?? 'transfer',
        note: (json['note'] as String?) ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
