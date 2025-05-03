import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Registrar usuario con email y contraseña
  Future<UserCredential> registerWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Iniciar sesión con email y contraseña
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Iniciar Sesion con Google
  Future<User?> signInWithGoogle() async {
    // Inicia el flujo de Google
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      // usuario canceló
      throw Exception('Inicio de sesión con Google cancelado');
    }

    // Obtén tokens de autenticación
    final googleAuth = await googleUser.authentication;

    // Crea credencial para Firebase
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Inicia sesión con Firebase
    final userCred = await _auth.signInWithCredential(credential);
    return userCred.user;
  }

  // Enviar correo para restablecer la contraseña
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Ver usuario actual
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
