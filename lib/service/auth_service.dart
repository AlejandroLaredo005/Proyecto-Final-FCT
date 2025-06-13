import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Servicio de autenticación que encapsula los métodos
/// de registro, inicio de sesión, recuperación de contraseña
/// y gestión de sesión mediante Firebase Auth y Google Sign-In.
class AuthService {
  /// Instancia de FirebaseAuth para interactuar con el backend de Auth.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Registra un usuario con correo y contraseña.
  ///
  /// Devuelve un [UserCredential] con la información del usuario creado.
  /// Lanza una excepción si el registro falla.
  Future<UserCredential> registerWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Inicia sesión con correo y contraseña.
  ///
  /// Devuelve un [UserCredential] con la información del usuario autenticado.
  /// Lanza una excepción si la autenticación falla.
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Inicia sesión mediante Google Sign-In.
  ///
  /// Abre el flujo de autenticación de Google, obtiene los tokens necesarios
  /// y crea una credencial para Firebase. Devuelve el [User] autenticado
  /// o lanza una excepción si el usuario cancela o falla el proceso.
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

  /// Envía un correo de restablecimiento de contraseña al [email] indicado.
  ///
  /// Lanza una excepción si la operación falla.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Cierra la sesión del usuario actualmente autenticado.
  ///
  /// Limpia el estado de FirebaseAuth.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Obtiene el usuario actualmente autenticado, o `null` si no hay ninguno.
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
