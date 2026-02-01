import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app_entry.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  bool _prefilled = false;
  bool _usernameLocked = false;
  String? _lockedUsername;

  String _normalizeUsername(String value) => value.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _prefillFromUserDoc();
  }

  Future<void> _prefillFromUserDoc() async {
    if (_prefilled) return;
    _prefilled = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data();
      if (data == null) return;

      final u = (data['username'] as String?)?.trim();
      final d = (data['displayName'] as String?)?.trim();
      final b = (data['bio'] as String?)?.trim();

      if (u != null && u.isNotEmpty) {
        _usernameController.text = u;
        _usernameLocked = true;
        _lockedUsername = u;
      }

      // displayName puede venir vacío si el usuario es inválido: lo dejamos tal cual
      if (d != null) _displayNameController.text = d;

      if (b != null && b.isNotEmpty) _bioController.text = b;

      if (mounted) setState(() {});
    } catch (_) {
      // si falla el prefill no pasa nada
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _error = 'Sesión no válida. Vuelve a iniciar sesión.';
      });
      return;
    }

    final uid = user.uid;

    final username = _usernameLocked
        ? (_lockedUsername ?? _normalizeUsername(_usernameController.text))
        : _normalizeUsername(_usernameController.text);

    final displayName = _displayNameController.text.trim();
    final bio = _bioController.text.trim();

    final firestore = FirebaseFirestore.instance;

    try {
      await firestore.runTransaction((tx) async {
        final userRef = firestore.collection('users').doc(uid);
        final usernameRef = firestore.collection('usernames').doc(username);
        final profileRef = firestore.collection('profiles').doc(uid);

        // 1) Reservar/validar username
        final usernameSnap = await tx.get(usernameRef);
        if (usernameSnap.exists) {
          final data = usernameSnap.data();
          final existingUid = data == null ? null : data['uid'];
          if (existingUid != uid) {
            throw Exception('USERNAME_TAKEN');
          }
        } else {
          tx.set(usernameRef, {
            'uid': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // 2) Guardar perfil privado en users/{uid} (isValid = true)
        tx.set(
          userRef,
          {
            'username': username,
            'displayName': displayName,
            'bio': bio,
            'isValid': true,
            'validatedAt': FieldValue.serverTimestamp(),
            // mantenemos foto/email en users (si existen) pero aquí no tocamos email
            'photoURL': user.photoURL,
          },
          SetOptions(merge: true),
        );

        // 3) Guardar perfil público en profiles/{uid} (para pintar autores en chat)
        tx.set(
          profileRef,
          {
            'username': username,
            'displayName': displayName,
            'photoURL': user.photoURL,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;

      // Volver al gate principal (AppEntry) para que redirija a salas si ya eres válido
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppEntry()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      final s = e.toString().toLowerCase();
      setState(() {
        if (s.contains('username_taken')) {
          _error = 'Ese nombre de usuario ya está en uso.';
        } else if (s.contains('permission-denied') || s.contains('permission denied')) {
          _error = 'Permiso denegado al guardar el perfil (Firestore Rules).';
        } else {
          _error = 'Error al guardar el perfil. Inténtalo de nuevo.';
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _usernameLocked ? 'Editar perfil' : 'Crear perfil';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameController,
                enabled: !_usernameLocked,
                decoration: InputDecoration(
                  labelText: 'Usuario (@username)',
                  helperText: _usernameLocked ? 'El username ya está fijado.' : null,
                ),
                validator: (value) {
                  if (_usernameLocked) return null;
                  if (value == null || value.trim().isEmpty) {
                    return 'Introduce un nombre de usuario';
                  }
                  final v = _normalizeUsername(value);
                  final regex = RegExp(r'^[a-z0-9_]{3,}$');
                  if (!regex.hasMatch(v)) {
                    return 'Solo letras, números y _. Mínimo 3 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre visible',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Introduce un nombre visible';
                  }
                  if (value.trim().length > 30) {
                    return 'Máximo 30 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Biografía (opcional)',
                ),
                maxLength: 160,
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_usernameLocked ? 'Guardar perfil' : 'Crear perfil'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
