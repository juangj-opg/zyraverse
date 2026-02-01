import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Entrar con Google'),
          onPressed: () async {
            try {
              await _authService.signInWithGoogle();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error al iniciar sesión')),
              );
            }
          },
        ),
      ),
    );
  }
}
