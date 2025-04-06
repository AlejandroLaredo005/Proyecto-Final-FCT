import 'package:proyecto_final_alejandro/firebase_options.dart';

import 'routes/imports.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
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
      // Ruta inicial
      initialRoute: AppRoutes.inicioSesion, 
      // Definición de rutas
      routes: AppRoutes.routes, 
    );
  }
}