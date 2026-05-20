import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_rest_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreRestService _rest = FirestoreRestService();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<bool> esProfesionalValido(String uid) async {
    try {
      final doc = await _rest.getProfesional(uid);
      return doc != null && (doc['activo'] as bool? ?? false);
    } catch (_) {
      return false;
    }
  }

  Future<void> crearProfesional({
    required String uid,
    required String nombre,
    required String email,
  }) async {
    await _rest.setProfesional(uid, {
      'id': uid,
      'nombre': nombre,
      'email': email,
      'activo': true,
      'creadoEn': DateTime.now().toIso8601String(),
    });
  }

  String? get currentEmail => _auth.currentUser?.email;
  String? get currentUid => _auth.currentUser?.uid;
}
