import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  String _normalizeUsername(String value) {
    return value.trim().toLowerCase();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser!;
    final uid = user.uid;

    final username = _normalizeUsername(_usernameController.text);
    final displayName = _displayNameController.text.trim();
    final bio = _bioController.text.trim();

    final firestore = FirebaseFirestore.instance;

    try {
      await firestore.runTransaction((transaction) async {
        final usernameRef =
            firestore.collection('usernames').doc(username);
        final userRef = firestore.collection('users').doc(uid);

        final usernameSnap = await transaction.get(usernameRef);

        if (usernameSnap.exists) {
          throw Exception('USERNAME_TAKEN');
        }

        transaction.set(usernameRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(userRef, {
          'username': username,
          'displayName': displayName,
          'bio': bio,
          'isValid': true,
          'validatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      setState(() {
        if (e.toString().contains('USERNAME_TAKEN')) {
          _error = 'Ese nombre de usuario ya está en uso.';
        } else {
          _error = 'Error al crear el perfil. Inténtalo de nuevo.';
        }
        _isLoading = false;
      });
      return;
    }

    // Si todo fue bien, AppEntry redirigirá automáticamente
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear perfil'),
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
                decoration: const InputDecoration(
                  labelText: 'Usuario (@username)',
                ),
                validator: (value) {
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
                      ? const CircularProgressIndicator()
                      : const Text('Crear perfil'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
