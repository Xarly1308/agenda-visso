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
  String? _franquiciaId;
  String? _franquiciaNombre;
  String? _franquiciaOriginalId;
  bool _esDesarrollador = false;

  User? get user => _user;
  bool get cargando => _cargando;
  bool get estaLogueado => _user != null;
  String? get error => _error;
  String get nombreUsuario => _nombreUsuario;
  String? get franquiciaId => _franquiciaId;
  String? get franquiciaNombre => _franquiciaNombre;
  String? get franquiciaOriginalId => _franquiciaOriginalId;
  bool get esDesarrollador => _esDesarrollador;
  bool get viendoOtraFranquicia => _esDesarrollador && _franquiciaId != _franquiciaOriginalId;
  Future<void>? _cargaSesion;

  Future<void> get sesionCargada => _cargaSesion ?? Future.value();

  AuthProvider() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      if (user != null) _cargaSesion = _cargarNombre(user.uid);
      notifyListeners();
    });
  }

  Future<void> _cargarNombre(String uid) async {
    try {
      final doc = await _rest.getProfesional(uid);
      if (doc != null) {
        _nombreUsuario = doc['nombre'] as String? ?? '';
        _franquiciaId = doc['franquiciaId'] as String?;
        if (_franquiciaId != null && _franquiciaId!.isNotEmpty) {
          FirestoreRestService.franquiciaActual = _franquiciaId;
          _franquiciaOriginalId = _franquiciaId;
          try {
            final fr = await _rest.getFranquicia(_franquiciaId!);
            _franquiciaNombre = fr?['nombre'] as String? ?? _franquiciaId;
          } catch (_) {
            _franquiciaNombre = _franquiciaId;
          }
        } else {
          FirestoreRestService.franquiciaActual = null;
          _franquiciaNombre = null;
        }
        try {
          _esDesarrollador = await _rest.esDesarrollador(uid);
        } catch (_) {
          _esDesarrollador = false;
        }
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
    _franquiciaId = null;
    _franquiciaNombre = null;
    _franquiciaOriginalId = null;
    _esDesarrollador = false;
    FirestoreRestService.franquiciaActual = null;
    notifyListeners();
  }

  Future<void> switchFranquicia(String franquiciaId, String nombre) async {
    _franquiciaId = franquiciaId;
    _franquiciaNombre = nombre;
    FirestoreRestService.franquiciaActual = franquiciaId;
    notifyListeners();
  }

  Future<void> volverAMiFranquicia() async {
    if (_franquiciaOriginalId == null) return;
    _franquiciaId = _franquiciaOriginalId;
    FirestoreRestService.franquiciaActual = _franquiciaOriginalId;
    try {
      final fr = await _rest.getFranquicia(_franquiciaOriginalId!);
      _franquiciaNombre = fr?['nombre'] as String? ?? _franquiciaOriginalId;
    } catch (_) {
      _franquiciaNombre = _franquiciaOriginalId;
    }
    notifyListeners();
  }

  Future<bool> recuperarPassword(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  void limpiarError() {
    _error = null;
    notifyListeners();
  }
}
