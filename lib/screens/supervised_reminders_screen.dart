import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:proyecto_final_alejandro/background_task.dart';
import 'package:workmanager/workmanager.dart';

/// Pantalla que muestra los recordatorios de un usuario supervisado.
/// Permite ver tanto pendientes como completados, pero sin editar ni borrar.
class SupervisedRemindersScreen extends StatelessWidget {
  /// UID de la persona supervisada cuyos recordatorios se muestran.
  final String superviseeUid;
  /// Nombre para mostrar de la persona supervisada.
  final String superviseeName;

  const SupervisedRemindersScreen({
    super.key,
    required this.superviseeUid,
    required this.superviseeName,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Dos pestañas: Pendientes y Completados
      child: Scaffold(
        appBar: AppBar(
          title: Text('Recordatorios de $superviseeName'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pendientes'),
              Tab(text: 'Completados'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Pestaña “Pendientes”
            _RemindersList(
              superviseeUid: superviseeUid,
              showCompleted: false,
            ),
            // Pestaña “Completados”
            _RemindersList(
              superviseeUid: superviseeUid,
              showCompleted: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget interno que construye la lista de recordatorios según estado.
class _RemindersList extends StatelessWidget {
  /// UID del usuario supervisado.
  final String superviseeUid;
  /// Si es true, muestra completados; si false, pendientes.
  final bool showCompleted;

  const _RemindersList({
    required this.superviseeUid,
    required this.showCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser!.uid;

    // Query: si showCompleted == false, traer solo pendientes; si true, solo completados
    final query = FirebaseFirestore.instance
        .collection('reminders')
        .where('userId', isEqualTo: superviseeUid)
        .where('completed', isEqualTo: showCompleted)
        .orderBy('timestamp', descending: false);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar los recordatorios, compruebe su conexion e intentelo de nuevo'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              showCompleted
                  ? 'No hay recordatorios completados.'
                  : 'No hay recordatorios pendientes.',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] as String? ?? '(Sin título)';
            final desc = data['description'] as String?;
            final Timestamp ts =
                data['timestamp'] as Timestamp? ?? Timestamp.now();
            final dateTime = ts.toDate();
            final reminderId = doc.id;

            // Leemos el mapa notificationSettings (si existe):
            final Map<String, dynamic> notificationSettings =
                (data['notificationSettings'] as Map<String, dynamic>?) ?? {};

            // ¿Existe una entrada para este supervisor en notificationSettings?
            final String? modoElegido =
                notificationSettings[currentUserUid] as String?;

            // Color del ícono de campana:
            final iconColor = modoElegido != null ? Colors.green : Colors.blue;

            // Calculamos el color de fondo de la tarjeta según la fecha:
            final now = DateTime.now();
            Color backgroundColor;
            if (dateTime.isBefore(now)) {
              // Fecha ya pasada → rojo pálido
              backgroundColor = Colors.red.shade100;
            } else {
              final diff = dateTime.difference(now);
              if (diff.inHours <= 24) {
                // En menos de 24 horas → amarillo pálido
                backgroundColor = Colors.yellow.shade100;
              } else {
                // Más de 24 horas → verde pálido
                backgroundColor = Colors.green.shade100;
              }
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Card(
                color: backgroundColor,
                child: ListTile(
                  title: Text(title),
                  subtitle: Text(
                    'Fecha: ${_formatDateTime(dateTime)}',
                  ),
                  // Solo si es pendiente (showCompleted==false), mostramos ícono de campana:
                  trailing: showCompleted
                      ? null
                      : IconButton(
                          icon: Icon(Icons.notifications, color: iconColor),
                          tooltip: modoElegido == null
                              ? 'Sin notificación'
                              : 'Modo: $modoElegido',
                          onPressed: () {
                            _showNotificationOptionsDialog(
                              context,
                              reminderId,
                              title,
                              currentUserUid,
                              dateTime,
                              modoElegido,
                            );
                          },
                        ),
                  onTap: () {
                    // Mostrar diálogo con descripción (si está vacía, “Sin descripción”)
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(title),
                        content: Text(
                          (desc == null || desc.trim().isEmpty)
                              ? 'Sin descripción'
                              : desc,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Formatea la fecha para mostrarla de forma legible.
  String _formatDateTime(DateTime dt) {
    final df = DateFormat('MMM dd, yyyy  •  HH:mm');
    return df.format(dt);
  }

  /// Muestra el diálogo con opciones de notificación y gestiona su programación o cancelación.
  void _showNotificationOptionsDialog(
    BuildContext context,
    String reminderId,
    String reminderTitle,
    String supervisorUid,
    DateTime originalDateTime,
    [String? modoActual]
  ) {
    // Si ya existe un modo guardado para este supervisor, mostramos un diálogo informativo:
    if (modoActual != null) {
      showDialog(
        context: context,
        builder: (ctx) {
          // Traducimos el modo de notificacion de la base de datos al español
          String modoActualTraducido = "";
          if (modoActual.contains("notifyIfCompleted")){
            modoActualTraducido = "Notificar si se completa";
          } else if (modoActual.contains("notifyIfPending")) {
            modoActualTraducido = "Notificar si sigue Pendiente";
          } else {
            modoActualTraducido = "Cuando cumpla y 10 min despues";
          }
          return AlertDialog(
            title: const Text('Notificación ya programada'),
            content: Text(
              'Ya tienes una notificación programada con modo:\n\n'
              '“$modoActualTraducido”\n\n'
              'Si lo deseas, para cambiarlo primero debes eliminar la notificación anterior.',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // Solo gestionamos aquí la eliminación del modo “notifyIfCompleted” y "notifyIfPending", pues su logica es la misma
                  if (modoActual == 'notifyIfCompleted' || modoActual == 'notifyIfPending') {
                    // Calculamos la hora en que se programó originalmente la tarea:
                    final scheduledTime = originalDateTime.add(const Duration(minutes: 30));
                    // Volvemos a calcular el mismo ID que usamos en Workmanager:
                    final followUpId = scheduledTime.millisecondsSinceEpoch ~/ 1000;
                    // Cancelamos la tarea pendiente en Workmanager:
                    await Workmanager().cancelByUniqueName(followUpId.toString());

                    // Eliminamos ese modo del documento en Firestore:
                    await FirebaseFirestore.instance
                      .collection('reminders')
                      .doc(reminderId)
                      .set({
                        'notificationSettings': {
                          supervisorUid: FieldValue.delete(),
                        }
                      },
                      SetOptions(merge: true),
                    );

                  } else if (modoActual == 'sameNotificationsAsSupervised'){
                    // Calculamos la hora a la que estan las notificaciones
                    final firstTime = originalDateTime;
                    final secondTime = originalDateTime.add(const Duration(minutes: 10));

                    // Calculamos las ids de las tareas
                    final firstId  = firstTime.millisecondsSinceEpoch ~/ 1000;
                    final secondId = secondTime.millisecondsSinceEpoch ~/ 1000;

                    // Cancelamos las tareas pendientes en Workmanager:
                    await Workmanager().cancelByUniqueName(firstId.toString());
                    await Workmanager().cancelByUniqueName(secondId.toString());

                    // Eliminamos ese modo del documento en Firestore:
                    await FirebaseFirestore.instance
                      .collection('reminders')
                      .doc(reminderId)
                      .set({
                        'notificationSettings': {
                          supervisorUid: FieldValue.delete(),
                        }
                      },
                      SetOptions(merge: true),
                    );
                  }
                  // Cerrar el diálogo
                  Navigator.pop(ctx);

                  // Muestra un SnackBar de confirmación
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notificación eliminada correctamente.')),
                  );
                },
                child: const Text(
                  'Eliminar notificación',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
      return; // Salimos, no abrimos el diálogo de opciones.
    }
     // Si no había modo guardado (modoActual == null), mostramos el diálogo con las 3 opciones:
    showDialog(
      context: context,
      builder: (ctx) {
        // variable local para saber qué opción está marcada (inicialmente “none”)
        String selectedMode = 'none';

        return AlertDialog(
          title: const Text('Programar notificación'),
          content: const Text('¿Cuándo quieres que te avise?'),
          actions: [
            TextButton(
              onPressed: () async {
                // “Cuando se complete” 
                // Programamos un Workmanager que, 30 minutos despues de la hora original,
                // verifique si completed == TRUE y, en tal caso, notifique.
                final scheduledTime     = originalDateTime.add(const Duration(minutes: 30));
                final now               = DateTime.now();
                final delayDuration     = scheduledTime.difference(now);
                final followUpId        = scheduledTime.millisecondsSinceEpoch ~/ 1000;

                final inputData = {
                  'docId': reminderId,
                  'title': reminderTitle,
                  'body': 'El recordatorio "$reminderTitle" fue completado.',
                  'id': followUpId,
                  'mode': 'notifyIfCompleted',
                };

                if (delayDuration.isNegative) {
                  // Si la hora ya pasó, programamos “inmediato”
                  await Workmanager().registerOneOffTask(
                    followUpId.toString(),
                    notificationTask,
                    initialDelay: Duration.zero,
                    inputData: inputData,
                    existingWorkPolicy: ExistingWorkPolicy.replace,
                  );
                } else {
                  // Programamos para que espere delayDuration
                  await Workmanager().registerOneOffTask(
                    followUpId.toString(),
                    notificationTask,
                    initialDelay: delayDuration,
                    inputData: inputData,
                    existingWorkPolicy: ExistingWorkPolicy.replace,
                  );
                }

                selectedMode = 'notifyIfCompleted';

                await FirebaseFirestore.instance
                        .collection('reminders')
                        .doc(reminderId)
                        .set({
                      'notificationSettings': {
                        supervisorUid: selectedMode,
                      }
                    }, SetOptions(merge: true));

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      delayDuration.isNegative
                        ? 'Notificación programada inmediatamente (ya venció).'
                        : 'Notificación programada a las ${scheduledTime.toLocal().toString().substring(0, 16)}.',
                    ),
                  ),
                );
              },
              child: const Text('30 min despues si es completado'),
            ),
            TextButton(
              onPressed: () async {
                // 30 min después de la hora original
                final scheduledTime =
                    originalDateTime.add(const Duration(minutes: 30));
                final now = DateTime.now();
                final delay = scheduledTime.difference(now);

                // ID de la tarea y de la notificación 
                final followUpId =
                    scheduledTime.millisecondsSinceEpoch ~/ 1000;

                // Campos que queremos pasar al callback
                final inputData = {
                  'docId': reminderId,
                  'title': reminderTitle,
                  'body':
                      'El recordatorio "$reminderTitle" sigue pendiente después de 30 min.',
                  'id': followUpId,
                  'mode': 'notifyIfPending',
                };

                if (delay.isNegative) {
                  // Si la hora ya pasó, programamos Workmanager “inmediato”
                  await Workmanager().registerOneOffTask(
                    followUpId.toString(),
                    notificationTask,
                    initialDelay: Duration.zero,
                    inputData: inputData,
                    existingWorkPolicy: ExistingWorkPolicy.replace,
                  );
                } else {
                  // Programamos para retrasar 'delay'
                  await Workmanager().registerOneOffTask(
                    followUpId.toString(),
                    notificationTask,
                    initialDelay: delay,
                    inputData: inputData,
                    existingWorkPolicy: ExistingWorkPolicy.replace,
                  );
                }

                selectedMode = 'notifyIfPending';

                await FirebaseFirestore.instance
                        .collection('reminders')
                        .doc(reminderId)
                        .set({
                      'notificationSettings': {
                        supervisorUid: selectedMode,
                      }
                    }, SetOptions(merge: true));

                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      delay.isNegative
                          ? 'Notificación programada inmediatamente (ya venció).'
                          : 'Notificación programada a las ${scheduledTime.toLocal().toString().split('.').first}.',
                    ),
                  ),
                );
              },
              child: const Text('30 min después si no es completado'),
            ),
            TextButton(
              onPressed: () async {
                // Calculamos las dos fechas/hora: la original y 10 minutos después
                final now = DateTime.now();
                final firstTime = originalDateTime;
                final secondTime = originalDateTime.add(const Duration(minutes: 10));

                // Calculamos los delays para Workmanager
                final firstDelay = firstTime.difference(now);
                final secondDelay = secondTime.difference(now);

                // Generamos dos IDs únicos (por ejemplo, a partir del timestamp)
                final firstId  = firstTime.millisecondsSinceEpoch ~/ 1000;
                final secondId = secondTime.millisecondsSinceEpoch ~/ 1000;

                // Datos que pasaremos al callback para la notificación
                final commonData = {
                  'docId': reminderId,
                  'title': reminderTitle,
                };

                // Tarea A: notificación justo a la hora original
                await Workmanager().registerOneOffTask(
                  firstId.toString(),            // nombre único de esta tarea
                  notificationTask,              // callbackDispatcher identifica esta constante
                  initialDelay: firstDelay.isNegative
                      ? Duration.zero
                      : firstDelay,
                  inputData: {
                    ...commonData,
                    'id':   firstId,
                    'body': 'Es hora de: $reminderTitle',
                    'mode': 'notifyIfPending',
                  },
                  existingWorkPolicy: ExistingWorkPolicy.replace,
                );

                // Tarea B: notificación 10 minutos después
                await Workmanager().registerOneOffTask(
                  secondId.toString(),
                  notificationTask,
                  initialDelay: secondDelay.isNegative
                      ? Duration.zero
                      : secondDelay,
                  inputData: {
                    ...commonData,
                    'id':   secondId,
                    'body': 'Han pasado 10 min y aún no se completó: $reminderTitle',
                    'mode': 'notifyIfPending',
                  },
                  existingWorkPolicy: ExistingWorkPolicy.replace,
                );

                selectedMode = 'sameNotificationsAsSupervised';

                await FirebaseFirestore.instance
                        .collection('reminders')
                        .doc(reminderId)
                        .set({
                      'notificationSettings': {
                        supervisorUid: selectedMode,
                      }
                    }, SetOptions(merge: true));

                Navigator.pop(ctx);

                // Mensaje informativo
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      firstDelay.isNegative
                          ? 'Notificación “hora exacta” programada inmediatamente (ya venció).'
                          : 'Notificación “hora exacta” programada a las '
                            '${firstTime.toLocal().toString().split('.').first}.',
                    ),
                  ),
                );
              },
              child: const Text('Cuando cumpla y 10 min después'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }
}
