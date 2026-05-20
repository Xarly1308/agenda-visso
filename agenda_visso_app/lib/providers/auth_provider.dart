import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_rest_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreRestService _rest = FirestoreRestService();
  User? _user;
  bool _cargando = false;
  String? _error;
  String _nombreUsuario = '';

  User? get user => _user;
  bool get cargando => _cargando;
  bool get estaLogueado => _user != null;
  String? get error => _error;
  String get nombreUsuario => _nombreUsuario;

  AuthProvider() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      if (user != null) _cargarNombre(user.uid);
      notifyListeners();
    });
  }

  Future<void> _cargarNombre(String uid) async {
    try {
      final doc = await _rest.getProfesional(uid);
      if (doc != null) {
        _nombreUsuario = doc['nombre'] as String? ?? '';
      }
    } catch (_) {
      _nombreUsuario = '';
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    late final UserCredential cred;
    try {
      cred = await _authService.login(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      _error = _mensajeErrorFirebase(e.code);
      _cargando = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error de conexión: verifica tu internet';
      _cargando = false;
      notifyListeners();
      return false;
    }

    try {
      final valido = await _authService.esProfesionalValido(cred.user!.uid);
      if (!valido) {
        await _authService.logout();
        _error = 'Usuario no autorizado como profesional';
        _cargando = false;
        notifyListeners();
        return false;
      }
      await _cargarNombre(cred.user!.uid);
      _cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al validar profesional: verifica tu conexión';
      _cargando = false;
      notifyListeners();
      return false;
    }
  }

  String _mensajeErrorFirebase(String code) {
    switch (code) {
      case 'INVALID_LOGIN_CREDENTIALS':
      case 'WRONG_PASSWORD':
      case 'INVALID_PASSWORD':
      case 'INVALID_EMAIL':
      case 'USER_NOT_FOUND':
        return 'Correo o contraseña incorrectos';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Demasiados intentos. Intenta más tarde';
      case 'USER_DISABLED':
        return 'Usuario deshabilitado';
      case 'EMAIL_NOT_FOUND':
        return 'No existe una cuenta con ese correo';
      default:
        return 'Error al iniciar sesión ($code)';
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _nombreUsuario = '';
    notifyListeners();
  }

  void limpiarError() {
    _error = null;
    notifyListeners();
  }
}
