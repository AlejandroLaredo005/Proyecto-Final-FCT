import 'package:proyecto_final_alejandro/screens/add_supervised_screen.dart';
import 'package:proyecto_final_alejandro/screens/forgotten_password_screen.dart';
import 'package:proyecto_final_alejandro/screens/login_screen.dart';
import 'package:proyecto_final_alejandro/screens/profile_screen.dart';
import 'package:proyecto_final_alejandro/screens/register_screen.dart';
import 'package:proyecto_final_alejandro/screens/reminders_screen.dart';
import 'package:proyecto_final_alejandro/screens/supervision_request_screen.dart';

import 'imports.dart';

class AppRoutes {
  // Definir nombres para las rutas
  static const String inicioSesion = '/inicioSesion'; 
  static const String registro = '/registro';
  static const String recuperar = '/recuperar';
  static const String recordatorios = '/recordatorios';
  static const String perfil = '/perfil';
  static const String agregarSupervisado = '/agregar_supervisado';
  static const String solicitudesSupervision = '/solicitudes_supervision';

  // Mapa de rutas
  static final Map<String, WidgetBuilder> routes = {
    inicioSesion: (context) => const LoginScreen(),
    registro: (context) => const RegistroScreen(),
    recuperar: (context) => const PasswordResetScreen(),
    recordatorios: (context) => const RemindersScreen(),
    perfil: (context) => const ProfileScreen(),
    agregarSupervisado: (context) => const AddSupervisedScreen(),
    solicitudesSupervision: (_) => const SupervisionRequestsScreen(),
  };
}