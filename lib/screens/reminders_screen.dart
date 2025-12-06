import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:proyecto_final_alejandro/background_task.dart';
import 'package:proyecto_final_alejandro/routes/app_routes.dart';
import 'package:workmanager/workmanager.dart';

/// Pantalla principal de recordatorios donde el usuario puede:
/// - Añadir nuevos recordatorios con opciones de recurrencia.
/// - Ver y filtrar recordatorios pendientes o completados.
/// - Editar, ver detalles o eliminar recordatorios existentes.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  /// Instancia de Firestore para acceder a la colección 'reminders'
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  /// Controlador de texto para el título del recordatorio
  final TextEditingController _titleController = TextEditingController();
  /// Controlador de texto para la descripción del recordatorio
  final TextEditingController _descriptionController = TextEditingController();
  /// Control para alternar la vista entre pendientes y completados
  bool _showCompleted = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Añade uno o varios recordatorios según la recurrencia seleccionada.
  /// - [firstDateTime]: fecha y hora del primer recordatorio.
  /// - [recurrence]: 'none', 'daily', 'weekly', o 'custom'.
  /// - [endDate]: fecha fin para recurrencia (si aplica).
  /// - [customIntervalDays]: intervalo en días para 'custom'.
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
      
      // Notificación principal en dt
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

      // Notificación de seguimiento 10 minutos despues
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

  /// Actualiza un recordatorio y reprograma notificaciones si es necesario.
  /// - Cancela tareas antiguas basadas en timestamp anterior.
  /// - Actualiza campos en Firestore.
  /// - Reprograma notificaciones si [completed] es false o nulo.
  Future<void> _updateReminder(
    String reminderId,
    DateTime newDateTime,
    String newTitle,
    String? newDescription, {
    bool? completed,
  }) async {
      try {
        // Obtengo el documento original para leer el timestamp antiguo:
        final docRef = _firestore.collection('reminders').doc(reminderId);
        final oldSnap = await docRef.get();
        DateTime? oldDateTime;
        if (oldSnap.exists) {
          final dataOld = oldSnap.data()! as Map<String, dynamic>;
          final Timestamp tsOld = dataOld['timestamp'] as Timestamp? ?? Timestamp.now();
          oldDateTime = tsOld.toDate();
        }

        // Calculo y cancelo las dos notificaciones antiguas (si existía oldDateTime):
        if (oldDateTime != null) {
          final oldBaseId = oldDateTime.millisecondsSinceEpoch ~/ 1000;
          final oldFollowUpId = oldBaseId + 1;
          await Workmanager().cancelByUniqueName(oldBaseId.toString());
          await Workmanager().cancelByUniqueName(oldFollowUpId.toString());
        }

        // Preparo el mapa de actualización en Firestore:
        final updatedData = <String, dynamic>{
          'title': newTitle,
          'timestamp': newDateTime,
          'description': newDescription ?? '',
        };
        if (completed != null) {
          updatedData['completed'] = completed;
        }
        await docRef.update(updatedData);

        // Si no estamos marcando como “completado” (o completed == false),
        // programo las dos nuevas notificaciones en base a newDateTime:
        if (completed == null || completed == false) {
          // Identificadores únicos para la nueva fecha:
          final newBaseId = newDateTime.millisecondsSinceEpoch ~/ 1000;
          final newFollowUpId = newBaseId + 1;

          // Datos comunes para cada notificación:
          final commonData = {
            'docId': reminderId,
            'title': newTitle,
          };

          // Notificación a la hora:
          final delayA = newDateTime.difference(DateTime.now());
          await Workmanager().registerOneOffTask(
            newBaseId.toString(),
            notificationTask,
            initialDelay: delayA.isNegative ? Duration.zero : delayA,
            inputData: {
              ...commonData,
              'id':   newBaseId,
              'title': 'Recordatorio: $newTitle',
              'body':  'Es hora de: $newTitle',
              'mode':  'notifyIfPending',
            },
            existingWorkPolicy: ExistingWorkPolicy.replace,
          );

          // Notificación de seguimiento 10 min después:
          final followUpTime = newDateTime.add(const Duration(minutes: 10));
          final delayB = followUpTime.difference(DateTime.now());
          await Workmanager().registerOneOffTask(
            newFollowUpId.toString(),
            notificationTask,
            initialDelay: delayB.isNegative ? Duration.zero : delayB,
            inputData: {
              ...commonData,
              'id':    newFollowUpId,
              'title': '🔔 Recordatorio pendiente: $newTitle',
              'body':  'Si no has completado "$newTitle", aún estás a tiempo',
              'mode':  'notifyIfPending',
            },
            existingWorkPolicy: ExistingWorkPolicy.replace,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recordatorio actualizado')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el recordatorio, compruebe los datos e intentelo de nuevoS')),
      );
    }
  }

  /// Elimina un recordatorio de Firestore y cancela sus notificaciones
  Future<void> _deleteReminder(String reminderId) async {
  try {
    // Obtengo el documento para leer su timestamp:
    final docSnap = await _firestore.collection('reminders').doc(reminderId).get();
    if (docSnap.exists) {
      final data = docSnap.data() as Map<String, dynamic>;
      final Timestamp ts = data['timestamp'] as Timestamp? ?? Timestamp.now();
      final DateTime dt = ts.toDate();

      // Calculo los dos IDs que programamos originalmente:
      final baseId = dt.millisecondsSinceEpoch ~/ 1000;
      final followUpId = baseId + 1;

      // Cancelo las dos tareas programadas en Workmanager:
      await Workmanager().cancelByUniqueName(baseId.toString());
      await Workmanager().cancelByUniqueName(followUpId.toString());
    }

    // Ahora sí borro el documento de Firestore:
    await _firestore.collection('reminders').doc(reminderId).delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recordatorio eliminado')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al eliminar el recordatorio, intentelo de nuevo')),
    );
  }
}

  /// Muestra un diálogo modal para editar un recordatorio existente.
  ///
  /// Parámetros:
  /// - [reminderId]: ID del documento de Firestore del recordatorio a editar.
  /// - [currentTitle]: título actual del recordatorio.
  /// - [currentDescription]: descripción actual (opcional).
  /// - [currentDateTime]: fecha y hora actuales del recordatorio.
  ///
  /// El diálogo incluye campos para modificar título, descripción, fecha y hora.
  /// Al guardar, llama a [_updateReminder] para aplicar los cambios y reprogramar notificaciones.
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

  /// Muestra un diálogo modal para crear un nuevo recordatorio.
  ///
  /// Inicializa valores por defecto para fecha, hora, tipo de recurrencia,
  /// fecha de fin y días de intervalo personalizado. Permite al usuario:
  /// - Escribir título y descripción.
  /// - Seleccionar fecha y hora.
  /// - Elegir repetición (ninguna, diaria, semanal o cada X días).
  /// - Si aplica, indicar hasta cuándo se repite.
  /// Al pulsar "Guardar", construye la fecha completa y llama a [_addReminder].
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

  /// Lógica para usar un DateFormat para adaptar la fecha al formato que queremos
  String _formatDateTime(DateTime dt) {
    final df = DateFormat('MMM dd, yyyy  •  HH:mm');
    return df.format(dt);
  }

  /// Muestra un diálogo de solo lectura con detalles de un recordatorio.
  ///
  /// Parámetros:
  /// - [id]: ID interno del recordatorio (no se muestra, pero sirve referencia).
  /// - [title]: Título que aparecerá en el encabezado.
  /// - [dateTime]: Fecha y hora programadas.
  /// - [description]: Descripción opcional.
  /// - [completed]: Estado (true = completado, false = pendiente).
  ///
  /// El diálogo incluye:
  /// 1. Fecha y hora formateadas en negrita.
  /// 2. Texto “Descripción:” subrayado y el contenido si existe.
  /// 3. Texto “Estado:” en negrita y “Completado” o “Pendiente” según corresponda.
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
                _formatDateTime(dateTime),
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
          icon: const Icon(Icons.add),
          tooltip: 'Agregar recordatorio',
          onPressed: _showAddReminderDialog,
        ),
        ],
      ),
      body: Column(
      children: [
        const SizedBox(height: 8),
        // ChoiceChips para alternar pendientes/completados
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
        // Lista filtrada dentro de Expanded
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
                return Center(child: Text('Error al cargar, compruebe su conexion e intentelo de nuevo'));
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

                  return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _ReminderCard(
                        id: id,
                        title: title,
                        description: description,
                        date: date,
                        done: done,
                        formatDate: _formatDateTime,
                        onToggleCompleted: (value) {
                          _updateReminder(id, date, title, description, completed: value);
                        },
                        onEdit: () {
                          _showEditReminderDialog(id, title, description, date);
                        },
                        onDelete: () {
                          _deleteReminder(id);
                        },
                        onTap: () {
                          _showViewReminderDialog(id, title, date, description, completed);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget que aplica estilos a cada recordatorio y asigna el fondo según:
///  - si ya pasó: rojo suave
///  - si falta ≤ 24 h: amarillo suave
///  - si falta > 24 h: verde suave
///  - si está completado: gris suave
class _ReminderCard extends StatelessWidget {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final bool done;
  final String Function(DateTime) formatDate;
  final ValueChanged<bool?> onToggleCompleted;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ReminderCard({
    required this.id,
    required this.title,
    required this.date,
    required this.done,
    required this.formatDate,
    required this.onToggleCompleted,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    // Determinar el color de fondo según la fecha y si está completado:
    final now = DateTime.now();
    Color bgColor;

    if (done) {
      bgColor = Colors.grey.shade100;
    } else {
      final diff = date.difference(now);

      if (diff.isNegative) {
        // Fecha ya pasada
        bgColor = Colors.red.shade100;
      } else if (diff.inHours <= 24) {
        // Fecha dentro de las próximas 24 horas
        bgColor = Colors.yellow.shade100;
      } else {
        // Fecha a más de 24 horas
        bgColor = Colors.green.shade100;
      }
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: bgColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox circular para marcar pendiente/completado
              Checkbox(
                value: done,
                onChanged: onToggleCompleted,
                shape: const CircleBorder(),
              ),

              const SizedBox(width: 8),

              // Columna con título, descripción breve y fecha
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título (tachado si está completado)
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Si hay descripción, la mostramos hasta 2 líneas
                    if (description != null && description!.isNotEmpty) ...[
                      Text(
                        description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Fecha formateada
                    Text(
                      formatDate(date),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Botones de editar y eliminar
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    color: Colors.blueAccent,
                    tooltip: 'Editar',
                    onPressed: onEdit,
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: Colors.redAccent,
                    tooltip: 'Eliminar',
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
