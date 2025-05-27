import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:proyecto_final_alejandro/background_task.dart';
import 'package:workmanager/workmanager.dart';

class SupervisedRemindersScreen extends StatelessWidget {
  final String superviseeUid;
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

class _RemindersList extends StatelessWidget {
  final String superviseeUid;
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
          return Center(child: Text('Error: ${snapshot.error}'));
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

            return Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(title),
                subtitle: Text(
                  'Fecha: ${dateTime.toLocal().toString().split('.').first}',
                ),
                // Solo si es pendiente, mostramos icono de campana
                trailing: showCompleted
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.notifications, color: Colors.blue),
                        tooltip: 'Opciones de notificación',
                        onPressed: () {
                          _showNotificationOptionsDialog(
                              context, reminderId, title, currentUserUid, dateTime,);
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
            );
          },
        );
      },
    );
  }

  /// Diálogo que ofrece dos opciones (por ahora implemento solo “30 min después”).
  void _showNotificationOptionsDialog(
    BuildContext context,
    String reminderId,
    String reminderTitle,
    String supervisorUid,
    DateTime originalDateTime,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Notificar a supervisor'),
          content: const Text('¿Cuándo quieres que te avise?'),
          actions: [
            TextButton(
              onPressed: () async {
                // “Cuando se complete” → implementarlo en el futuro
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Esta opción se habilitará más adelante.'),
                  ),
                );
              },
              child: const Text('Cuando se complete'),
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
              child: const Text('30 min después'),
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
