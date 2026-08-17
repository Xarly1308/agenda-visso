import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sede.dart';
import '../models/horario.dart';
import '../models/paciente.dart';
import '../models/cita.dart';
import '../models/excepcion.dart';
import '../models/notificacion.dart';
import '../models/tipo_consulta.dart';

class FirestoreRestService {
  static const String _project = 'agendavisso';
  static const String _baseUrl = 'https://firestore.googleapis.com/v1/projects/'
      '$_project/databases/(default)/documents';

  // Franquicia activa de la sesión. Cuando es no vacía, todas las consultas
  // filtran por franquiciaId y las escrituras lo incluyen automáticamente.
  static String? franquiciaActual;

  final http.Client _client = http.Client();
  final Uuid _uuid = const Uuid();

  Map<String, dynamic>? _withFranquicia(Map<String, dynamic>? where) {
    final f = franquiciaActual;
    if (f == null || f.isEmpty) return where;
    final franquiciaFilter = {
      'fieldFilter': {
        'field': {'fieldPath': 'franquiciaId'},
        'op': 'EQUAL',
        'value': {'stringValue': f},
      },
    };
    if (where == null) return franquiciaFilter;
    if (where.containsKey('fieldFilter')) {
      return {
        'compositeFilter': {
          'op': 'AND',
          'filters': [franquiciaFilter, where],
        },
      };
    }
    if (where.containsKey('compositeFilter')) {
      final filters = (where['compositeFilter'] as Map)['filters'] as List;
      return {
        'compositeFilter': {
          'op': 'AND',
          'filters': [franquiciaFilter, ...filters],
        },
      };
    }
    return where;
  }

  Map<String, dynamic> _withFranquiciaEnDatos(Map<String, dynamic> data) {
    final f = franquiciaActual;
    if (f == null || f.isEmpty || data.containsKey('franquiciaId')) return data;
    return {...data, 'franquiciaId': f};
  }

  Future<Map<String, String>> _headers() async {
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

  String _docName(String collection, String id) =>
      '$_baseUrl/$collection/$id';

  Future<List<dynamic>> _runQuery(Map<String, dynamic> query) async {
    final response = await _client
        .post(_url(':runQuery'), headers: await _headers(), body: jsonEncode(query))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      debugPrint('Firestore runQuery error ${response.statusCode}: ${response.body}');
      throw Exception('Query error (${response.statusCode}): ${response.body}');
    }
    final results = jsonDecode(response.body) as List;
    return results.where((r) => r.containsKey('document')).toList();
  }

