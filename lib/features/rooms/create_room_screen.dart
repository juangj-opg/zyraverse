import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/rooms_service.dart';
import '../chat/chat_screen.dart';
import 'room_model.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final RoomsService _roomsService = RoomsService();

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  bool _isPublic = true;
  bool _isLoading = false;

  String _ownerDisplayName = 'Usuario';

  @override
  void initState() {
    super.initState();
    _loadOwnerProfile();
    _titleCtrl.addListener(() {
      // Para habilitar/deshabilitar el botón "Crear".
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOwnerProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data() ?? {};
      final displayName = (data['displayName'] as String?)?.trim();
      final username = (data['username'] as String?)?.trim();

      final name = (displayName != null && displayName.isNotEmpty)
          ? displayName
          : ((username != null && username.isNotEmpty) ? username : 'Usuario');

      if (!mounted) return;
      setState(() => _ownerDisplayName = name);
    } catch (_) {
      // Si falla, nos quedamos con "Usuario".
    }
  }

  bool get _canCreate => _titleCtrl.text.trim().isNotEmpty && !_isLoading;

  String get _screenTitle => _isPublic ? 'Nuevo chat público' : 'Nuevo chat privado';

  Future<void> _create() async {
    if (!_canCreate) return;

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;

    final name = _titleCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final type = _isPublic ? 'public' : 'private';

    setState(() => _isLoading = true);

    try {
      final roomId = await _roomsService.createRoom(
        uid: uid,
        ownerDisplayName: _ownerDisplayName,
        name: name,
        description: description,
        type: type,
      );

      if (!mounted) return;

      // Navegamos directo al chat (como ProjectZ: crear -> entrar).
      final room = Room(
        id: roomId,
        name: name,
        type: _isPublic ? RoomType.public : RoomType.private,
        createdAt: DateTime.now(),
        memberCount: 1,
        lastMessageText: null,
        lastActivityAt: DateTime.now(),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la sala: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          _screenTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ayuda: pendiente')),
              );
            },
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Fondo suave (sin complicarnos con assets todavía)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF101014),
                      Color(0xFF0B0B0E),
                    ],
                  ),
                ),
              ),
            ),

            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),

                  // Imagen placeholder (reservado a futuro)
                  Center(
                    child: _ImagePlaceholder(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Subida de imagen: pendiente (Storage)'),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Título (obligatorio)
                  _LabeledField(
                    label: 'Título',
                    child: TextField(
                      controller: _titleCtrl,
                      maxLength: 30,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Escribe el título…',
                        counterText: '',
                      ),
                    ),
                    trailing: _CounterPill(
                      text: '${_titleCtrl.text.trim().length}/30',
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Descripción (opcional)
                  _LabeledField(
                    label: 'Descripción',
                    child: TextField(
                      controller: _descCtrl,
                      maxLength: 180,
                      enabled: !_isLoading,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '¿De qué va esta sala?',
                        counterText: '',
                      ),
                    ),
                    trailing: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _descCtrl,
                      builder: (_, value, __) => _CounterPill(
                        text: '${value.text.trim().length}/180',
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Público / Privado
                  Text(
                    'Visibilidad',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.70),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _VisibilityToggle(
                    isPublic: _isPublic,
                    enabled: !_isLoading,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),
                ],
              ),
            ),

            // Botón crear fijo abajo
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canCreate ? _create : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canCreate ? Colors.white : Colors.white12,
                        foregroundColor: _canCreate ? Colors.black : Colors.white60,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Crear',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final VoidCallback onTap;

  const _ImagePlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 170,
        height: 170,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Icon(Icons.add, size: 52, color: Colors.white70),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget trailing;

  const _LabeledField({
    required this.label,
    required this.child,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            trailing,
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white, fontSize: 15),
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _CounterPill extends StatelessWidget {
  final String text;

  const _CounterPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white70,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  final bool isPublic;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _VisibilityToggle({
    required this.isPublic,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleChip(
              label: 'Pública',
              selected: isPublic,
              enabled: enabled,
              onTap: () => onChanged(true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ToggleChip(
              label: 'Privada',
              selected: !isPublic,
              enabled: enabled,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.black : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
