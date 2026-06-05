class ChatParticipant {
  final String id;
  final String displayName;
  final String? avatarUrl;

  const ChatParticipant({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });
}
