import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:proyecto_final_alejandro/routes/app_routes.dart';
import 'package:proyecto_final_alejandro/screens/supervised_reminders_screen.dart';
import 'package:proyecto_final_alejandro/screens/supervision_request_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  String? _photoUrl;
  bool _loading = false;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();  

  @override
  void initState() {
    super.initState();
  }

  String _generateCode() {
    final rnd = Random();
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += rnd.nextInt(10).toString();
    }
    return code;
  }

  Future<void> _pickAndUploadImage() async {
  final uid = _auth.currentUser?.uid;
  if (uid == null) return;

  final picked = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 80,
  );
  if (picked == null) return;

  setState(() => _loading = true);
  try {
    final file = File(picked.path);
    final ref = FirebaseStorage.instance
        .ref()
        .child('users/$uid/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final task = await ref.putFile(file);
    final url = await task.ref.getDownloadURL();

    // 1) Actualizo _photoUrl en memoria
    setState(() {
      _photoUrl = url;
    });

    // 2) Escribo inmediatamente en Firestore para que el perfil se actualice
    await _firestore.collection('users').doc(uid).set({
      'photoUrl': url,
    }, SetOptions(merge: true));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al subir imagen: $e')),
    );
  } finally {
    setState(() => _loading = false);
  }
}

  Future<void> _saveProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loading = true);
    try {
      await _firestore.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'photoUrl': _photoUrl,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar perfil: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.inicioSesion);
  }

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Confirmación al usuario
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          '¿Estás seguro? Esta acción eliminará tu cuenta y todos tus datos.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final uid = user.uid;
      // Eliminar documento en Firestore
      await _firestore.collection('users').doc(uid).delete();
      // Eliminar usuario de Auth
      await user.delete();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.inicioSesion);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar cuenta: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Elimina a `supUid` del array “supervisors” de **mi** documento.
  Future<void> _removeSupervised(String supUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    try {
      await _firestore.collection('users').doc(myUid).update({
        'supervisors': FieldValue.arrayRemove([supUid]),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se eliminó de personas que supervisas')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar supervisado: $e')),
      );
    }
  }

  /// Elimina a **mí** (mi UID) del array “supervisors” de `otherUid`.
  Future<void> _removeSupervisor(String otherUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    try {
      await _firestore.collection('users').doc(otherUid).update({
        'supervisors': FieldValue.arrayRemove([myUid]),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se eliminó de personas que me supervisan')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar supervisor: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      // Si no hay usuario logueado, volvemos al login.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, AppRoutes.inicioSesion);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Usamos un StreamBuilder para “escuchar” el documento de 'users/{uid}'
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            body: Center(child: Text('Error al cargar perfil')),
          );
        }

        // Aquí ya tenemos el documento “en vivo” de Firestore
        final data = snapshot.data!.data() as Map<String, dynamic>;

        // Establecemos los campos visuales a partir de Firestore
        _nameController.text = data['name'] as String? ?? '';
        _photoUrl = data['photoUrl'] as String?;

        // Código de supervisión (String) – si aún no existe, lo creamos
        String supervisionCode = data['supervisionCode'] as String? ?? '';
        if (supervisionCode.isEmpty) {
          // Si no hay supervisionCode, lo generamos y escribimos de una vez.
          supervisionCode = _generateCode();
          _firestore.collection('users').doc(uid).set({
            'supervisionCode': supervisionCode,
            'supervisors': <String>[], // array vacío
          }, SetOptions(merge: true));
        }

        // Leemos el array “supervisors” (UIDs de quienes supervisas tú):
        final List<dynamic>? supList = data['supervisors'] as List<dynamic>?;
        final mySupervisors = supList?.whereType<String>().toList() ?? <String>[];

        // Lista de solicitudes pendientes
        final List<dynamic>? pendList =
            data['pendingSupervisionRequests'] as List<dynamic>?;
        final myPending = pendList?.whereType<String>().toList() ?? <String>[];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mi Perfil'),
            actions: [
              // Icono que abre “Solicitudes de supervisión entrantes”
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.how_to_reg),
                    tooltip: 'Solicitudes entrantes',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupervisionRequestsScreen(),
                        ),
                      );
                    },
                  ),
                  if (myPending.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 20, minHeight: 20),
                        child: Text(
                          '${myPending.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_loading) const LinearProgressIndicator(),
              const SizedBox(height: 16),

              // Avatar y cambio de foto 
              Center(
                child: GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage:
                        _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                    child: _photoUrl == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.photo_camera),
                label: const Text('Cambiar foto'),
                onPressed: _pickAndUploadImage,
              ),
              const SizedBox(height: 24),

              // Campo nombre 
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveProfile,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Guardar perfil'),
                ),
              ),
              const SizedBox(height: 16),

              // Cerrar sesión / Eliminar cuenta 
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _signOut,
                  child: const Text('Cerrar sesión'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: _deleteAccount,
                  child: const Text('Eliminar cuenta'),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Código de supervisión 
              const Text(
                'Tu código de supervisión:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(
                supervisionCode,
                style: const TextStyle(fontSize: 20, letterSpacing: 2),
              ),
              const SizedBox(height: 16),

              // Botón para agregar supervisado 
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.group_add),
                  label: const Text('Agregar supervisado'),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.agregarSupervisado)
                        .then((_) {
                      // Al volver, el StreamBuilder ya se actualizará automáticamente
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Lista de personas que supervisas, o mensaje si está vacía 
              if (mySupervisors.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Personas que supervisas:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Un ListView.builder “anidado” dentro del ListView principal
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: mySupervisors.length,
                  itemBuilder: (context, idx) {
                    final supUid = mySupervisors[idx];
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(supUid).get(),
                      builder: (context, snap) {
                        if (!snap.hasData || !snap.data!.exists) {
                          return const ListTile(
                            leading: Icon(Icons.person),
                            title: Text('Cargando...'),
                          );
                        }
                        final userData =
                            snap.data!.data() as Map<String, dynamic>;
                        final name =
                            userData['name'] as String? ?? '(Sin nombre)';
                        final photo = 
                            userData['photoUrl'] as String?;

                        return ListTile(
                          leading: photo != null
                              ? CircleAvatar(backgroundImage: NetworkImage(photo))
                              : const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(name),
                          subtitle: Text('UID: $supUid'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Dejar de supervisar',
                            onPressed: () {
                              _removeSupervised(supUid);
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SupervisedRemindersScreen(
                                  superviseeUid: supUid,
                                  superviseeName: name,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text('Aún no supervisas a nadie'),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),

              // Sección: Personas que me supervisan 
              const Text(
                'Personas que me supervisan:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Usamos otro StreamBuilder que consulta “where supervisors array-contains miUid”
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('users')
                    .where('supervisors', arrayContains: uid)
                    .snapshots(),
                builder: (context, snap2) {
                  if (snap2.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap2.hasError) {
                    return Center(
                        child: Text('Error: ${snap2.error}'));
                  }
                  final docs = snap2.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Text('Nadie te está supervisando aún.');
                  }

                  return ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final docData = docs[i].data() as Map<String, dynamic>;
                      final otherUid = docs[i].id;
                      final otherName =
                          docData['name'] as String? ?? '(Sin nombre)';
                      final otherPhoto = 
                          docData['photoUrl'] as String?;
                      return ListTile(
                        leading: otherPhoto != null
                            ? CircleAvatar(backgroundImage: NetworkImage(otherPhoto))
                            : const CircleAvatar(child: Icon(Icons.person_outline)),
                        title: Text(otherName),
                        subtitle: Text('UID: $otherUid'),
                         trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Eliminar supervisor',
                          onPressed: () {
                            _removeSupervisor(otherUid);
                          },
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}