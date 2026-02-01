import 'package:flutter/material.dart';
import 'app_entry.dart';

class ZyraVerseApp extends StatelessWidget {
  const ZyraVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZyraVerse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const AppEntry(),
    );
  }
}
