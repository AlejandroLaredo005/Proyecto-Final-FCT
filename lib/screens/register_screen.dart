import 'package:flutter/material.dart';
import 'package:proyecto_final_alejandro/routes/app_routes.dart';
import 'package:proyecto_final_alejandro/service/auth_service.dart';

/// Pantalla de registro de nuevos usuarios mediante email/contraseña.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  /// Controlador para el campo de correo electrónico.
  final TextEditingController _emailController = TextEditingController();
  /// Controlador para el campo de contraseña.
  final TextEditingController _passwordController = TextEditingController();
  /// Controlador para confirmar contraseña.
  final TextEditingController _confirmController = TextEditingController();

  /// Indicador de carga mientras se procesa el registro.
  bool _loading = false;
  /// Mensaje de error a mostrar en pantalla.
  String _error = '';

  /// Ejecuta el flujo de registro:
  /// 1. Valida que los campos no estén vacíos.
  /// 2. Comprueba que contraseña y confirmación coincidan.
  /// 3. Llama a AuthService para crear el usuario.
  /// 4. Navega a la pantalla de Login si el registro es exitoso.
  void _registrar() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    setState(() {
      _error = '';
    });

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Completa todos los campos');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService().registerWithEmail(email, password);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.inicioSesion);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrarse')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Correo electrónico'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_error.isNotEmpty)
              Text(
                _error,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _registrar,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Registrarse'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context),
              child: const Text('¿Ya tienes cuenta? Inicia sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