  Future<void> _setDocument(String collection, String id, Map<String, dynamic> data) async {
    final response = await _client
        .post(_url('/$collection?documentId=$id'), headers: await _headers(),
            body: jsonEncode({'fields': _toFields(_withFranquiciaEnDatos(data))}))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Error al crear $collection: ${response.statusCode}');
    }
  }

  Future<void> _updateDocument(String collection, String id, Map<String, dynamic> data) async {
    final mask = data.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
    final uri = Uri.parse('$_baseUrl/$collection/$id?$mask');
    final response = await _client
        .patch(uri, headers: await _headers(),
            body: jsonEncode({'fields': _toFields(data)}))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar $collection: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> _getDocument(String collection, String id) async {
    final response = await _client
        .get(_url('/$collection/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Error al obtener $collection: ${response.statusCode}');
    }
    final doc = jsonDecode(response.body);
    return _fieldsToMap(doc['fields']);
  }

  Future<void> _commit(List<Map<String, dynamic>> writes) async {
    final response = await _client
        .post(Uri.parse('$_baseUrl:commit'), headers: await _headers(),
            body: jsonEncode({'writes': writes}))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Commit error (${response.statusCode}): ${response.body}');
    }
  }

  Future<void> _deleteDocument(String collection, String id) async {
    final response = await _client
        .delete(_url('/$collection/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 && response.statusCode != 404) {
      throw Exception('Error al eliminar $collection: ${response.statusCode} - ${response.body}');
    }
  }

  // ─── FRANQUICIAS CRUD ────────────────────────────────────────

  Future<void> updateFranquicia(String id, Map<String, dynamic> data) async {
    await _updateDocument('franquicias', id, data);
  }

  Future<void> deleteFranquicia(String id) async {
    await _deleteDocument('franquicias', id);
  }

  // ─── PROFESIONALES CRUD ──────────────────────────────────────

  Future<void> updateProfesional(String uid, Map<String, dynamic> data) async {
    await _updateDocument('profesionales', uid, data);
  }

  Future<void> deleteProfesional(String uid) async {
    await _deleteDocument('profesionales', uid);
  }

  // ─── SEDES ────────────────────────────────────────────────────────

  Future<List<Sede>> getSedes() async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'sedes'}],
        'where': _withFranquicia({
          'fieldFilter': {
            'field': {'fieldPath': 'activa'},
            'op': 'EQUAL',
            'value': {'booleanValue': true},
          },
        }),
      },
    });
    return docs
        .map((r) => Sede.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<void> addSede(Sede sede) async {
    await _setDocument('sedes', sede.id, sede.toMap());
  }

  Future<void> updateSede(Sede sede) async {
    await _updateDocument('sedes', sede.id, sede.toMap());
  }

  Future<void> deleteSede(String id) async {
    await _updateDocument('sedes', id, {'activa': false});
  }

  // ─── HORARIOS ─────────────────────────────────────────────────────

  Future<List<Horario>> getHorariosPorProfesionalYVariosDias({
    required String profesionalId,
    required List<int> diasSemana,
  }) async {
    if (diasSemana.isEmpty) return [];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'horarios'}],
        'where': _withFranquicia({
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'profesionalId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': profesionalId},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'diaSemana'},
                  'op': 'IN',
                  'value': {
                    'arrayValue': {
                      'values': diasSemana
                          .map((d) => {'integerValue': d.toString()})
                          .toList(),
                    },
                  },
                },
              },
            ],
          },
        }),
      },
    });
    return docs
        .map((r) => Horario.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Horario>> getHorariosPorSede(String sedeId) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'horarios'}],
        'where': _withFranquicia({
          'fieldFilter': {
            'field': {'fieldPath': 'sedeId'},
            'op': 'EQUAL',
            'value': {'stringValue': sedeId},
          },
        }),
      },
    });
    return docs
        .map((r) => Horario.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Horario>> getHorariosPorProfesional(String profesionalId) async {
    // Global: return all horarios regardless of professional
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'horarios'}],
        'where': _withFranquicia(null),
      },
    });
    return docs
        .map((r) => Horario.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<void> addHorario(Horario horario) async {
    await _setDocument('horarios', horario.id, horario.toMap());
  }

  Future<void> deleteHorario(String id) async {
    final response = await _client
        .delete(_url('/horarios/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar horario: ${response.statusCode}');
    }
  }

  Future<void> setHorarios({
    required String profesionalId,
    required String sedeId,
    required List<Horario> horarios,
  }) async {
    // Global: query horarios by sede only (not by professional)
    final existing = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'horarios'}],
        'where': _withFranquicia({
          'fieldFilter': {
            'field': {'fieldPath': 'sedeId'},
            'op': 'EQUAL',
            'value': {'stringValue': sedeId},
          },
        }),
      },
    });

    final writes = <Map<String, dynamic>>[];

    for (final doc in existing) {
      writes.add({
        'delete': doc['document']['name'] as String,
      });
    }

    for (final horario in horarios) {
      final id = _uuid.v4();
      final h = horario.copyWith(
        id: id,
        profesionalId: profesionalId,
        sedeId: sedeId,
      );
      writes.add({
        'update': {
          'name': _docName('horarios', id),
          'fields': _toFields(_withFranquiciaEnDatos(h.toMap())),
        },
      });
    }

    if (writes.isNotEmpty) {
      await _commit(writes);
    }
  }

  // ─── PACIENTES ────────────────────────────────────────────────────

  Future<void> deletePaciente(String id) async {
    final response = await _client
        .delete(_url('/pacientes/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar paciente: ${response.statusCode}');
    }
  }

  Future<Paciente?> getPacientePorId(String id) async {
    final doc = await _getDocument('pacientes', id);
    if (doc == null) return null;
    return Paciente.fromMap(doc);
  }

  Future<Paciente?> getPacientePorDocumento(String documento) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'pacientes'}],
        'where': _withFranquicia({
          'fieldFilter': {
            'field': {'fieldPath': 'documento'},
            'op': 'EQUAL',
            'value': {'stringValue': documento},
          },
        }),
        'limit': 1,
      },
    });
    if (docs.isEmpty) return null;
    return Paciente.fromMap(_fieldsToMap(docs.first['document']['fields']));
  }

  Future<void> updatePaciente(Paciente paciente) async {
    await _updateDocument('pacientes', paciente.id, paciente.toMap());
  }

  Future<Paciente> addPaciente(Paciente paciente) async {
    final id = _uuid.v4();
    final p = Paciente(
      id: id,
      documento: paciente.documento,
      nombres: paciente.nombres,
      telefono: paciente.telefono,
      email: paciente.email,
      yaEraPaciente: paciente.yaEraPaciente,
    );
    await _setDocument('pacientes', id, p.toMap());
    return p;
  }

  Future<List<Paciente>> getAllPacientes() async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'pacientes'}],
        'where': _withFranquicia(null),
        'orderBy': [
          {
            'field': {'fieldPath': 'creadoEn'},
            'direction': 'DESCENDING',
          },
        ],
      },
    });
    return docs
        .map((r) => Paciente.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Paciente>> buscarPacientes(String query) async {
    if (query.isEmpty) return [];
    final all = await getAllPacientes();
    final q = query.toLowerCase();
    return all
        .where((p) =>
            p.nombres.toLowerCase().contains(q) || p.documento.contains(q))
        .toList();
  }

  // ─── CITAS ────────────────────────────────────────────────────────

  Future<List<Cita>> getCitasPorFecha(DateTime fecha) async {
    final fechaStr = fecha.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': _withFranquicia({
          'fieldFilter': {
            'field': {'fieldPath': 'fecha'},
            'op': 'EQUAL',
            'value': {'stringValue': fechaStr},
          },
        }),
        'orderBy': [
          {
            'field': {'fieldPath': 'hora'},
            'direction': 'ASCENDING',
          },
        ],
      },
    });
    return docs
        .map((r) => Cita.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Cita>> getCitasPorFechaYSede(DateTime fecha, String sedeId) async {
    final fechaStr = fecha.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': _withFranquicia({
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'EQUAL',
                  'value': {'stringValue': fechaStr},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'sedeId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': sedeId},
                },
              },
            ],
          },
        }),
        'orderBy': [
          {
            'field': {'fieldPath': 'hora'},
            'direction': 'ASCENDING',
          },
        ],
      },
    });
    return docs
        .map((r) => Cita.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Cita>> getCitasPorFechaYProfesional(
      DateTime fecha, String profesionalId) async {
    final fechaStr = fecha.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': _withFranquicia({
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'EQUAL',
                  'value': {'stringValue': fechaStr},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'profesionalId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': profesionalId},
                },
              },
            ],
          },
        }),
        'orderBy': [
          {
            'field': {'fieldPath': 'hora'},
            'direction': 'ASCENDING',
          },
        ],
      },
    });
    return docs
        .map((r) => Cita.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Cita>> getCitasPorPaciente(String pacienteId) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': _withFranquicia({
          'fieldFilter': {
            'field': {'fieldPath': 'pacienteId'},
            'op': 'EQUAL',
            'value': {'stringValue': pacienteId},
          },
        }),
        'orderBy': [
          {
            'field': {'fieldPath': 'fecha'},
            'direction': 'DESCENDING',
          },
          {
            'field': {'fieldPath': 'hora'},
            'direction': 'DESCENDING',
          },
        ],
        'limit': 1,
      },
    });
    return docs
        .map((r) => Cita.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<Cita> addCita(Cita cita) async {
    final id = _uuid.v4();
    final c = cita.copyWith(id: id);
    await _setDocument('citas', id, c.toMap());
    return c;
  }

  Future<void> updateCitaEstado(String id, String estado) async {
    await _updateDocument('citas', id, {'estado': estado});
  }

  Future<void> updateCitaNotificada(String id) async {
    await _updateDocument('citas', id, {'notificada': true});
  }

  Future<void> updateCitaFechaHora(String id, String fecha, String hora) async {
    await _updateDocument('citas', id, {'fecha': fecha, 'hora': hora});
  }

  Future<void> deleteCita(String id) async {
    final response = await _client
        .delete(_url('/citas/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar cita: ${response.statusCode}');
    }
  }

  Future<void> deleteCitasEnRango(
      String profesionalId, DateTime desde, DateTime hasta) async {
    final d = desde.toIso8601String().split('T')[0];
    final h = hasta.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': _withFranquicia({
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'profesionalId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': profesionalId},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'GREATER_THAN_OR_EQUAL',
                  'value': {'stringValue': d},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'LESS_THAN_OR_EQUAL',
                  'value': {'stringValue': h},
                },
              },
            ],
          },
        }),
      },
    });

    if (docs.isEmpty) return;
    final writes = docs
        .map((doc) => {'delete': doc['document']['name'] as String})
        .toList();
    await _commit(writes);
  }

  // ─── EXCEPCIONES ──────────────────────────────────────────────────

  Future<List<Excepcion>> getExcepciones(String profesionalId) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'excepciones'}],
        'where': _withFranquicia({
          'fieldFilter': {
            'field': {'fieldPath': 'profesionalId'},
            'op': 'EQUAL',
            'value': {'stringValue': profesionalId},
          },
        }),
      },
    });
    return docs.map((r) {
      final e = Excepcion.fromMap(_fieldsToMap(r['document']['fields']));
      if (e.id.isEmpty) {
        final name = r['document']['name'] as String;
        final docId = name.split('/').last;
        return e.copyWith(id: docId);
      }
      return e;
    }).toList();
  }

  Future<List<Excepcion>> getExcepcionesEnRango({
    required String profesionalId,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final d = desde.toIso8601String().split('T')[0];
    final h = hasta.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'excepciones'}],
        'where': _withFranquicia({
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'profesionalId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': profesionalId},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'GREATER_THAN_OR_EQUAL',
                  'value': {'stringValue': d},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'LESS_THAN_OR_EQUAL',
                  'value': {'stringValue': h},
                },
              },
            ],
          },
        }),
      },
    });
    return docs.map((r) {
      final e = Excepcion.fromMap(_fieldsToMap(r['document']['fields']));
      if (e.id.isEmpty) {
        final name = r['document']['name'] as String;
        final docId = name.split('/').last;
        return e.copyWith(id: docId);
      }
      return e;
    }).toList();
  }

  Future<void> addExcepcion(Excepcion excepcion) async {
    final id = excepcion.id.isEmpty ? _uuid.v4() : excepcion.id;
    final e = excepcion.copyWith(id: id);
    await _setDocument('excepciones', id, e.toMap());
  }

  Future<void> deleteExcepcion(String id) async {
    final response = await _client
        .delete(_url('/excepciones/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar excepción: ${response.statusCode}');
    }
  }

  // ─── PROFESIONALES ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProfesionales() async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'profesionales'}],
        'where': _withFranquicia({
          'fieldFilter': {
            'field': {'fieldPath': 'activo'},
            'op': 'EQUAL',
            'value': {'booleanValue': true},
          },
        }),
      },
    });
    return docs
        .map((r) => _fieldsToMap(r['document']['fields']))
        .toList();
  }

  Future<Map<String, dynamic>?> getProfesional(String uid) async {
    return await _getDocument('profesionales', uid);
  }

  Future<void> setProfesional(String uid, Map<String, dynamic> data) async {
    await _setDocument('profesionales', uid, data);
  }

  // ─── FRANQUICIAS Y DESARROLLADORES ───────────────────────────────

  Future<Map<String, dynamic>?> getFranquicia(String id) async {
    return await _getDocument('franquicias', id);
  }

  Future<List<Map<String, dynamic>>> getTodasFranquicias() async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'franquicias'}],
      },
    });
    return docs
        .map((r) {
          final fields = _fieldsToMap(r['document']['fields']);
          // Ensure 'codigo' always has a value (use doc ID if field is missing)
          final docId = r['document']['name'].split('/').last;
          fields.putIfAbsent('codigo', () => docId);
          return fields;
        })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getTodosProfesionales() async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'profesionales'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'activo'},
            'op': 'EQUAL',
            'value': {'booleanValue': true},
          },
        },
      },
    });
    return docs
        .map((r) => _fieldsToMap(r['document']['fields']))
        .toList();
  }

  Future<bool> esDesarrollador(String uid) async {
    final doc = await _getDocument('desarrolladores', uid);
    return doc != null && (doc['activo'] as bool? ?? true);
  }

  // ─── NOTIFICACIONES ───────────────────────────────────────────────

  Future<List<Notificacion>> getNotificaciones(String profesionalId) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'notificaciones'}],
        'where': _withFranquicia({
          'fieldFilter': {
            'field': {'fieldPath': 'profesionalId'},
            'op': 'EQUAL',
            'value': {'stringValue': profesionalId},
          },
        }),
        'orderBy': [
          {
            'field': {'fieldPath': 'fechaCreacion'},
            'direction': 'DESCENDING',
          },
        ],
      },
    });
    return docs
        .map((r) =>
            Notificacion.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<int> getNotificacionesNoLeidas(String profesionalId) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'notificaciones'}],
        'where': _withFranquicia({
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'profesionalId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': profesionalId},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'leida'},
                  'op': 'EQUAL',
                  'value': {'booleanValue': false},
                },
              },
            ],
          },
        }),
      },
    });
    return docs.length;
  }

  Future<void> addNotificacion(Notificacion notificacion) async {
    final id = notificacion.id.isEmpty ? _uuid.v4() : notificacion.id;
    await _setDocument('notificaciones', id, notificacion.copyWith(id: id).toMap());
  }

  Future<void> marcarNotificacionesLeidas(String profesionalId) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'notificaciones'}],
        'where': _withFranquicia({
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'profesionalId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': profesionalId},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'leida'},
                  'op': 'EQUAL',
                  'value': {'booleanValue': false},
                },
              },
            ],
          },
        }),
      },
    });

    if (docs.isEmpty) return;
    final writes = docs.map((doc) {
      final name = doc['document']['name'] as String;
      return {
        'update': {
          'name': name,
          'fields': _toFields({'leida': true}),
        },
      };
    }).toList();
    await _commit(writes);
  }

  // ─── POLLING (replaces stream) ────────────────────────────────────

  Future<List<Cita>> pollCitasEnRango({
    required String profesionalId,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final d = desde.toIso8601String().split('T')[0];
    final h = hasta.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': _withFranquicia({
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'GREATER_THAN_OR_EQUAL',
                  'value': {'stringValue': d},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'LESS_THAN_OR_EQUAL',
                  'value': {'stringValue': h},
                },
              },
            ],
          },
        }),
      },
    });
    return docs
        .map((r) => Cita.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  // ─── TIPOS CONSULTA ──────────────────────────────────────────────

  Future<List<TipoConsulta>> getTiposConsulta() async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'tipos_consulta'}],
        'where': _withFranquicia({
          'fieldFilter': {
            'field': {'fieldPath': 'activo'},
            'op': 'EQUAL',
            'value': {'booleanValue': true},
          },
        }),
      },
    });
    return docs
        .map((r) =>
            TipoConsulta.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<void> addTipoConsulta(TipoConsulta tipo) async {
    await _setDocument('tipos_consulta', tipo.id, tipo.toMap());
  }

  Future<void> deleteTipoConsulta(String id) async {
    await _updateDocument('tipos_consulta', id, {'activo': false});
  }

  // ─── BORRADO MASIVO ─────────────────────────────────────────────

  Future<void> _deleteAllInCollection(String collection) async {
    final query = <String, dynamic>{
      'from': [{'collectionId': collection}],
    };
    final f = franquiciaActual;
    if (f != null && f.isNotEmpty) {
      query['where'] = {
        'fieldFilter': {
          'field': {'fieldPath': 'franquiciaId'},
          'op': 'EQUAL',
          'value': {'stringValue': f},
        },
      };
    }
    final docs = await _runQuery({'structuredQuery': query});
    if (docs.isEmpty) return;
    final writes = docs
        .map((doc) => {'delete': doc['document']['name'] as String})
        .toList();
    for (var i = 0; i < writes.length; i += 500) {
      final batch = writes.sublist(i, (i + 500).clamp(0, writes.length));
      await _commit(batch);
    }
  }

  Future<void> deleteAllCitas() async {
    await _deleteAllInCollection('citas');
  }

  Future<void> deleteAllCollections() async {
    const collections = [
      'citas', 'sedes', 'horarios', 'tipos_consulta',
      'excepciones', 'pacientes', 'notificaciones', 'profesionales',
    ];
    for (final coll in collections) {
      await _deleteAllInCollection(coll);
    }
  }

  Future<void> deleteSelectedCollections(List<String> collections) async {
    for (final coll in collections) {
      await _deleteAllInCollection(coll);
    }
  }

  // ─── ESTADÍSTICAS ────────────────────────────────────────────────

  Future<List<Cita>> getCitasEnRango(DateTime desde, DateTime hasta) async {
    final d = desde.toIso8601String().split('T')[0];
    final h = hasta.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': _withFranquicia({
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'GREATER_THAN_OR_EQUAL',
                  'value': {'stringValue': d},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'LESS_THAN_OR_EQUAL',
                  'value': {'stringValue': h},
                },
              },
            ],
          },
        }),
        'orderBy': [
          {
            'field': {'fieldPath': 'fecha'},
            'direction': 'ASCENDING',
          },
        ],
      },
    });
    return docs
        .map((r) => Cita.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  // ─── AUDIT LOG ─────────────────────────────────────────────────

  Future<void> registrarAuditLog({
    required String accion,
    required String coleccion,
    String? documentoId,
    required String usuarioId,
    required String usuarioNombre,
    String? franquiciaId,
    String? detalles,
  }) async {
    final id = _uuid.v4();
    await _setDocument('audit_log', id, {
      'accion': accion,
      'coleccion': coleccion,
      'documentoId': documentoId,
      'usuarioId': usuarioId,
      'usuarioNombre': usuarioNombre,
      'franquiciaId': franquiciaId ?? franquiciaActual,
      'timestamp': DateTime.now().toIso8601String(),
      'detalles': detalles,
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({String? franquiciaId, int limit = 100}) async {
    final where = <String, dynamic>{};
    if (franquiciaId != null && franquiciaId.isNotEmpty) {
      where['fieldFilter'] = {
        'field': {'fieldPath': 'franquiciaId'},
        'op': 'EQUAL',
        'value': {'stringValue': franquiciaId},
      };
    }
    final query = <String, dynamic>{
      'from': [{'collectionId': 'audit_log'}],
      'orderBy': [
        {
          'field': {'fieldPath': 'timestamp'},
          'direction': 'DESCENDING',
        },
      ],
      'limit': limit,
    };
    if (where.isNotEmpty) {
      query['where'] = where;
    }
    final docs = await _runQuery({'structuredQuery': query});
    return docs
        .map((r) {
          final fields = _fieldsToMap(r['document']['fields']);
          fields['id'] = r['document']['name'].split('/').last;
          return fields;
        })
        .toList();
  }
}