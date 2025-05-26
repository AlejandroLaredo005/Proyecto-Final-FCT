import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddSupervisedScreen extends StatefulWidget {
  const AddSupervisedScreen({super.key});

  @override
  State<AddSupervisedScreen> createState() => _AddSupervisedScreenState();
}

class _AddSupervisedScreenState extends State<AddSupervisedScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _sendRequest() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Introduce un código válido');
      return;
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Buscamos el usuario con ese supervisionCode:
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('supervisionCode', isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _error = 'Código no válido');
      } else {
        final targetDoc = query.docs.first;
        final targetUid = targetDoc.id;

        // Evitar auto-solicitud:
        if (targetUid == myUid) {
          setState(() => _error = 'No puedes solicitar supervisión a ti mismo.');
        } else {
          // 1) Revisar si ya existe petición pendiente:
          final List<dynamic>? pendientes =
              targetDoc.data()['pendingSupervisionRequests'] as List<dynamic>?;

          if (pendientes != null && pendientes.contains(myUid)) {
            setState(() => _error = 'Ya has enviado una solicitud pendiente.');
          } else {
            // 2) Añadimos a array “pendingSupervisionRequests” de target:
            await FirebaseFirestore.instance
                .collection('users')
                .doc(targetUid)
                .update({
              'pendingSupervisionRequests': FieldValue.arrayUnion([myUid]),
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Solicitud enviada')),
            );
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      setState(() => _error = 'Error al enviar solicitud: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar supervisado')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Introduce el código de supervisión de la persona que deseas vigilar.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Código de supervisión',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendRequest,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Agregar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
