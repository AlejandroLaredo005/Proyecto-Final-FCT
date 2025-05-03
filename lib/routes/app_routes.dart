import 'package:proyecto_final_alejandro/screens/forgotten_password_screen.dart';
import 'package:proyecto_final_alejandro/screens/login_screen.dart';
import 'package:proyecto_final_alejandro/screens/profile_screen.dart';
import 'package:proyecto_final_alejandro/screens/register_screen.dart';
import 'package:proyecto_final_alejandro/screens/reminders_screen.dart';

import 'imports.dart';

class AppRoutes {
  // Definir nombres para las rutas
  static const String inicioSesion = '/inicioSesion'; 
  static const String registro = '/registro';
  static const String recuperar = '/recuperar';
  static const String recordatorios = '/recordatorios';
  static const String perfil = '/perfil';

  // Mapa de rutas
  static final Map<String, WidgetBuilder> routes = {
    inicioSesion: (context) => const LoginScreen(),
    registro: (context) => const RegistroScreen(),
    recuperar: (context) => const PasswordResetScreen(),
    recordatorios: (context) => const RemindersScreen(),
    perfil: (_) => const ProfileScreen(),
  };
}