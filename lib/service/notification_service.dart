import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

/// Servicio singleton para manejar notificaciones locales.
/// 
/// Encapsula la inicialización del plugin y la programación
/// de notificaciones inmediatas o programadas.
class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Inicializa el servicio de notificaciones:
  /// 1. Configura las zonas horarias.
  /// 2. Inicializa el plugin.
  /// 3. Solicita permisos en Android 13+.
  /// 4. Crea el canal de notificaciones en Android 8+.
  Future<void> init() async {
    // Inicializa zonas horarias
    tz.initializeTimeZones();

    const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInitSettings);

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Manejo al pulsar la notificación
        debugPrint('Notification tapped: ${response.notificationResponseType}');
      },
    );

    // Solicita permiso en Android 13+
    final androidImpl = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestPermission();
      debugPrint('Notification permission granted: $granted');

      // Crea el canal para Android 8+
      const channel = AndroidNotificationChannel(
        'reminders_channel',
        'Recordatorios',
        description: 'Canal para recordatorios de medicación y hábitos',
        importance: Importance.high,
      );
      await androidImpl.createNotificationChannel(channel);
    }
  }

  /// Programa una notificación futura.
  ///
  /// [id]: identificador único de la notificación.  
  /// [title]: título mostrado.  
  /// [body]: cuerpo del mensaje.  
  /// [scheduledDate]: fecha y hora en la que debe saltar.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      debugPrint('▶️ [NotificationService] Scheduling id=$id at $scheduledDate');
      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders_channel',
            'Recordatorios',
            channelDescription: 'Canal para recordatorios',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('   — scheduleNotification COMPLETED id=$id');
    } catch (e, s) {
      debugPrint('❌ [NotificationService] Error scheduleNotification: $e');
      debugPrint('$s');
    }
  }

  /// Muestra una notificación inmediata.
  ///
  /// Utilizado principalmente para pruebas.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _flutterLocalNotificationsPlugin.show(
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
      debugPrint('Immediate notification shown id=$id');
    } catch (e, s) {
      debugPrint('Error in showNotification: $e');
      debugPrint('$s');
    }
  }
}