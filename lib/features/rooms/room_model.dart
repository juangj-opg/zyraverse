class Room {
  final String id;
  final String name;
  final RoomType type;
  final DateTime createdAt;

  const Room({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
  });
}

enum RoomType {
  public,
  group,
}
