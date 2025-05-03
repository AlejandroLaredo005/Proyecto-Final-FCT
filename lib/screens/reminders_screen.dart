import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:proyecto_final_alejandro/routes/app_routes.dart';
import 'package:proyecto_final_alejandro/service/notification_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _addReminder(DateTime dateTime) async {
    final String title = _titleController.text.trim();
    if (title.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    await _firestore.collection('reminders').add({
      'title': title,
      'timestamp': dateTime,
      'userId': user?.uid,
    });

    _titleController.clear();

    final int notificationId = dateTime.millisecondsSinceEpoch ~/ 1000;
    await NotificationService().scheduleNotification(
      id: notificationId,
      title: 'Recordatorio: $title',
      body: 'Es hora de: $title',
      scheduledDate: dateTime,
    );
  }

  Future<void> _updateReminder(String reminderId, DateTime newDateTime, String newTitle) async {
    try {
      await _firestore.collection('reminders').doc(reminderId).update({
        'title': newTitle,
        'timestamp': newDateTime,
      });

      // Actualizar notificación si es necesario (si cambian la fecha/hora)
      final int notificationId = newDateTime.millisecondsSinceEpoch ~/ 1000;
      await NotificationService().scheduleNotification(
        id: notificationId,
        title: 'Recordatorio actualizado: $newTitle',
        body: 'Es hora de: $newTitle',
        scheduledDate: newDateTime,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recordatorio actualizado')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  Future<void> _deleteReminder(String reminderId) async {
    try {
      await _firestore.collection('reminders').doc(reminderId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recordatorio eliminado')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }

  void _showEditReminderDialog(String reminderId, String currentTitle, DateTime currentDateTime) {
    DateTime selectedDate = currentDateTime;
    TimeOfDay selectedTime = TimeOfDay(hour: selectedDate.hour, minute: selectedDate.minute);
    _titleController.text = currentTitle;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Editar recordatorio'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título del recordatorio',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Fecha: ${selectedDate.toLocal().toString().split(' ')[0]}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() => selectedDate = pickedDate);
                          }
                        },
                        child: const Text('Seleccionar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Hora: ${selectedTime.format(context)}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (pickedTime != null) {
                            setState(() => selectedTime = pickedTime);
                          }
                        },
                        child: const Text('Seleccionar'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    final updatedDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    await _updateReminder(reminderId, updatedDateTime, _titleController.text);
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddReminderDialog() {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nuevo recordatorio'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título del recordatorio',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Fecha: ${selectedDate.toLocal().toString().split(' ')[0]}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() => selectedDate = pickedDate);
                          }
                        },
                        child: const Text('Seleccionar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Hora: ${selectedTime.format(context)}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (pickedTime != null) {
                            setState(() => selectedTime = pickedTime);
                          }
                        },
                        child: const Text('Seleccionar'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    final scheduledDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    await _addReminder(scheduledDateTime);
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordatorios'),
        leading: IconButton(
          icon: const Icon(Icons.person),
          tooltip: 'Ver perfil',
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.perfil);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Test Noti',
            onPressed: () async {
              debugPrint('▶️ [Reminders] Test inmediato pulsado');
              try {
                await NotificationService().showNotification(
                  id: 999,
                  title: '🚀 Test Ahora',
                  body: 'Comprueba si se dispara esta notif.',
                );
                debugPrint('   — showNotification completado');
              } catch (e, s) {
                debugPrint('❌ Error en showNotification: $e\n$s');
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Disparando test inmediato...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.schedule_send),
            tooltip: 'Test programado 5s',
            onPressed: () async {
              final inFive = DateTime.now().add(const Duration(seconds: 5));
              debugPrint('▶️ [Reminders] Test programado pulsado');
              await NotificationService().scheduleNotification(
                id: 888,
                title: '⏰ Test programado',
                body: 'Esta notificación debe saltar en 5 s',
                scheduledDate: inFive,
              );
              debugPrint('   — Test programado finished call');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notificación programada en 5 s')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('reminders')
            .where('userId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay recordatorios aún'));
          }
          final reminders = snapshot.data!.docs;
          return ListView.builder(
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final reminder = reminders[index].data() as Map<String, dynamic>;
              final title = reminder['title'] ?? '';
              final Timestamp ts = reminder['timestamp'] as Timestamp? ?? Timestamp.now();
              final DateTime dateTime = ts.toDate();
              final reminderId = reminders[index].id; // ID del recordatorio

              return ListTile(
                title: Text(title),
                subtitle: Text('Fecha: ${dateTime.toLocal()}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditReminderDialog(reminderId, title, dateTime),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteReminder(reminderId),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReminderDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
