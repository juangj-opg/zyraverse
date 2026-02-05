import 'package:flutter/material.dart';

class ProfileAboutSection extends StatefulWidget {
  const ProfileAboutSection({
    super.key,
    required this.bio,
    required this.onCollapseSnapToTop,
  });

  final String? bio;

  /// Cuando se pulsa "Ver menos", forzamos un pequeño "snap" hacia arriba
  /// para evitar estados raros cuando hay poco contenido.
  final VoidCallback onCollapseSnapToTop;

  @override
  State<ProfileAboutSection> createState() => _ProfileAboutSectionState();
}

class _ProfileAboutSectionState extends State<ProfileAboutSection> {
  bool _expanded = false;

  void _toggle() {
    final wasExpanded = _expanded;
    setState(() => _expanded = !_expanded);

    // ✅ Si acabamos de colapsar ("Ver menos"), pedimos snap hacia arriba.
    if (wasExpanded && !_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCollapseSnapToTop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bio = widget.bio?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.subject, color: Colors.white70, size: 18),
            SizedBox(width: 8),
            Text(
              'Bio',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (bio == null || bio.isEmpty)
          const Text(
            'Sin bio',
            style: TextStyle(
              color: Colors.white60,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.25,
            ),
          )
        else
          _BioText(
            text: bio,
            expanded: _expanded,
            onToggle: _toggle,
          ),
      ],
    );
  }
}

class _BioText extends StatelessWidget {
  const _BioText({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  bool _shouldShowToggle(String text) {
    final lineBreaks = '\n'.allMatches(text).length;
    return lineBreaks >= 5 || text.length > 220;
  }

  @override
  Widget build(BuildContext context) {
    final canToggle = _shouldShowToggle(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: expanded ? null : 5,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        if (canToggle) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                expanded ? 'Ver menos' : 'Ver todo',
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
