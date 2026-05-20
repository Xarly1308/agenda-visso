import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/sede.dart';
import '../models/horario.dart';
import '../models/cita.dart';
import '../models/paciente.dart';
import '../models/excepcion.dart';

class FirestoreRestService {
  static const String _project = 'agendavisso';
  static const String _baseUrl = 'https://firestore.googleapis.com/v1/projects/'
      '$_project/databases/(default)/documents';

  final http.Client _client = http.Client();
  final Uuid _uuid = const Uuid();

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _url(String path) => Uri.parse('$_baseUrl$path');

  Map<String, dynamic> _fieldsToMap(Map<String, dynamic> fields) {
    return fields.map((key, value) {
      if (value.containsKey('stringValue')) return MapEntry(key, value['stringValue']);
      if (value.containsKey('integerValue')) return MapEntry(key, int.parse(value['integerValue']));
      if (value.containsKey('booleanValue')) return MapEntry(key, value['booleanValue']);
      if (value.containsKey('doubleValue')) return MapEntry(key, double.parse(value['doubleValue']));
      if (value.containsKey('timestampValue')) return MapEntry(key, value['timestampValue']);
      if (value.containsKey('nullValue')) return MapEntry(key, null);
      return MapEntry(key, value.toString());
    });
  }

  Map<String, dynamic> _toFields(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is String) return MapEntry(key, {'stringValue': value});
      if (value is bool) return MapEntry(key, {'booleanValue': value});
      if (value is int) return MapEntry(key, {'integerValue': value.toString()});
      if (value is double) return MapEntry(key, {'doubleValue': value.toString()});
      if (value == null) return MapEntry(key, {'nullValue': null});
      return MapEntry(key, {'stringValue': value.toString()});
    });
  }

  String _docId(String name) => name.split('/').last;

  Future<List<Sede>> getSedes() async {
    final body = {
      'structuredQuery': {
        'from': [{'collectionId': 'sedes'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'activa'},
            'op': 'EQUAL',
            'value': {'booleanValue': true}
          }
        }
      }
    };
    final response = await _client.post(
      _url(':runQuery'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al cargar sedes: ${response.statusCode}');
    }
    final results = jsonDecode(response.body) as List;
    return results
        .where((r) => r.containsKey('document'))
        .map((r) => Sede.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<Map<String, String>> getProfesionales() async {
    final body = {
      'structuredQuery': {
        'from': [{'collectionId': 'profesionales'}]
      }
    };
    final response = await _client.post(
      _url(':runQuery'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al cargar profesionales: ${response.statusCode}');
    }
    final results = jsonDecode(response.body) as List;
    return {
      for (final r in results.where((r) => r.containsKey('document')))
        _docId(r['document']['name']):
        _fieldsToMap(r['document']['fields'])['nombre'] as String? ?? 'Profesional'
    };
  }

  Future<List<Horario>> getHorarios(String profesionalId) async {
    final body = {
      'structuredQuery': {
        'from': [{'collectionId': 'horarios'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'profesionalId'},
            'op': 'EQUAL',
            'value': {'stringValue': profesionalId}
          }
        }
      }
    };
    final response = await _client.post(
      _url(':runQuery'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al cargar horarios: ${response.statusCode}');
    }
    final results = jsonDecode(response.body) as List;
    return results
        .where((r) => r.containsKey('document'))
        .map((r) => Horario.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Excepcion>> getExcepciones(String profesionalId) async {
    final body = {
      'structuredQuery': {
        'from': [{'collectionId': 'excepciones'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'profesionalId'},
            'op': 'EQUAL',
            'value': {'stringValue': profesionalId}
          }
        }
      }
    };
    final response = await _client.post(
      _url(':runQuery'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al cargar excepciones: ${response.statusCode}');
    }
    final results = jsonDecode(response.body) as List;
    return results
        .where((r) => r.containsKey('document'))
        .map((r) => Excepcion.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Cita>> getCitas(String profesionalId, DateTime fecha) async {
    final fechaStr = fecha.toIso8601String().split('T')[0];
    final body = {
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'profesionalId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': profesionalId}
                }
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'EQUAL',
                  'value': {'stringValue': fechaStr}
                }
              }
            ]
          }
        }
      }
    };
    final response = await _client.post(
      _url(':runQuery'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al cargar citas: ${response.statusCode}');
    }
    final results = jsonDecode(response.body) as List;
    return results
        .where((r) => r.containsKey('document'))
        .map((r) => Cita.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<Paciente?> buscarPaciente(String documento) async {
    final body = {
      'structuredQuery': {
        'from': [{'collectionId': 'pacientes'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'documento'},
            'op': 'EQUAL',
            'value': {'stringValue': documento}
          }
        },
        'limit': 1
      }
    };
    final response = await _client.post(
      _url(':runQuery'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al buscar paciente: ${response.statusCode}');
    }
    final results = jsonDecode(response.body) as List;
    final docs = results.where((r) => r.containsKey('document')).toList();
    if (docs.isEmpty) return null;
    return Paciente.fromMap(_fieldsToMap(docs.first['document']['fields']));
  }

  Future<Paciente> crearPaciente({
    required String documento,
    required String nombres,
    required String telefono,
    String? email,
    bool yaEraPaciente = false,
  }) async {
    final id = _uuid.v4();
    final paciente = Paciente(
      id: id,
      documento: documento,
      nombres: nombres,
      telefono: telefono,
      email: email,
      yaEraPaciente: yaEraPaciente,
    );
    final response = await _client.post(
      _url('/pacientes?documentId=$id'),
      headers: await _headers(),
      body: jsonEncode({'fields': _toFields(paciente.toMap())}),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al crear paciente: ${response.statusCode}');
    }
    return paciente;
  }

  Future<Cita> crearCita({
    required String profesionalId,
    required String sedeId,
    required String pacienteId,
    required DateTime fecha,
    required String hora,
    String? pacienteNombre,
    String? creadoPor,
    String? tipoConsulta,
  }) async {
    final id = _uuid.v4();
    final cita = Cita(
      id: id,
      profesionalId: profesionalId,
      sedeId: sedeId,
      pacienteId: pacienteId,
      fecha: fecha,
      hora: hora,
      estado: 'pendiente',
      pacienteNombre: pacienteNombre,
      creadoPor: creadoPor,
      tipoConsulta: tipoConsulta,
    );
    final response = await _client.post(
      _url('/citas?documentId=$id'),
      headers: await _headers(),
      body: jsonEncode({'fields': _toFields(cita.toMap())}),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al crear cita: ${response.statusCode}');
    }
    return cita;
  }
}
