String formato12h(String hora24) {
  final partes = hora24.split(':');
  final h = int.parse(partes[0]);
  final m = partes[1];
  final periodo = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:$m $periodo';
}

String formatoFecha(DateTime fecha) {
  final d = fecha.day.toString().padLeft(2, '0');
  final m = fecha.month.toString().padLeft(2, '0');
  final y = fecha.year.toString();
  return '$d/$m/$y';
}
