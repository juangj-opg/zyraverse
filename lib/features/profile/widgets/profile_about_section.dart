import 'package:flutter/material.dart';

class ProfileAboutSection extends StatefulWidget {
  const ProfileAboutSection({
    super.key,
    required this.bio,
  });

  final String? bio;

  @override
  State<ProfileAboutSection> createState() => _ProfileAboutSectionState();
}

class _ProfileAboutSectionState extends State<ProfileAboutSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bio = widget.bio;

    // OJO: El título "Sobre mí" ahora va anclado (pinned) en el ProfileScreen
    // para replicar el comportamiento de ProjectZ.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
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
          if (bio == null)
            const Text(
              'Sin bio',
              style: TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            _BioText(
              text: bio,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
        ],
      ),
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
    // Heurística simple:
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
          ),
        ),
        if (canToggle) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onToggle,
            child: Text(
              expanded ? 'Ver menos' : 'Ver todo',
              style: const TextStyle(
                color: Colors.lightBlueAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
