import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// Identificador de la tarea
const notificationTask = "notificationTask";

/// Entry-point de Workmanager.
/// 
/// Android invoca esta función en background para despachar tareas agendadas.
/// Inicializa Firestore y el plugin de notificaciones, luego:
///  - Lee el documento del recordatorio en Firestore.
///  - Comprueba su campo `completed` y la opción `mode`.
///  - Muestra la notificación solo si coincide con la lógica de `mode`.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // Inicializar zonas y plugin de notificaciones
    tz.initializeTimeZones();
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings),
    );

    // Inicializar Firebase (necesario para Firestore)
    await Firebase.initializeApp();

    if (taskName == notificationTask && inputData != null) {
      final docId = inputData['docId'] as String?;
      final id    = inputData['id']   as int;
      final title = inputData['title'] as String;
      final body  = inputData['body']  as String;
      final mode  = inputData['mode']  as String?; 

      if (docId != null) {
        // Leer documento en Firestore
        final doc = await FirebaseFirestore.instance
            .collection('reminders')
            .doc(docId)
            .get();

        if (!doc.exists) {
          // Si el recordatorio ya no existe, no hacemos nada
          return Future.value(true);
        }

        final completed = doc.data()?['completed'] as bool? ?? false;

        //  Si mode == "notifyIfPending", notificamos solo si completed == false
        //  Si mode == "notifyIfCompleted", notificamos solo si completed == true
        bool shouldShow = false;
        if (mode == "notifyIfPending" && completed == false) {
          shouldShow = true;
        } else if (mode == "notifyIfCompleted" && completed == true) {
          shouldShow = true;
        }

        // Mostrar solo si no está completado
        if (shouldShow) {
          await flutterLocalNotificationsPlugin.show(
            id,
            title,
            body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'reminders_channel',
                'Recordatorios',
                channelDescription: 'Canal para recordatorios',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        }
      }
    }

    // Retornamos true si la tarea terminó sin errores
    return Future.value(true);
  });
}
