import 'package:flutter/material.dart';

class ToolIcon extends StatelessWidget {
  final IconData icon;
  const ToolIcon(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 34,
      child: Center(
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
  }
}
