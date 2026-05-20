import '../models/sede.dart';
import '../models/horario.dart';
import '../models/paciente.dart';
import '../models/cita.dart';
import '../models/excepcion.dart';
import '../models/notificacion.dart';
import '../models/tipo_consulta.dart';
import 'firestore_rest_service.dart';

class FirestoreService {
  final FirestoreRestService _rest = FirestoreRestService();

  Future<List<Sede>> getSedes() => _rest.getSedes();
  Future<void> addSede(Sede sede) => _rest.addSede(sede);
  Future<void> updateSede(Sede sede) => _rest.updateSede(sede);
  Future<void> deleteSede(String id) => _rest.deleteSede(id);

  Future<List<Horario>> getHorariosPorProfesionalYVariosDias({
    required String profesionalId,
    required List<int> diasSemana,
  }) =>
      _rest.getHorariosPorProfesionalYVariosDias(
        profesionalId: profesionalId,
        diasSemana: diasSemana,
      );

  Future<List<Horario>> getHorariosPorSede(String sedeId) =>
      _rest.getHorariosPorSede(sedeId);

  Future<List<Horario>> getHorariosPorProfesional(String profesionalId) =>
      _rest.getHorariosPorProfesional(profesionalId);

  Future<void> addHorario(Horario horario) => _rest.addHorario(horario);
  Future<void> deleteHorario(String id) => _rest.deleteHorario(id);

  Future<void> setHorarios({
    required String profesionalId,
    required String sedeId,
    required List<Horario> horarios,
  }) =>
      _rest.setHorarios(
        profesionalId: profesionalId,
        sedeId: sedeId,
        horarios: horarios,
      );

  Future<Paciente?> getPacientePorDocumento(String documento) =>
      _rest.getPacientePorDocumento(documento);

  Future<void> updatePaciente(Paciente paciente) =>
      _rest.updatePaciente(paciente);

  Future<Paciente> addPaciente(Paciente paciente) =>
      _rest.addPaciente(paciente);

  Future<void> deletePaciente(String id) => _rest.deletePaciente(id);

  Future<List<Paciente>> getAllPacientes() => _rest.getAllPacientes();

  Future<List<Paciente>> buscarPacientes(String query) =>
      _rest.buscarPacientes(query);

  Future<List<Cita>> getCitasPorFecha(DateTime fecha) =>
      _rest.getCitasPorFecha(fecha);

  Future<List<Cita>> getCitasPorFechaYSede(DateTime fecha, String sedeId) =>
      _rest.getCitasPorFechaYSede(fecha, sedeId);

  Future<List<Cita>> getCitasPorFechaYProfesional(
          DateTime fecha, String profesionalId) =>
      _rest.getCitasPorFechaYProfesional(fecha, profesionalId);

  Future<Cita> addCita(Cita cita) => _rest.addCita(cita);

  Future<void> updateCitaEstado(String id, String estado) =>
      _rest.updateCitaEstado(id, estado);

  Future<void> updateCitaNotificada(String id) =>
      _rest.updateCitaNotificada(id);

  Future<void> deleteCita(String id) => _rest.deleteCita(id);

  Future<void> deleteCitasEnRango(
          String profesionalId, DateTime desde, DateTime hasta) =>
      _rest.deleteCitasEnRango(profesionalId, desde, hasta);

  Future<List<Excepcion>> getExcepciones(String profesionalId) =>
      _rest.getExcepciones(profesionalId);

  Future<List<Excepcion>> getExcepcionesEnRango({
    required String profesionalId,
    required DateTime desde,
    required DateTime hasta,
  }) =>
      _rest.getExcepcionesEnRango(
        profesionalId: profesionalId,
        desde: desde,
        hasta: hasta,
      );

  Future<void> addExcepcion(Excepcion excepcion) =>
      _rest.addExcepcion(excepcion);

  Future<void> deleteExcepcion(String id) => _rest.deleteExcepcion(id);

  Future<List<Map<String, dynamic>>> getProfesionales() =>
      _rest.getProfesionales();

  Future<void> addNotificacion(Notificacion notificacion) =>
      _rest.addNotificacion(notificacion);

  Future<List<Notificacion>> getNotificaciones(String profesionalId) =>
      _rest.getNotificaciones(profesionalId);

  Future<int> getNotificacionesNoLeidas(String profesionalId) =>
      _rest.getNotificacionesNoLeidas(profesionalId);

  Future<void> marcarNotificacionesLeidas(String profesionalId) =>
      _rest.marcarNotificacionesLeidas(profesionalId);

  Future<Map<String, dynamic>?> getProfesional(String uid) =>
      _rest.getProfesional(uid);

  Future<void> setProfesional(String uid, Map<String, dynamic> data) =>
      _rest.setProfesional(uid, data);

  Future<List<Cita>> pollCitasEnRango({
    required String profesionalId,
    required DateTime desde,
    required DateTime hasta,
  }) =>
      _rest.pollCitasEnRango(
        profesionalId: profesionalId,
        desde: desde,
        hasta: hasta,
      );

  Future<List<TipoConsulta>> getTiposConsulta() => _rest.getTiposConsulta();
  Future<void> addTipoConsulta(TipoConsulta tipo) => _rest.addTipoConsulta(tipo);
  Future<void> deleteTipoConsulta(String id) => _rest.deleteTipoConsulta(id);
  Future<List<Cita>> getCitasEnRango(DateTime desde, DateTime hasta) =>
      _rest.getCitasEnRango(desde, hasta);
}
