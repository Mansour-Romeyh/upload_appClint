import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../widgets/calendar_view.dart';
import '../widgets/animated_bottom_sheet.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  bool _checkedIn = false;
  String? _checkInTime;
  late TabController _tabController;
  bool _loading = true;
  bool _submitting = false;
  List<AttendanceRecord> _attendanceData = [];
  List<CheckInRequest> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        ApiService.getJson('/api/mobile/attendance',
            query: {'month': now.month, 'year': now.year}),
        ApiService.getJson('/api/mobile/attendance/today'),
        ApiService.getJson('/api/mobile/attendance/checkin-requests')
            .catchError((_) => <String, dynamic>{'requests': []}),
      ]);

      final attendanceList = List<Map<String, dynamic>>.from(results[0] ?? []);
      final todayCheckins = List<Map<String, dynamic>>.from(results[1] ?? []);
      final requestsData = results[2] is Map
          ? Map<String, dynamic>.from(results[2] as Map)
          : <String, dynamic>{};
      final requestsList = List<Map<String, dynamic>>.from(
          requestsData['requests'] ?? const []);

      // Determine check-in state from today's checkins
      bool isCheckedIn = false;
      String? lastCheckInTime;
      for (final c in todayCheckins) {
        if (c['log_type'] == 'IN') {
          isCheckedIn = true;
          lastCheckInTime = _formatTime(c['time'] ?? '');
        } else if (c['log_type'] == 'OUT') {
          isCheckedIn = false;
        }
      }

      if (!mounted) return;
      setState(() {
        _attendanceData = attendanceList.map((r) {
          final status = _mapStatus(r['status'] ?? '');
          return AttendanceRecord(
            date: r['date'] ?? '',
            hours: (r['working_hours'] as num?)?.toDouble() ?? 0,
            status: status,
          );
        }).toList();
        _pendingRequests =
            requestsList.map(CheckInRequest.fromJson).toList();
        _checkedIn = isCheckedIn;
        _checkInTime = lastCheckInTime;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapStatus(String status) {
    switch (status) {
      case 'Present': return 'present';
      case 'Absent': return 'absent';
      case 'Half Day': return 'half-day';
      case 'On Leave': return 'leave';
      default: return 'absent';
    }
  }

  String _formatTime(String datetime) {
    try {
      final dt = DateTime.parse(datetime);
      return DateFormat('hh:mm a', 'ar').format(dt);
    } catch (_) {
      return datetime;
    }
  }

  Future<void> _handleCheckIn({String? requestId}) => _submitAttendance(
        endpoint: '/api/mobile/attendance/checkin',
        successPrefix: 'تم تسجيل الحضور في',
        requestId: requestId,
        onSuccess: (time) {
          _checkedIn = true;
          _checkInTime = time;
          if (requestId != null) {
            _pendingRequests = _pendingRequests
                .where((r) => r.id != requestId)
                .toList();
          }
        },
      );

  Future<void> _handleCheckOut() => _submitAttendance(
        endpoint: '/api/mobile/attendance/checkout',
        successPrefix: 'تم تسجيل الانصراف في',
        onSuccess: (_) => _checkedIn = false,
      );

  Future<void> _submitAttendance({
    required String endpoint,
    required String successPrefix,
    required void Function(String time) onSuccess,
    String? requestId,
  }) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    Fluttertoast.showToast(msg: 'جاري تحديد الموقع...');
    try {
      final position = await LocationService.getCurrentPosition();
      final result = await ApiService.postJson(endpoint, body: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'requestId': ?requestId,
      });
      final time = _formatTime(result['time'] ?? '');
      if (!mounted) return;
      setState(() => onSuccess(time));
      Fluttertoast.showToast(msg: '$successPrefix $time');
    } on LocationException catch (e) {
      Fluttertoast.showToast(msg: e.message);
    } catch (e) {
      final msg = e.toString().contains('DoesNotExist')
          ? 'لا يوجد سجل موظف مرتبط بحسابك'
          : 'خطأ: $e';
      Fluttertoast.showToast(msg: msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showAttendanceRequestDialog() {
    String? selectedType;
    final dateController = TextEditingController();
    final reasonController = TextEditingController();

    showAnimatedBottomSheet(
      context: context,
      title: 'طلب تسوية الحضور',
      subtitle: 'قدم طلب لتسوية سجل الحضور الخاص بك',
      children: [
        StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نوع الطلب', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(hintText: 'اختر النوع'),
                  items: ['نسيان تسجيل الحضور', 'نسيان تسجيل الانصراف', 'وقت خاطئ', 'خطأ في النظام']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setSheetState(() => selectedType = v),
                ),
                const SizedBox(height: 16),
                const Text('التاريخ', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: dateController,
                  readOnly: true,
                  decoration: const InputDecoration(hintText: 'اختر التاريخ', suffixIcon: Icon(Icons.calendar_today, size: 18)),
                  onTap: () async {
                    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030), locale: const Locale('ar'));
                    if (date != null) dateController.text = DateFormat('yyyy-MM-dd').format(date);
                  },
                ),
                const SizedBox(height: 16),
                const Text('السبب', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(controller: reasonController, maxLines: 3, decoration: const InputDecoration(hintText: 'اشرح سبب طلبك...')),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (dateController.text.isNotEmpty && reasonController.text.isNotEmpty) {
                        try {
                          await ApiService.postJson('/api/mobile/attendance/requests', body: {
                            'reason': '${selectedType ?? ''}: ${reasonController.text}',
                            'attendance_date': dateController.text,
                          });
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          Fluttertoast.showToast(msg: 'تم تقديم طلب تسوية الحضور بنجاح!');
                        } catch (e) {
                          Fluttertoast.showToast(msg: 'خطأ: $e');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF284A63),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('تقديم الطلب', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'present': return 'حاضر';
      case 'half-day': return 'نصف يوم';
      case 'leave': return 'إجازة';
      default: return 'غائب';
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'present': return const Color(0xFFDCFCE7);
      case 'half-day': return const Color(0xFFFEF9C3);
      case 'leave': return const Color(0xFFD9DAD9);
      default: return const Color(0xFFFEE2E2);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'present': return const Color(0xFF15803D);
      case 'half-day': return const Color(0xFFA16207);
      case 'leave': return const Color(0xFF284A63);
      default: return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentTime = DateFormat('hh:mm', 'ar').format(now);
    final currentDate = DateFormat('EEEE، d MMMM yyyy', 'ar').format(now);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [Color(0xFF3B6E71), Color(0xFF284A63)],
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/logo.png', height: 28, color: Colors.white),
                const SizedBox(height: 16),
                const Text('الحضور والانصراف', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(currentTime, style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(currentDate, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 96,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
                                child: _checkedIn
                                    ? ElevatedButton(
                                        key: const ValueKey('checkout'),
                                        onPressed: _submitting ? null : _handleCheckOut,
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(double.infinity, 96)),
                                        child: _submitting
                                            ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                            : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout, size: 32), SizedBox(height: 8), Text('تسجيل الانصراف')]),
                                      )
                                    : ElevatedButton(
                                        key: const ValueKey('checkin'),
                                        onPressed: _submitting ? null : _handleCheckIn,
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(double.infinity, 96)),
                                        child: _submitting
                                            ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                            : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.login, size: 32), SizedBox(height: 8), Text('تسجيل الحضور')]),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 96,
                              child: OutlinedButton(
                                onPressed: _showAttendanceRequestDialog,
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.3)), backgroundColor: Colors.white.withValues(alpha: 0.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add, size: 32), SizedBox(height: 8), Text('طلب تسوية')]),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('وقت الحضور: ${_checkedIn ? _checkInTime ?? '' : 'لم يتم التسجيل'}', style: const TextStyle(fontSize: 14, color: Colors.white)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Pending check-in requests (admin-initiated)
          if (!_loading && !_checkedIn && _pendingRequests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: _pendingRequests
                    .map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildRequestBanner(r),
                        ))
                    .toList(),
              ),
            ),

          // Tabs
          Padding(
            padding: const EdgeInsets.all(16),
            child: _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                : Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: Colors.black,
                          unselectedLabelColor: const Color(0xFF353535),
                          dividerHeight: 0,
                          tabs: const [Tab(text: 'عرض التقويم'), Tab(text: 'السجل')],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 600,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            CalendarView(attendanceData: _attendanceData),
                            _buildHistoryTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestBanner(CheckInRequest req) {
    final requesterLine = req.requestedBy != null && req.requestedBy!.isNotEmpty
        ? 'طلب من: ${req.requestedBy}'
        : 'طلب تسجيل حضور من الإدارة';
    final timeLabel = _formatRequestedAt(req.requestedAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        border: Border.all(color: const Color(0xFFFB923C)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFB923C).withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFFFB923C), shape: BoxShape.circle),
                child: const Icon(Icons.notifications_active, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تنبيه: مطلوب تسجيل الحضور',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF9A3412)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      requesterLine,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF7C2D12)),
                    ),
                    if (timeLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(timeLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412))),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (req.note != null && req.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(req.note!, style: const TextStyle(fontSize: 13, color: Color(0xFF7C2D12))),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : () => _handleCheckIn(requestId: req.id),
              icon: const Icon(Icons.check_circle, size: 20),
              label: const Text('تأكيد تسجيل الحضور الآن', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _formatRequestedAt(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      return 'الوقت: ${DateFormat('hh:mm a · d MMM', 'ar').format(dt)}';
    } catch (_) {
      return null;
    }
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _attendanceData.length,
      itemBuilder: (context, index) {
        final record = _attendanceData[index];
        String formattedDate;
        try {
          final date = DateTime.parse(record.date);
          formattedDate = DateFormat('EEEE، d MMM', 'ar').format(date);
        } catch (_) {
          formattedDate = record.date;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      if (record.status == 'present' || record.status == 'half-day')
                        Text('${record.hours.toStringAsFixed(1)} ساعة عمل', style: const TextStyle(fontSize: 14, color: Color(0xFF353535)))
                      else
                        const Text('لا يوجد حضور', style: TextStyle(fontSize: 14, color: Color(0xFF353535))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: _getStatusBgColor(record.status), borderRadius: BorderRadius.circular(20)),
                  child: Text(_getStatusText(record.status), style: TextStyle(fontSize: 12, color: _getStatusTextColor(record.status))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CheckInRequest {
  final String id;
  final String? note;
  final String? requestedBy;
  final String? requestedAt;

  const CheckInRequest({
    required this.id,
    this.note,
    this.requestedBy,
    this.requestedAt,
  });

  factory CheckInRequest.fromJson(Map<String, dynamic> json) => CheckInRequest(
        id: json['id'] as String,
        note: json['note'] as String?,
        requestedBy: json['requestedBy'] as String?,
        requestedAt: json['requestedAt'] as String?,
      );
}
