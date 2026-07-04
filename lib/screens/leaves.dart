import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../widgets/animated_bottom_sheet.dart';
import '../widgets/staggered_column.dart';
import '../services/api_service.dart';

class LeavesScreen extends StatefulWidget {
  const LeavesScreen({super.key});

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

const Map<String, String> kLeaveTypeLabels = {
  'Annual': 'إجازة سنوية',
  'Sick': 'إجازة مرضية',
  'Personal': 'إجازة شخصية',
  'Maternity': 'إجازة أمومة',
  'Paternity': 'إجازة أبوة',
  'Unpaid': 'إجازة بدون راتب',
};

String leaveTypeArabic(String? type) {
  if (type == null || type.isEmpty) return '';
  return kLeaveTypeLabels[type] ?? type;
}

class _LeavesScreenState extends State<LeavesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _leaveBalance = [];
  List<String> _leaveTypes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getJson('/api/mobile/leaves'),
        ApiService.getJson('/api/mobile/leaves/balance'),
        ApiService.getJson('/api/mobile/leaves/types'),
      ]);

      if (!mounted) return;
      final leavesData = results[0] as Map<String, dynamic>;
      setState(() {
        _leaves = List<Map<String, dynamic>>.from(leavesData['leaves'] ?? []);
        _leaveBalance = List<Map<String, dynamic>>.from(results[1] ?? []);
        _leaveTypes = List<String>.from(results[2] ?? []);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showLeaveRequestDialog() {
    String? selectedType;
    final fromController = TextEditingController();
    final toController = TextEditingController();
    final reasonController = TextEditingController();

    showAnimatedBottomSheet(
      context: context,
      title: 'تقديم طلب إجازة',
      subtitle: 'املأ النموذج أدناه لتقديم طلب الإجازة',
      children: [
        StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نوع الإجازة', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(hintText: 'اختر النوع'),
                  items: _leaveTypes
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(leaveTypeArabic(t)),
                          ))
                      .toList(),
                  onChanged: (v) => setSheetState(() => selectedType = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('من تاريخ', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: fromController,
                            readOnly: true,
                            decoration: const InputDecoration(hintText: 'اختر التاريخ', suffixIcon: Icon(Icons.calendar_today, size: 18)),
                            onTap: () async {
                              final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030), locale: const Locale('ar'));
                              if (date != null) fromController.text = DateFormat('yyyy-MM-dd').format(date);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('إلى تاريخ', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: toController,
                            readOnly: true,
                            decoration: const InputDecoration(hintText: 'اختر التاريخ', suffixIcon: Icon(Icons.calendar_today, size: 18)),
                            onTap: () async {
                              final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030), locale: const Locale('ar'));
                              if (date != null) toController.text = DateFormat('yyyy-MM-dd').format(date);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('السبب', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(controller: reasonController, maxLines: 3, decoration: const InputDecoration(hintText: 'أدخل السبب...')),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedType != null && fromController.text.isNotEmpty && toController.text.isNotEmpty) {
                        try {
                          await ApiService.postJson('/api/mobile/leaves', body: {
                            'leave_type': selectedType,
                            'from_date': fromController.text,
                            'to_date': toController.text,
                            'reason': reasonController.text,
                          });
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          Fluttertoast.showToast(msg: 'تم تقديم طلب الإجازة بنجاح!');
                          _loadData();
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

  String _mapStatus(String status) {
    switch (status) {
      case 'Approved': return 'approved';
      case 'Rejected': return 'rejected';
      default: return 'pending';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      default: return Icons.access_time;
    }
  }

  Color _getStatusIconColor(String status) {
    switch (status) {
      case 'approved': return const Color(0xFF16A34A);
      case 'rejected': return const Color(0xFFDC2626);
      default: return const Color(0xFFEA580C);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'approved': return const Color(0xFFDCFCE7);
      case 'rejected': return const Color(0xFFFEE2E2);
      default: return const Color(0xFFFFF7ED);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'approved': return const Color(0xFF15803D);
      case 'rejected': return const Color(0xFFDC2626);
      default: return const Color(0xFFC2410C);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved': return 'موافق عليها';
      case 'rejected': return 'مرفوضة';
      default: return 'قيد الانتظار';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMM', 'ar').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            color: const Color(0xFF284A63),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/logo.png', height: 28, color: Colors.white),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إدارة الإجازات', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600)),
                    ElevatedButton.icon(
                      onPressed: _showLeaveRequestDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('تقديم طلب'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF284A63),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_loading)
                  const Center(child: CircularProgressIndicator(color: Colors.white))
                else
                  ..._leaveBalance.map((balance) {
                    final remaining = (balance['balance'] as num?)?.toDouble() ?? 0;
                    final total = (balance['total_allocated'] as num?)?.toDouble() ?? 1;
                    final progress = total > 0 ? remaining / total : 0.0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(leaveTypeArabic(balance['leave_type']?.toString()), style: const TextStyle(fontSize: 14, color: Colors.white)),
                              Text('${remaining.toStringAsFixed(0)}/${total.toStringAsFixed(0)} يوم', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          // Leave History
          Padding(
            padding: const EdgeInsets.all(16),
            child: _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                : StaggeredColumn(
                    children: [
                      const Text('سجل الإجازات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      if (_leaves.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('لا توجد إجازات', style: TextStyle(color: Color(0xFF9CA3AF)))),
                        )
                      else
                        ..._leaves.map((leave) {
                          final status = _mapStatus(leave['status'] ?? '');
                          final days = (leave['total_leave_days'] as num?)?.toInt() ?? 1;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(leaveTypeArabic(leave['leave_type']?.toString()), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today, size: 16, color: Color(0xFF353535)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${_formatDate(leave['from_date'] ?? '')} - ${_formatDate(leave['to_date'] ?? '')}',
                                                  style: const TextStyle(fontSize: 14, color: Color(0xFF353535)),
                                                ),
                                                const SizedBox(width: 8),
                                                Text('($days ${days > 1 ? 'أيام' : 'يوم'})', style: const TextStyle(fontSize: 14, color: Color(0xFF353535))),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(_getStatusIcon(status), size: 22, color: _getStatusIconColor(status)),
                                    ],
                                  ),
                                  if ((leave['description'] ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(leave['description'], style: const TextStyle(fontSize: 14, color: Color(0xFF353535))),
                                  ],
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(color: _getStatusBgColor(status), borderRadius: BorderRadius.circular(20)),
                                    child: Text(_getStatusText(status), style: TextStyle(fontSize: 12, color: _getStatusTextColor(status))),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
