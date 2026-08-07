import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class FunctionsService {
  static const String _baseUrl =
      'https://us-central1-agendavisso.cloudfunctions.net';

  static Future<Map<String, String>> _headers() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await Future.delayed(const Duration(milliseconds: 100));
      user = FirebaseAuth.instance.currentUser;
    }
    if (user == null) throw Exception('No authenticated user');
    final token = await user.getIdToken().timeout(const Duration(seconds: 8));
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> call(String functionName, Map<String, dynamic> data) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$_baseUrl/$functionName'),
      headers: headers,
      body: jsonEncode({'data': data}),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body.containsKey('result')) return body['result'] as Map<String, dynamic>;
      if (body.containsKey('error')) {
        final err = body['error'] as Map<String, dynamic>;
        throw Exception('Error de función: ${err['message']} (${err['status']})');
      }
      return body as Map<String, dynamic>;
    } else {
      final body = jsonDecode(response.body);
      if (body.containsKey('error')) {
        final err = body['error'] as Map<String, dynamic>;
        throw Exception('Error de función: ${err['message']} (${err['status']})');
      }
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> crearFranquicia({
    required String codigo,
    required String nombre,
    String? direccion,
    String? telefonoContacto,
  }) async {
    return call('crearFranquicia', {
      'codigo': codigo,
      'nombre': nombre,
      'direccion': direccion ?? '',
      'telefonoContacto': telefonoContacto ?? '',
    });
  }

  static Future<Map<String, dynamic>> asignarProfesionalAFranquicia({
    required String uid,
    required String franquiciaId,
  }) async {
    return call('asignarProfesionalAFranquicia', {
      'uid': uid,
      'franquiciaId': franquiciaId,
    });
  }

  static Future<Map<String, dynamic>> crearProfesional({
    required String email,
    required String password,
    required String nombre,
    required String franquiciaId,
    String? documento,
  }) async {
    return call('crearProfesional', {
      'email': email,
      'password': password,
      'nombre': nombre,
      'documento': documento ?? '',
      'franquiciaId': franquiciaId,
    });
  }

  static Future<Map<String, dynamic>> editarProfesional({
    required String uid,
    String? nombre,
    String? email,
    String? password,
    String? documento,
    String? franquiciaId,
  }) async {
    return call('editarProfesional', {
      'uid': uid,
      if (nombre != null) 'nombre': nombre,
      if (email != null) 'email': email,
      if (password != null) 'password': password,
      if (documento != null) 'documento': documento,
      if (franquiciaId != null) 'franquiciaId': franquiciaId,
    });
  }

  static Future<Map<String, dynamic>> eliminarProfesional({
    required String uid,
  }) async {
    return call('eliminarProfesional', {'uid': uid});
  }
}