import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/staggered_column.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login.dart';

const String kPrivacyPolicyUrl = 'https://sar-iq.com/privacy';
const String kTermsOfServiceUrl = 'https://sar-iq.com/terms';
const String kSupportEmail = 'support@sar-realestate.com';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await ApiService.getJson('/api/mobile/me');
      if (!mounted) return;

      final user = (data is Map ? data['user'] as Map? : null) ?? {};
      final employee = (data is Map ? data['employee'] as Map? : null);
      final company = (data is Map ? data['company'] as String? : null) ?? '';

      final flat = <String, dynamic>{
        'display_name': employee?['fullName'] ?? user['name'] ?? '',
        'employee_name': employee?['fullName'] ?? user['name'] ?? '',
        'designation': employee?['position'] ?? '',
        'employee_id': employee?['employeeCode'] ?? '',
        'display_email': employee?['email'] ?? user['email'] ?? '',
        'display_phone': employee?['phone'] ?? '',
        'department': employee?['department'] ?? '',
        'date_of_joining': (employee?['hireDate'] ?? '').toString().split('T').first,
        'company': company,
      };

      setState(() {
        _profile = flat;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط')),
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final canDelete = confirmController.text.trim() == 'حذف';
            return AlertDialog(
              title: const Text('حذف الحساب'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سيؤدي هذا الإجراء إلى حذف حسابك وجميع بياناتك الشخصية المرتبطة به بشكل دائم. لا يمكن التراجع عن هذه العملية.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'للتأكيد، اكتب كلمة "حذف" في الحقل أدناه:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    onChanged: (_) => setLocal(() {}),
                    decoration: const InputDecoration(
                      hintText: 'حذف',
                      isDense: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                  onPressed: canDelete ? () => Navigator.of(ctx).pop(true) : null,
                  child: const Text('حذف نهائي'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await AuthService.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الحساب بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حذف الحساب: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = (_profile['display_name'] ?? _profile['employee_name'] ?? '...').toString();
    final String designation = (_profile['designation'] ?? '').toString();
    final String employeeId = (_profile['employee_id'] ?? '').toString();

    final infoItems = [
      {'icon': Icons.email_outlined, 'label': 'البريد الإلكتروني', 'value': (_profile['display_email'] ?? _profile['company_email'] ?? _profile['personal_email'] ?? _profile['user_email'] ?? '').toString()},
      {'icon': Icons.phone_outlined, 'label': 'الهاتف', 'value': (_profile['display_phone'] ?? _profile['cell_phone'] ?? _profile['user_mobile_no'] ?? _profile['user_phone'] ?? '').toString()},
      {'icon': Icons.work_outline, 'label': 'القسم', 'value': (_profile['department'] ?? '').toString()},
      {'icon': Icons.work_outline, 'label': 'المسمى الوظيفي', 'value': designation},
      {'icon': Icons.calendar_today_outlined, 'label': 'تاريخ الانضمام', 'value': (_profile['date_of_joining'] ?? '').toString()},
      {'icon': Icons.business_outlined, 'label': 'الشركة', 'value': (_profile['company'] ?? '').toString()},
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            height: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [Color(0xFF284A63), Color(0xFF3B6E71)]),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/logo.png', height: 28, color: Colors.white),
                const SizedBox(height: 12),
                const Text('الملف الشخصي', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // Profile Card
          Transform.translate(
            offset: const Offset(0, -64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(64), child: Center(child: CircularProgressIndicator()))
                  : StaggeredColumn(
                      children: [
                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 48,
                                  backgroundColor: const Color(0xFF284A63),
                                  child: Text(
                                    name.split(' ').where((n) => n.isNotEmpty).map((n) => n[0]).take(2).join(''),
                                    style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(designation, style: const TextStyle(fontSize: 14, color: Color(0xFF353535))),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFD9DAD9), borderRadius: BorderRadius.circular(20)),
                                  child: Text(employeeId, style: const TextStyle(fontSize: 14, color: Color(0xFF3B6E71))),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Info Card
                        Card(
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: infoItems.where((item) => (item['value'] as String).isNotEmpty).toList().asMap().entries.map((entry) {
                                final item = entry.value;
                                final filteredItems = infoItems.where((i) => (i['value'] as String).isNotEmpty).toList();
                                final isLast = entry.key == filteredItems.length - 1;
                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
                                  child: Row(children: [
                                    Icon(item['icon'] as IconData, size: 20, color: const Color(0xFF9CA3AF)),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item['label'] as String, style: const TextStyle(fontSize: 13, color: Color(0xFF353535))),
                                          const SizedBox(height: 2),
                                          Text(item['value'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                  ]),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Legal & Support Card
                        Card(
                          elevation: 1,
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF6B7280)),
                                title: const Text('سياسة الخصوصية', style: TextStyle(fontSize: 14)),
                                trailing: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF9CA3AF)),
                                onTap: () => _openUrl(kPrivacyPolicyUrl),
                              ),
                              const Divider(height: 1, color: Color(0xFFE5E7EB)),
                              ListTile(
                                leading: const Icon(Icons.description_outlined, color: Color(0xFF6B7280)),
                                title: const Text('شروط الاستخدام', style: TextStyle(fontSize: 14)),
                                trailing: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF9CA3AF)),
                                onTap: () => _openUrl(kTermsOfServiceUrl),
                              ),
                              const Divider(height: 1, color: Color(0xFFE5E7EB)),
                              ListTile(
                                leading: const Icon(Icons.support_agent_outlined, color: Color(0xFF6B7280)),
                                title: const Text('التواصل مع الدعم', style: TextStyle(fontSize: 14)),
                                trailing: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF9CA3AF)),
                                onTap: () => _openUrl('mailto:$kSupportEmail'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _handleLogout,
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('تسجيل الخروج'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFFECACA)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Delete Account Button (App Store Guideline 5.1.1(v))
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: TextButton.icon(
                            onPressed: _handleDeleteAccount,
                            icon: const Icon(Icons.delete_forever_outlined, size: 18),
                            label: const Text('حذف الحساب'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'حذف الحساب عملية دائمة ولا يمكن التراجع عنها',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
