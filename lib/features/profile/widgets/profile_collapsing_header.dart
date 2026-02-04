import 'package:flutter/material.dart';

/// Cabecera colapsable estilo ProjectZ.
///
/// Reglas:
/// - Avatar siempre placeholder (por privacidad, no usamos photoURL de Google).
/// - El botón de "editar" para mi perfil se añadirá más adelante.
class ProfileCollapsingHeader extends StatelessWidget {
  const ProfileCollapsingHeader({
    super.key,
    required this.displayName,
    required this.username,
    required this.isMe,
  });

  final String displayName;
  final String username;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF0F0F12),
      expandedHeight: 300,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        IconButton(
          onPressed: () {
            // Placeholder: menú de opciones (reportar/ajustes)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opciones: pendiente')),
            );
          },
          icon: const Icon(Icons.more_horiz),
        ),
      ],
      titleSpacing: 0,
      title: _CollapsedTitle(displayName: displayName),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // Cuando la AppBar se colapsa, el alto se acerca a (kToolbarHeight + topPadding)
          final minHeight = kToolbarHeight + topPadding;
          final t = ((constraints.maxHeight - minHeight) / (300 - minHeight))
              .clamp(0.0, 1.0);

          return FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Fondo (placeholder)
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF15151A),
                        Color(0xFF0F0F12),
                      ],
                    ),
                  ),
                ),
                // Fade para que el contenido se "pierda" al colapsar
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.15),
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                // Contenido grande (solo visible si no está colapsado)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 22,
                  child: Opacity(
                    opacity: t,
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.white10,
                          child: Icon(Icons.person, size: 42, color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 4),
        const CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white10,
          child: Icon(Icons.person, size: 18, color: Colors.white70),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
