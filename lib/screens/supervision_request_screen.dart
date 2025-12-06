import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Pantalla que muestra las solicitudes de supervisión entrantes.
/// Aquí el usuario puede aceptar o rechazar peticiones de otros usuarios.
class SupervisionRequestsScreen extends StatelessWidget {
  const SupervisionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Solicitudes de Supervisión')),
        body: const Center(child: Text('No estás autenticado')),
      );
    }

    // StreamBuilder para escuchar “pendingSupervisionRequests” en mi doc
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de Supervisión')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return Center(child: Text('Error al cargar solicitudes, compruebe su conexion e intentelo de nuevo'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic>? pendList =
              data['pendingSupervisionRequests'] as List<dynamic>?;
          final myPending =
              pendList?.whereType<String>().toList() ?? <String>[];

          if (myPending.isEmpty) {
            return const Center(child: Text('No hay solicitudes pendientes.'));
          }

          return ListView.builder(
            itemCount: myPending.length,
            itemBuilder: (context, index) {
              final requesterUid = myPending[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(requesterUid)
                    .get(),
                builder: (context, snap2) {
                  if (!snap2.hasData || !snap2.data!.exists) {
                    return const ListTile(
                      leading: Icon(Icons.person),
                      title: Text('Cargando...'),
                    );
                  }
                  final requesterData =
                      snap2.data!.data() as Map<String, dynamic>;
                  final requesterName =
                      requesterData['name'] as String? ?? '(Sin nombre)';
                  final requesterPhoto = 
                            requesterData['photoUrl'] as String?;

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: requesterPhoto != null
                              ? CircleAvatar(backgroundImage: NetworkImage(requesterPhoto))
                              : const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(requesterName),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          // Botón Aceptar
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            tooltip: 'Aceptar',
                            onPressed: () async {
                              // Aceptar: quitar de pending y añadir a supervisors
                              final batch = FirebaseFirestore.instance.batch();
                              final myRef = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid);

                              final requesterRef = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(requesterUid);

                              // Quitar mi UID de su pendingSupervisionRequests
                              batch.update(myRef, {
                                'pendingSupervisionRequests':
                                    FieldValue.arrayRemove([requesterUid]),
                              });

                              // Añado en su array que yo le superviso
                              batch.update(requesterRef, {
                                'supervisors': FieldValue.arrayUnion([uid]),
                              });

                              await batch.commit();
                            },
                          ),

                          // Botón Rechazar
                          IconButton(
                            icon:
                                const Icon(Icons.cancel, color: Colors.redAccent),
                            tooltip: 'Rechazar',
                            onPressed: () async {
                              // Solo quitar de pendingSupervisionRequests:
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .update({
                                'pendingSupervisionRequests':
                                    FieldValue.arrayRemove([requesterUid])
                              });
                            },
                          ),
                        ],
                      ),
                    ),
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
