class AiMessageModel {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? actionBadge;
  final Map<String, dynamic>? actionData;
  final bool isError;

  const AiMessageModel({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.actionBadge,
    this.actionData,
    this.isError = false,
  });

  AiMessageModel copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    String? actionBadge,
    Map<String, dynamic>? actionData,
    bool? isError,
  }) {
    return AiMessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      actionBadge: actionBadge ?? this.actionBadge,
      actionData: actionData ?? this.actionData,
      isError: isError ?? this.isError,
    );
  }
}
