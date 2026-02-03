import 'package:flutter/material.dart';

import 'input_functions_row.dart';
import 'input_text_row.dart';

/// Fragmento 3/3 del chat: InputTextRoom
/// - si NO es miembro: botón "Unirse al chat"
/// - si es miembro: inputText + inputFunctions
class InputTextRoom extends StatelessWidget {
  final bool isMember;
  final TextEditingController controller;

  final VoidCallback onJoin;
  final VoidCallback onSend;

  const InputTextRoom({
    super.key,
    required this.isMember,
    required this.controller,
    required this.onJoin,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMember) {
      return SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onJoin,
          child: const Text('Unirse al chat'),
        ),
      );
    }

    return Column(
      children: [
        InputTextRow(
          controller: controller,
          onSend: onSend,
        ),
        const SizedBox(height: 8),
        const InputFunctionsRow(),
      ],
    );
  }
}
