import 'package:flutter/material.dart';
import 'package:proyecto_final_alejandro/service/auth_service.dart';

/// Pantalla que permite al usuario solicitar un restablecimiento de contraseña
/// 
/// El usuario introduce su correo y se le manda un correo para cambiarla
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  /// Controlador para el campo de texto del correo electrónico
  final TextEditingController emailController = TextEditingController();
  /// Indica si estamos procesando la petición
  bool _loading = false;
  /// Mensaje de error para mostrar al usuario
  String? _error;

  /// Envia la petición de restablecimiento de contraseña
  void _resetPassword() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService().sendPasswordResetEmail(emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se ha enviado un correo de restablecimiento de contraseña'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = "Ha habido un error al mandar el correo para reiniciar la contraseña, comprueba que el correo esta bien escrito e intentalo de nuevo";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Restablecer contraseña")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Introduce tu correo electrónico para recibir un enlace de restablecimiento de contraseña',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _resetPassword,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Restablecer contraseña'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
