import 'package:cloud_firestore/cloud_firestore.dart';
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
    final _firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text('Recordatorios de $superviseeName'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('reminders')
            .where('userId', isEqualTo: superviseeUid)
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
              final data = reminders[index].data() as Map<String, dynamic>;
              final title = data['title'] as String? ?? '';
              final Timestamp ts = data['timestamp'] as Timestamp? ?? Timestamp.now();
              final dateTime = ts.toDate();
              final description = data['description'] as String?;
              final completed = data['completed'] as bool? ?? false;

              return ListTile(
                title: Text(title),
                subtitle: Text('Fecha: ${dateTime.toLocal()}'),
                onTap: () {
                  // Mostrar detalle al pulsar (solo lectura)
                  showDialog(
                    context: context,
                    builder: (ctx) {
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
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
