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

  Future<void> _addByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Busca usuario cuyo supervisionCode == code
      final querySnap = await FirebaseFirestore.instance
          .collection('users')
          .where('supervisionCode', isEqualTo: code)
          .limit(1)
          .get();

      if (querySnap.docs.isEmpty) {
        setState(() => _error = 'Código no válido');
        return;
      }

      final targetDoc = querySnap.docs.first;
      final targetUid = targetDoc.id;

      final myUid = FirebaseAuth.instance.currentUser?.uid;
      if (myUid == null) {
        setState(() => _error = 'Debes iniciar sesión');
        return;
      }
      if (targetUid == myUid) {
        setState(() => _error = 'No puedes supervisarte a ti mismo');
        return;
      }

      // Guardo en mi array “supervisors” el UID de quien voy a supervisar.
      final myRef = FirebaseFirestore.instance.collection('users').doc(myUid);
      await myRef.update({
        'supervisors': FieldValue.arrayUnion([targetUid]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Ahora supervisas a esta persona')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Error: $e');
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
                onPressed: _loading ? null : _addByCode,
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
