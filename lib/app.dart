import 'package:flutter/material.dart';
import 'features/rooms/room_list_screen.dart';

class ZyraVerseApp extends StatelessWidget {
  const ZyraVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZyraVerse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const RoomListScreen(),
    );
  }
}
