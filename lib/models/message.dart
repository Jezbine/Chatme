import 'user_profile.dart';

enum MessageType { text, image, audio, video, file, system }

enum MessageStatus { sent, delivered, read }

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final MessageType type;
  final String? content;
  final String? mediaUrl;
  final String? mediaMimeType;
  final int? mediaSizeBytes;
  final String? replyToId;
  final MessageStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEdited;
  final UserProfile? sender;
  final Map<String, List<String>>? reactions;
  final Message? replyTo;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.content,
    this.mediaUrl,
    this.mediaMimeType,
    this.mediaSizeBytes,
    this.replyToId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.isEdited = false,
    this.sender,
    this.reactions,
    this.replyTo,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Défensif : last_message côté Supabase ne renvoie pas conversation_id ni updated_at
    final rawType = (json['type'] as String?) ?? 'text';
    final rawStatus = (json['status'] as String?) ?? 'sent';
    Map<String, List<String>>? parsedReactions;
    if (json['reactions'] is Map) {
      parsedReactions = (json['reactions'] as Map).map((k, v) => MapEntry(
            k.toString(),
            (v as List?)?.map((e) => e.toString()).toList() ?? <String>[],
          ));
    }

    return Message(
      id: (json['id'] as String?) ?? '',
      conversationId: (json['conversation_id'] as String?) ?? (json['conversationId'] as String?) ?? '',
      senderId: (json['sender_id'] as String?) ?? '',
      type: MessageType.values.asNameMap()[rawType] ?? MessageType.text,
      content: json['content'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaMimeType: json['media_mime_type'] as String?,
      mediaSizeBytes: json['media_size_bytes'] as int?,
      replyToId: json['reply_to_id'] as String?,
      status: MessageStatus.values.asNameMap()[rawStatus] ?? MessageStatus.sent,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      isEdited: (json['is_edited'] as bool?) ?? false,
      reactions: parsedReactions,
    );
  }

  factory Message.fromJsonWithSender(Map<String, dynamic> json) {
    final rawType = (json['type'] as String?) ?? 'text';
    final rawStatus = (json['status'] as String?) ?? 'sent';
    Map<String, List<String>>? parsedReactions;
    if (json['reactions'] is Map) {
      parsedReactions = (json['reactions'] as Map).map((k, v) => MapEntry(
            k.toString(),
            (v as List?)?.map((e) => e.toString()).toList() ?? <String>[],
          ));
    }

    return Message(
      id: (json['id'] as String?) ?? '',
      conversationId: (json['conversation_id'] as String?) ?? '',
      senderId: (json['sender_id'] as String?) ?? '',
      type: MessageType.values.asNameMap()[rawType] ?? MessageType.text,
      content: json['content'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaMimeType: json['media_mime_type'] as String?,
      mediaSizeBytes: json['media_size_bytes'] as int?,
      replyToId: json['reply_to_id'] as String?,
      status: MessageStatus.values.asNameMap()[rawStatus] ?? MessageStatus.sent,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      sender: json['sender'] != null
          ? UserProfile.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      reactions: parsedReactions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'type': type.name,
        'content': content,
        'media_url': mediaUrl,
        'media_mime_type': mediaMimeType,
        'media_size_bytes': mediaSizeBytes,
        'reply_to_id': replyToId,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_edited': isEdited,
        if (reactions != null) 'reactions': reactions,
      };

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    MessageType? type,
    String? content,
    String? mediaUrl,
    String? mediaMimeType,
    int? mediaSizeBytes,
    String? replyToId,
    MessageStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
    UserProfile? sender,
    Map<String, List<String>>? reactions,
    Message? replyTo,
  }) =>
      Message(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        senderId: senderId ?? this.senderId,
        type: type ?? this.type,
        content: content ?? this.content,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        mediaMimeType: mediaMimeType ?? this.mediaMimeType,
        mediaSizeBytes: mediaSizeBytes ?? this.mediaSizeBytes,
        replyToId: replyToId ?? this.replyToId,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isEdited: isEdited ?? this.isEdited,
        sender: sender ?? this.sender,
        reactions: reactions ?? this.reactions,
        replyTo: replyTo ?? this.replyTo,
      );

  bool isMine(String currentUserId) => senderId == currentUserId;

  String get displayContent {
    switch (type) {
      case MessageType.image:
        return content ?? '📷 Image';
      case MessageType.audio:
        return content ?? '🎵 Audio';
      case MessageType.video:
        return content ?? '🎬 Vidéo';
      case MessageType.file:
        return content ?? '📎 Fichier';
      case MessageType.system:
        return content ?? 'System';
      default:
        return content ?? '';
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
