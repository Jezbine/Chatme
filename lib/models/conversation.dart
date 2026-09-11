import 'user_profile.dart';
import 'message.dart';

enum ConversationType { direct, group }

class Conversation {
  final String id;
  final ConversationType type;
  final String? name;
  final String? avatarUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ConversationParticipant> participants;
  final Message? lastMessage;

  Conversation({
    required this.id,
    required this.type,
    this.name,
    this.avatarUrl,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.participants = const [],
    this.lastMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: (json['id'] as String?) ?? '',
        type: ConversationType.values.asNameMap()[json['type']] ?? ConversationType.direct,
        name: json['name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        createdBy: (json['created_by'] as String?) ?? '',
        createdAt: json['created_at'] != null
            ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? (DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now())
            : DateTime.now(),
        participants: (json['participants'] as List?)
                ?.map((p) => ConversationParticipant.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
        lastMessage: json['last_message'] != null
            ? Message.fromJson(json['last_message'] as Map<String, dynamic>)
            : null,
      );

  factory Conversation.fromJsonWithParticipants(Map<String, dynamic> json) {
    final participants = (json['participants'] as List?)?.map((p) {
      final pMap = p as Map<String, dynamic>;
      final profileData = pMap['profiles'] as Map<String, dynamic>?;
      return ConversationParticipant(
        conversationId: (json['id'] as String?) ?? (pMap['conversation_id'] as String?) ?? '',
        userId: (pMap['user_id'] as String?) ?? '',
        role: (pMap['role'] as String?) ?? 'member',
        joinedAt: pMap['joined_at'] != null
            ? (DateTime.tryParse(pMap['joined_at'].toString()) ?? DateTime.now())
            : DateTime.now(),
        lastReadMessageId: pMap['last_read_message_id'] as String?,
        muted: (pMap['muted'] as bool?) ?? false,
        profile: profileData != null ? UserProfile.fromJson(profileData) : null,
      );
    }).toList() ?? [];

    return Conversation(
      id: (json['id'] as String?) ?? '',
      type: ConversationType.values.asNameMap()[json['type']] ?? ConversationType.direct,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdBy: (json['created_by'] as String?) ?? '',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      participants: participants,
      lastMessage: json['last_message'] != null && (json['last_message'] as List).isNotEmpty
          ? Message.fromJsonWithSender({
              ...(json['last_message'] as List).first as Map<String, dynamic>,
              'conversation_id': (json['last_message'] as List).first['conversation_id'] ?? json['id'],
            })
          : null,
    );
  }

  String getTitle(String currentUserId) {
    if (type == ConversationType.group) {
      return name ?? 'Groupe';
    }
    final other = participants.firstWhere(
      (p) => p.userId != currentUserId,
      orElse: () => participants.first,
    );
    return other.profile?.displayNameOrPhone ?? 'Discussion';
  }

  String? getAvatarUrl(String currentUserId) {
    if (type == ConversationType.group) {
      return avatarUrl;
    }
    final other = participants.firstWhere(
      (p) => p.userId != currentUserId,
      orElse: () => participants.first,
    );
    return other.profile?.avatarUrl;
  }

  bool get isGroup => type == ConversationType.group;
  bool get isDirect => type == ConversationType.direct;

  ConversationParticipant? getOtherParticipant(String currentUserId) {
    if (participants.isEmpty) return null;
    return participants.firstWhere(
      (p) => p.userId != currentUserId,
      orElse: () => participants.first,
    );
  }

  Conversation copyWith({
    String? id,
    ConversationType? type,
    String? name,
    String? avatarUrl,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ConversationParticipant>? participants,
    Message? lastMessage,
  }) =>
      Conversation(
        id: id ?? this.id,
        type: type ?? this.type,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        participants: participants ?? this.participants,
        lastMessage: lastMessage ?? this.lastMessage,
      );
}

class ConversationParticipant {
  final String conversationId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final String? lastReadMessageId;
  final bool muted;
  final UserProfile? profile;

  ConversationParticipant({
    required this.conversationId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.lastReadMessageId,
    this.muted = false,
    this.profile,
  });

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) => ConversationParticipant(
        conversationId: (json['conversation_id'] as String?) ?? '',
        userId: (json['user_id'] as String?) ?? '',
        role: (json['role'] as String?) ?? 'member',
        joinedAt: json['joined_at'] != null
            ? (DateTime.tryParse(json['joined_at'].toString()) ?? DateTime.now())
            : DateTime.now(),
        lastReadMessageId: json['last_read_message_id'] as String?,
        muted: (json['muted'] as bool?) ?? false,
        profile: json['profiles'] != null ? UserProfile.fromJson(json['profiles'] as Map<String, dynamic>) : null,
      );
}
