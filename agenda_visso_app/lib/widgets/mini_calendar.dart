import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../utils/colombian_holidays.dart';

class MiniCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final Set<String> excepcionFechas;
  final Set<String> citaFechas;
  final ValueChanged<DateTime> onDateSelected;

  const MiniCalendar({
    super.key,
    required this.selectedDate,
    required this.excepcionFechas,
    required this.citaFechas,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final now = DateTime.now();
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday - DateTime.monday));
    final weeks = List.generate(6, (i) => startOfWeek.add(Duration(days: i * 7)));
    final monthName = _monthName(selectedDate.month);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.chevronLeft, size: 18),
              onPressed: () {
                final prev = DateTime(selectedDate.year, selectedDate.month - 1, 1);
                onDateSelected(prev);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Expanded(
              child: Text(
                '$monthName ${selectedDate.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.chevronRight, size: 18),
              onPressed: () {
                final next = DateTime(selectedDate.year, selectedDate.month + 1, 1);
                onDateSelected(next);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: ['L', 'M', 'Mi', 'J', 'V', 'S', 'D'].map((d) => Expanded(
            child: Center(
              child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 4),
        ...weeks.map((weekStart) => Row(
          children: List.generate(7, (dayIdx) {
            final day = weekStart.add(Duration(days: dayIdx));
            final isCurrentMonth = day.month == selectedDate.month;
            final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
            final isSelected = day.year == selectedDate.year && day.month == selectedDate.month && day.day == selectedDate.day;
            final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
            final isException = excepcionFechas.contains(dateStr);
            final isHoliday = ColombianHolidays.esFestivo(day);
            final hasCitas = citaFechas.contains(dateStr);
            final isBlocked = isException || isHoliday;

            return Expanded(
              child: GestureDetector(
                onTap: () => onDateSelected(day),
                child: Container(
                  height: 32,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary
                        : isToday
                            ? primary.withAlpha(25)
                            : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected
                              ? Colors.white
                              : !isCurrentMonth
                                  ? Colors.grey.shade300
                                  : isBlocked
                                      ? Colors.red.shade300
                                      : Colors.black87,
                        ),
                      ),
                      if (hasCitas && !isSelected)
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isBlocked ? Colors.red : primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        )),
      ],
    );
  }

  String _monthName(int m) {
    const names = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return names[m];
  }
}
