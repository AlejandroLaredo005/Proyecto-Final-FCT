import 'package:firebase_auth/firebase_auth.dart';
import 'package:proyecto_final_alejandro/background_task.dart';
import 'package:proyecto_final_alejandro/firebase_options.dart';
import 'package:proyecto_final_alejandro/screens/login_screen.dart';
import 'package:proyecto_final_alejandro/screens/reminders_screen.dart';
import 'package:workmanager/workmanager.dart';

import 'routes/imports.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:proyecto_final_alejandro/service/notification_service.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('▶️ [main] Antes de init notifications');
  await NotificationService().init();
  debugPrint('▶️ [main] Después de init notifications');
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false, 
  );
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recordatorios',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.appTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const RemindersScreen();  // Si el usuario ya esta logueado, pasa al core
          }
          return const LoginScreen();       // Si es la primera vez que inicia, tiene que iniciar sesion o crear cuenta
        },
      ),
      routes: AppRoutes.routes,
    );
  }
}