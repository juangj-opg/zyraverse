import 'package:flutter/material.dart';

import '../tool_icon.dart';

/// Parte 2 del InputTextRoom: botones de función (futuros)
/// - nota de voz, imagen, emotes, dados, etc.
class InputFunctionsRow extends StatelessWidget {
  const InputFunctionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        ToolIcon(Icons.graphic_eq),
        ToolIcon(Icons.image_outlined),
        ToolIcon(Icons.emoji_emotions_outlined),
        ToolIcon(Icons.auto_awesome_outlined),
        ToolIcon(Icons.casino_outlined),
        Spacer(),
        ToolIcon(Icons.add),
      ],
    );
  }
}
