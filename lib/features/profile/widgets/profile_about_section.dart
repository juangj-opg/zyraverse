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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sobre mí',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
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
                  onExpand: () => setState(() => _expanded = true),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BioText extends StatelessWidget {
  const _BioText({
    required this.text,
    required this.expanded,
    required this.onExpand,
  });

  final String text;
  final bool expanded;
  final VoidCallback onExpand;

  bool _shouldShowMore(String text) {
    // Heurística simple (sin medir layout): si hay muchas líneas o mucho texto.
    final lineBreaks = '\n'.allMatches(text).length;
    return lineBreaks >= 5 || text.length > 220;
  }

  @override
  Widget build(BuildContext context) {
    final showMore = !expanded && _shouldShowMore(text);

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
        if (showMore) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              // Modal con todo el texto (estilo "Ver todo")
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF121218),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                builder: (_) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Bio',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                              )
                            ],
                          ),
                          const SizedBox(height: 6),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Text(
                                text,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            child: const Text(
              'Ver todo',
              style: TextStyle(
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
