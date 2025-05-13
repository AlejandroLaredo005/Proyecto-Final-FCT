import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;

// Identificador de la tarea
const notificationTask = "notificationTask";

// Este es el entry-point que Android invoca
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

      if (docId != null) {
        // Leer documento en Firestore
        final doc = await FirebaseFirestore.instance
            .collection('reminders')
            .doc(docId)
            .get();

        final completed = doc.data()?['completed'] as bool? ?? false;

        // Mostrar solo si no está completado
        if (!completed) {
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
