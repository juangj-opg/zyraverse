class Message {
  final String id;
  final String roomId;
  final String authorId;
  final String content;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.roomId,
    required this.authorId,
    required this.content,
    required this.createdAt,
  });
}
