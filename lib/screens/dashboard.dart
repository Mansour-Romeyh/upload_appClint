import 'package:flutter/material.dart';
import '../widgets/staggered_column.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String _fullName = '';
  String _employeeId = '';
  int _leaveBalance = 0;
  double _monthlyHours = 0;
  int _pendingRequests = 0;
  int _attendanceRate = 0;
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _fullName = await AuthService.getFullName();
      _employeeId = await AuthService.getEmployeeId();

      final data = await ApiService.getJson('/api/mobile/dashboard');
      if (!mounted) return;
      setState(() {
        _leaveBalance = (data['leave_balance'] as num?)?.toInt() ?? 0;
        _monthlyHours = (data['monthly_hours'] as num?)?.toDouble() ?? 0;
        _pendingRequests = (data['pending_requests'] as num?)?.toInt() ?? 0;
        _attendanceRate = (data['attendance_rate'] as num?)?.toInt() ?? 0;
        _activities = List<Map<String, dynamic>>.from(data['recent_activities'] ?? []);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = [
      {'icon': Icons.calendar_today, 'label': 'رصيد الإجازات', 'value': '$_leaveBalance يوم', 'color': const Color(0xFF284A63)},
      {'icon': Icons.access_time, 'label': 'ساعات هذا الشهر', 'value': '${_monthlyHours.toStringAsFixed(0)} ساعة', 'color': const Color(0xFF16A34A)},
      {'icon': Icons.assignment_turned_in, 'label': 'الطلبات المعلقة', 'value': '$_pendingRequests', 'color': const Color(0xFFEA580C)},
      {'icon': Icons.trending_up, 'label': 'معدل الحضور', 'value': '%$_attendanceRate', 'color': const Color(0xFF9333EA)},
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF284A63), Color(0xFF3B6E71)],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/logo.png', height: 32, color: Colors.white),
                const SizedBox(height: 16),
                const Text('مرحباً بعودتك،', style: TextStyle(fontSize: 22, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  _fullName.isNotEmpty ? _fullName : '...',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'رقم الموظف: ${_employeeId.isNotEmpty ? _employeeId : '...'}',
                  style: const TextStyle(fontSize: 14, color: Color(0xFFBFDBFE)),
                ),
              ],
            ),
          ),

          // Stats Grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                : StaggeredColumn(
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        children: stats.map((stat) {
                          return Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.topStart,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(stat['icon'] as IconData, size: 32, color: stat['color'] as Color),
                                    const SizedBox(height: 8),
                                    Text(stat['value'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(stat['label'] as String, style: const TextStyle(fontSize: 13, color: Color(0xFF353535))),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Recent Activities
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('النشاطات الأخيرة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              if (_activities.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('لا توجد نشاطات حديثة', style: TextStyle(color: Color(0xFF9CA3AF))),
                                )
                              else
                                ..._activities.asMap().entries.map((entry) {
                                  final activity = entry.value;
                                  final isLast = entry.key == _activities.length - 1;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            activity['action'] ?? '',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        Icon(
                                          activity['type'] == 'checkin' ? Icons.login : Icons.description,
                                          size: 18,
                                          color: const Color(0xFF9CA3AF),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
