class ColombianHolidays {
  static DateTime _easter(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  static DateTime _nextMonday(DateTime d) {
    var daysUntilMonday = (DateTime.monday - d.weekday + 7) % 7;
    if (daysUntilMonday == 0) daysUntilMonday = 7;
    return d.add(Duration(days: daysUntilMonday));
  }

  static List<DateTime> getHolidays(int year) {
    final easter = _easter(year);
    final holidays = <DateTime>[];

    void addIfNotMonday(DateTime date, String name) {
      if (date.weekday == DateTime.monday) {
        holidays.add(date);
      } else {
        holidays.add(_nextMonday(date));
      }
    }

    holidays.add(DateTime(year, 1, 1));
    addIfNotMonday(DateTime(year, 1, 6), 'Reyes Magos');
    addIfNotMonday(DateTime(year, 3, 19), 'San José');
    holidays.add(easter.subtract(const Duration(days: 3)));
    holidays.add(easter.subtract(const Duration(days: 2)));
    holidays.add(DateTime(year, 5, 1));
    holidays.add(_nextMonday(easter.add(const Duration(days: 43))));
    holidays.add(_nextMonday(easter.add(const Duration(days: 64))));
    holidays.add(_nextMonday(easter.add(const Duration(days: 71))));
    addIfNotMonday(DateTime(year, 6, 29), 'San Pedro y San Pablo');
    holidays.add(DateTime(year, 7, 20));
    holidays.add(DateTime(year, 8, 7));
    addIfNotMonday(DateTime(year, 8, 15), 'Asunción');
    addIfNotMonday(DateTime(year, 10, 12), 'Día de la Raza');
    addIfNotMonday(DateTime(year, 11, 1), 'Todos los Santos');
    addIfNotMonday(DateTime(year, 11, 11), 'Independencia de Cartagena');
    holidays.add(DateTime(year, 12, 8));
    holidays.add(DateTime(year, 12, 25));

    return holidays;
  }

  static bool esFestivo(DateTime fecha) {
    return getHolidays(fecha.year).any((h) =>
        h.year == fecha.year && h.month == fecha.month && h.day == fecha.day);
  }

  static String? nombreFestivo(DateTime fecha) {
    final festivos = <DateTime, String>{
      DateTime(fecha.year, 1, 1): 'Año Nuevo',
      DateTime(fecha.year, 5, 1): 'Día del Trabajo',
      DateTime(fecha.year, 7, 20): 'Día de la Independencia',
      DateTime(fecha.year, 8, 7): 'Batalla de Boyacá',
      DateTime(fecha.year, 12, 8): 'Inmaculada Concepción',
      DateTime(fecha.year, 12, 25): 'Navidad',
    };

    for (final h in getHolidays(fecha.year)) {
      if (h.year == fecha.year && h.month == fecha.month && h.day == fecha.day) {
        final fixed = festivos.entries.firstWhere(
          (e) => e.key.month == h.month && e.key.day == h.day,
          orElse: () => MapEntry(h, 'Festivo'),
        );
        return _nombreFestivoMovil(h) ?? fixed.value;
      }
    }
    return null;
  }

  static String? _nombreFestivoMovil(DateTime h) {
    final easter = _easter(h.year);
    if (h == easter.subtract(const Duration(days: 3))) return 'Jueves Santo';
    if (h == easter.subtract(const Duration(days: 2))) return 'Viernes Santo';
    if (h == _nextMonday(easter.add(const Duration(days: 43)))) return 'Ascensión de Jesús';
    if (h == _nextMonday(easter.add(const Duration(days: 64)))) return 'Corpus Christi';
    if (h == _nextMonday(easter.add(const Duration(days: 71)))) return 'Sagrado Corazón';
    return null;
  }

  static List<DateTime> getHolidaysInRange(DateTime desde, DateTime hasta) {
    final result = <DateTime>[];
    for (var y = desde.year; y <= hasta.year; y++) {
      for (final h in getHolidays(y)) {
        if (!h.isBefore(desde) && !h.isAfter(hasta)) {
          result.add(h);
        }
      }
    }
    return result;
  }
}
