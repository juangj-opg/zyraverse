import 'package:flutter/material.dart';

/// Parte inferior del HeaderRoom:
/// - Noticias (placeholder)
/// - Miembros (avatares + contador)
/// - Selector Roleplay (placeholder)
class HeaderRoomInfo extends StatelessWidget {
  final int memberCount;

  const HeaderRoomInfo({
    super.key,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.campaign_outlined, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Noticias',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 64,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        _MemberAvatar(left: 0),
                        _MemberAvatar(left: 14),
                        _MemberAvatar(left: 28),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$memberCount',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: const [
              Icon(Icons.shield_outlined, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Roleplay',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.expand_more),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final double left;

  const _MemberAvatar({required this.left});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black87,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: const CircleAvatar(
          backgroundColor: Colors.white10,
          child: Icon(Icons.person, size: 16, color: Colors.white70),
        ),
      ),
    );
  }
}
