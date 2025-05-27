import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:proyecto_final_alejandro/background_task.dart';
import 'package:proyecto_final_alejandro/routes/app_routes.dart';
import 'package:proyecto_final_alejandro/service/notification_service.dart';
import 'package:workmanager/workmanager.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _showCompleted = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addReminder(DateTime firstDateTime, String recurrence, DateTime? endDate, int customIntervalDays) async {
    final String title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    // Determinar cuántas semanas generar
    List<DateTime> dates = [];
    if (recurrence == 'weekly' && endDate != null) {
      var cursor = firstDateTime;
      while (!cursor.isAfter(endDate)) {
        dates.add(cursor);
        cursor = cursor.add(const Duration(days: 7));
      }
    } else if (recurrence == 'daily' && endDate != null){
        var cursor = firstDateTime;
        while (!cursor.isAfter(endDate)) {
          dates.add(cursor);
          cursor = cursor.add(const Duration(days: 1));
        }
    } else if (recurrence == 'custom' && endDate != null) {
        var cursor = firstDateTime;
        while (!cursor.isAfter(endDate)) {
          dates.add(cursor);
          cursor = cursor.add(Duration(days: customIntervalDays));
        }
    } else {
        dates.add(firstDateTime);
    }

    for (var dt in dates) {
      // Añade el recordatorio y captura la referencia
      final docRef = await _firestore.collection('reminders').add({
        'title': title,
        'description':  description.isEmpty ? null : description,
        'timestamp': dt,
        'userId': user?.uid,
        'completed': false,
      });

      // Identificadores únicos para cada noti
      final baseId = dt.millisecondsSinceEpoch ~/ 1000;
      final followUpId = baseId + 1; // distinto del principal

      // Datos comunes para inputData
      final commonData = {
        'docId': docRef.id,   
        'title': title,
      };
      
      // A) Notificación principal en dt
      final delay = dt.difference(DateTime.now());
      Workmanager().registerOneOffTask(
        baseId.toString(),  // unique name
        notificationTask,
        initialDelay: delay.isNegative ? Duration.zero : delay,
        inputData: {
          ...commonData,
          'id':   baseId,
          'title': 'Recordatorio: $title',
          'body':  'Es hora de: $title',
          'mode':   'notifyIfPending',
        },
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      // B) Notificación de seguimiento 10 minutos despues
      final followUpTime = dt.add(const Duration(minutes: 10));
      Workmanager().registerOneOffTask(
        followUpId.toString(),
        notificationTask,
        initialDelay: followUpTime.difference(DateTime.now()).isNegative
            ? Duration.zero
            : followUpTime.difference(DateTime.now()),
        inputData: {
          ...commonData,
          'id':    followUpId,
          'title': '🔔 Recordatorio pendiente: $title',
          'body':  'Si no has completado "$title", aún estás a tiempo',
          'mode':   'notifyIfPending',
        },
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    }

    _titleController.clear();
    _descriptionController.clear();
  }

  Future<void> _updateReminder(String reminderId, DateTime newDateTime, String newTitle, String? newDescription, {bool? completed}) async {
    try {
      final data = {
        'title': newTitle,
        'timestamp': newDateTime,
        'description': newDescription ?? '',
      };
      if (completed != null) {
        data['completed'] = completed;
      }
      await _firestore.collection('reminders').doc(reminderId).update(data);

      // Actualizar notificación si es necesario (si cambian la fecha/hora)
      if (completed == null || completed == false){
        final int notificationId = newDateTime.millisecondsSinceEpoch ~/ 1000;
        await NotificationService().scheduleNotification(
          id: notificationId,
          title: 'Recordatorio actualizado: $newTitle',
          body: 'Es hora de: $newTitle',
          scheduledDate: newDateTime,
        );
      }

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

  void _showEditReminderDialog(String reminderId, String currentTitle, String? currentDescription, DateTime currentDateTime) {
    DateTime selectedDate = currentDateTime;
    TimeOfDay selectedTime = TimeOfDay(hour: selectedDate.hour, minute: selectedDate.minute);
    _titleController.text = currentTitle;
    _descriptionController.text = currentDescription ?? '';

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

                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      border: OutlineInputBorder(),
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
                    await _updateReminder(reminderId, updatedDateTime, _titleController.text, _descriptionController.text);
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

    DateTime? _recurrenceEndDate;
    _recurrenceEndDate = null;
    String _recurrence = 'none';        // 'none', 'daily  o 'weekly'
    int _customIntervalDays = 1;        // para 'custom'

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

                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      border: OutlineInputBorder(),
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

                  const SizedBox(height: 16),

                  // Selector de recurrencia
                  DropdownButtonFormField<String>(
                    value: _recurrence,
                    decoration: const InputDecoration(labelText: 'Repetir'),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('Sin repetición')),
                      DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                      DropdownMenuItem(value: 'daily', child: Text('Diaria')),
                      DropdownMenuItem(value: 'custom', child: Text('Cada X días')),
                    ],
                    onChanged: (v) => setState(() => _recurrence = v!),
                  ),

                  // Si es custom, pedir intervalo
                  if (_recurrence == 'custom') ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      const Text('Intervalo (días):'),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true),
                          onChanged: (txt) {
                            final val = int.tryParse(txt);
                            if (val != null && val > 0) setState(() => _customIntervalDays = val);
                          },
                          controller: TextEditingController(text: '$_customIntervalDays'),
                        ),
                      ),
                    ]),
                  ],

                  // Si elige semanal, diaria o custom, pedimos fecha fin
                  if (_recurrence != 'none') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(_recurrenceEndDate == null
                              ? 'Fecha de fin: --/--/----'
                              : 'Fin: ${_recurrenceEndDate!.toLocal().toString().split(" ")[0]}'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final end = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: selectedDate,
                              lastDate: DateTime(2100),
                            );
                            if (end != null) setState(() => _recurrenceEndDate = end);
                          },
                          child: const Text('Seleccionar fin'),
                        ),
                      ],
                    ),
                  ],
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
                    await _addReminder(scheduledDateTime, _recurrence, _recurrenceEndDate, _customIntervalDays);
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

  void _showViewReminderDialog(
    String id,
    String title,
    DateTime dateTime,
    String? description,
    bool completed,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fecha: ${dateTime.toLocal().toString().split('.')[0]}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (description != null && description.isNotEmpty) ...[
                const Text(
                  'Descripción:',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
                const SizedBox(height: 4),
                Text(description),
                const SizedBox(height: 8),
              ],
              const Text(
                'Estado:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(completed ? 'Completado' : 'Pendiente'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
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
      body: Column(
      children: [
        const SizedBox(height: 8),
        // 1) ChoiceChips para alternar pendientes/completados
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Pendientes'),
              selected: !_showCompleted,
              onSelected: (_) => setState(() => _showCompleted = false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Completados'),
              selected: _showCompleted,
              onSelected: (_) => setState(() => _showCompleted = true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 2) Lista filtrada dentro de Expanded
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
              .collection('reminders')
              .where('userId', isEqualTo: user?.uid)
              .where('completed', isEqualTo: _showCompleted)             
              .orderBy('timestamp', descending: false)
              .snapshots(),
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
                  child: Text(_showCompleted
                      ? 'No hay completados'
                      : 'No hay pendientes'),
                );
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc    = docs[i];
                  final data   = doc.data()! as Map<String, dynamic>;
                  final title  = data['title'] as String? ?? '';
                  final ts     = data['timestamp'] as Timestamp;
                  final date   = ts.toDate();
                  final done   = data['completed']  as bool? ?? false;
                  final id      = doc.id;
                  final description = data['description'] as String?;
                  final completed   = data['completed'] as bool? ?? false;

                  return ListTile(
                    // 3) Checkbox para marcar completed
                    leading: Checkbox(
                      value: done,
                      onChanged: (chk) {
                        _updateReminder(id, date, title, description, completed: chk);
                      },
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        decoration: done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      ),
                    ),
                    subtitle: Text('Fecha: ${date.toLocal()}'),
                    onTap: () => _showViewReminderDialog(
                  id, title, date, description, completed),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditReminderDialog(id, title, description, date),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteReminder(id),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReminderDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
