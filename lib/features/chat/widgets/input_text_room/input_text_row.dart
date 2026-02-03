import 'package:flutter/material.dart';

/// Parte 1 del InputTextRoom: fila del input
/// - icono selección de personaje (placeholder)
/// - texto
/// - A+ (futura edición)
/// - botón enviar
class InputTextRow extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const InputTextRow({
    super.key,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Selector personaje (placeholder)
        const CircleAvatar(
          backgroundColor: Colors.white10,
          child: Icon(Icons.person, color: Colors.white70),
        ),
        const SizedBox(width: 10),

        // Campo de texto
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Escribe tu mensaje...',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // A+ (placeholder futura edición / formato)
        Container(
          height: 44,
          width: 46,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Text(
              'A+',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Enviar
        Container(
          height: 44,
          width: 46,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            icon: const Icon(Icons.send),
            onPressed: onSend,
          ),
        ),
      ],
    );
  }
}
