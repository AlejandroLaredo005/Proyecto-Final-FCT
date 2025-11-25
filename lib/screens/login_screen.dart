import 'package:flutter/material.dart';
import 'package:proyecto_final_alejandro/routes/app_routes.dart';
import 'package:proyecto_final_alejandro/service/auth_service.dart';

/// Pantalla de inicio de sesión donde el usuario puede autenticarse
/// 
/// El usuario introduce el correo y contraseña y firebase comprobará que los datos coinciden
/// Tambien puede iniciar con google
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Controlador para el campo de correo electrónico
  final TextEditingController emailController = TextEditingController();
  /// Controlador para el campo de contraseña
  final TextEditingController passwordController = TextEditingController();
  /// Servicio de autenticación
  final AuthService _authService = AuthService();

  /// Indicador de carga mientras se procesa la autenticación
  bool _isLoading = false;
  /// Almacena mensaje de error para mostrar en pantalla
  String? _error;

  /// Intenta iniciar sesión con email/contraseña
  void _signIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _authService.signInWithEmail(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
      Navigator.pushReplacementNamed(context, AppRoutes.recordatorios);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Intenta iniciar sesión mediante Google Sign-In
  void _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _authService.signInWithGoogle();
      Navigator.pushReplacementNamed(context, AppRoutes.recordatorios);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Iniciar Sesión',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Iniciar sesión'),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.grey[300], thickness: 1),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: Image.asset(
                      'assets/logo_google.webp',
                      width: 20,
                      height: 20,
                    ),
                    label: const Text('Continuar con Google'),
                    onPressed: _isLoading ? null : _signInWithGoogle,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.registro);
                  },
                  child: const Text(
                    '¿No tienes cuenta? Regístrate',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/recuperar');
                  },
                  child: const Text(
                    '¿Has olvidado tu contraseña?',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
