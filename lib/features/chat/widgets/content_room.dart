import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../message_model.dart';
import 'message_group_bubble.dart';

/// Fragmento 2/3 del chat: ContentRoom
/// Contiene TODO el render del historial (no lo fragmentamos más a nivel lógico),
/// pero sí lo encapsulamos en un widget para mantener ChatScreen pequeño.
class ContentRoom extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream;
  final String? currentUid;

  const ContentRoom({
    super.key,
    required this.messagesStream,
    required this.currentUid,
  });

  String _formatDateSeparator(DateTime dt) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sept', 'oct', 'nov', 'dic'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hh:$mi';
  }

  bool _needsSeparator(DateTime current, DateTime? previous) {
    if (previous == null) return true;
    final diff = current.difference(previous);

    final dayChanged = current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;

    return dayChanged || diff.inHours >= 3;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error cargando mensajes: ${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No hay mensajes'));
        }

        final messages = docs.map((d) => Message.fromFirestore(d)).toList();

        final items = <_ChatItem>[];
        DateTime? prevTime;

        for (int i = 0; i < messages.length; i++) {
          final m = messages[i];

          // IMPORTANTE (estilo ProjectZ):
          // Los separadores (fecha/hora) y los mensajes de sistema deben "romper" el grupo.
          // Es decir: si insertamos un separador aquí, el siguiente mensaje del mismo autor
          // debe volver a mostrar avatar+nombre como inicio de bloque.
          final insertedSeparator = _needsSeparator(m.createdAt, prevTime);

          if (insertedSeparator) {
            items.add(_ChatItem.separator(_formatDateSeparator(m.createdAt)));
          }

          final prevMsg = (i > 0) ? messages[i - 1] : null;
          final nextMsg = (i < messages.length - 1) ? messages[i + 1] : null;

          // Si hay separador insertado antes de este mensaje, NO puede ser continuación del grupo.
          final sameAsPrev = !insertedSeparator &&
              prevMsg != null &&
              prevMsg.type == 'user' &&
              m.type == 'user' &&
              prevMsg.authorId == m.authorId;

          // Si entre este mensaje y el siguiente habrá un separador, entonces ESTE es el último del grupo.
          final separatorBeforeNext =
              nextMsg != null ? _needsSeparator(nextMsg.createdAt, m.createdAt) : false;

          final sameAsNext = !separatorBeforeNext &&
              nextMsg != null &&
              nextMsg.type == 'user' &&
              m.type == 'user' &&
              nextMsg.authorId == m.authorId;

          items.add(
            _ChatItem.message(
              m,
              isFirstOfGroup: !sameAsPrev,
              isLastOfGroup: !sameAsNext,
            ),
          );

          prevTime = m.createdAt;
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];

            if (item.kind == _ChatItemKind.separator) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.separatorText!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              );
            }

            final msg = item.message!;
            if (msg.type == 'system') {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      msg.text,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            final isMe = currentUid != null && msg.authorId == currentUid;

            final name = msg.authorDisplayName.trim().isNotEmpty
                ? msg.authorDisplayName.trim()
                : 'Usuario';

            return MessageGroupBubble(
              isMe: isMe,
              displayName: name,
              text: msg.text,
              authorUid: msg.authorId,
              showHeader: item.isFirstOfGroup!,
              showAvatar: item.isFirstOfGroup!,
              addBottomGap: item.isLastOfGroup!,
            );
          },
        );
      },
    );
  }
}

enum _ChatItemKind { separator, message }

class _ChatItem {
  final _ChatItemKind kind;
  final String? separatorText;

  final Message? message;
  final bool? isFirstOfGroup;
  final bool? isLastOfGroup;

  _ChatItem.separator(this.separatorText)
      : kind = _ChatItemKind.separator,
        message = null,
        isFirstOfGroup = null,
        isLastOfGroup = null;

  _ChatItem.message(
    this.message, {
    required this.isFirstOfGroup,
    required this.isLastOfGroup,
  })  : kind = _ChatItemKind.message,
        separatorText = null;
}
