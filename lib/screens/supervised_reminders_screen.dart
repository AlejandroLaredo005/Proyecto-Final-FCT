import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
                              context, reminderId, title, currentUserUid);
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

  /// Abre un diálogo con las dos opciones: 'onComplete' o 'after30min'
  void _showNotificationOptionsDialog(BuildContext context, String reminderId,
      String reminderTitle, String supervisorUid) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Notificar a supervisor'),
          content: const Text('¿Cuándo quieres que te avise?'),
          actions: [
            TextButton(
              onPressed: () async {
                // Opción 1: Notificar cuando se complete
                await FirebaseFirestore.instance
                    .collection('reminders')
                    .doc(reminderId)
                    .set(
                  {
                    'notificationSettings': {
                      supervisorUid: 'onComplete',
                    }
                  },
                  SetOptions(merge: true),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pedido: te avisaré cuando se complete.'),
                  ),
                );
              },
              child: const Text('Cuando se complete'),
            ),
            TextButton(
              onPressed: () async {
                // Opción 2: Notificar 30 min después
                await FirebaseFirestore.instance
                    .collection('reminders')
                    .doc(reminderId)
                    .set(
                  {
                    'notificationSettings': {
                      supervisorUid: 'after30min',
                    }
                  },
                  SetOptions(merge: true),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pedido: te avisaré 30 min después si sigue pendiente.'),
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
