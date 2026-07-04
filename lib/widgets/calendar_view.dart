import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceRecord {
  final String date;
  final String? checkIn;
  final String? checkOut;
  final double hours;
  final String status;

  AttendanceRecord({
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.hours,
    required this.status,
  });
}

class CalendarView extends StatefulWidget {
  final List<AttendanceRecord> attendanceData;

  const CalendarView({super.key, required this.attendanceData});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present': return const Color(0xFF22C55E);
      case 'half-day': return const Color(0xFFEAB308);
      case 'leave': return const Color(0xFF3B82F6);
      case 'absent': return const Color(0xFFEF4444);
      default: return const Color(0xFFE5E7EB);
    }
  }

  AttendanceRecord? _getAttendanceStatus(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    try {
      return widget.attendanceData.firstWhere((r) => r.date == dateString);
    } catch (_) {
      return null;
    }
  }

  void _previousMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final year = _currentDate.year;
    final month = _currentDate.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startingDayOfWeek = firstDay.weekday % 7;
    final weekDays = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final today = DateTime.now();

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Month Navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_left, size: 24),
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                Text(
                  DateFormat('MMMM yyyy', 'ar').format(_currentDate),
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
                IconButton(
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_right, size: 24),
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weekday Headers
            Row(
              children: weekDays.map((day) {
                return Expanded(
                  child: Center(
                    child: Text(day, style: const TextStyle(fontSize: 10, color: Color(0xFF353535))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),

            // Calendar Grid with fade transition on month change
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: GridView.builder(
                key: ValueKey<String>('$year-$month'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: startingDayOfWeek + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < startingDayOfWeek) {
                    return const SizedBox();
                  }
                  final day = index - startingDayOfWeek + 1;
                  final date = DateTime(year, month, day);
                  final attendance = _getAttendanceStatus(date);
                  final isToday = date.year == today.year && date.month == today.month && date.day == today.day;

                  return Container(
                    decoration: BoxDecoration(
                      color: attendance != null ? _getStatusColor(attendance.status) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                      border: isToday ? Border.all(color: const Color(0xFF284A63), width: 2) : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          color: attendance != null ? Colors.white : const Color(0xFF353535),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Legend
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 6,
              children: [
                _legendItem(const Color(0xFF22C55E), 'حاضر'),
                _legendItem(const Color(0xFFEAB308), 'نصف يوم'),
                _legendItem(const Color(0xFF3B82F6), 'إجازة'),
                _legendItem(const Color(0xFFEF4444), 'غائب'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
