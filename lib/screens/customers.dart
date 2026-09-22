import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:fluttertoast/fluttertoast.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

/// Fixed customer-status vocabulary. MUST stay identical to
/// CUSTOMER_STATUSES in real-estate-app src/lib/validations.ts.
const List<String> kCustomerStatuses = ['مهتم', 'غير مهتم', 'قام بالشراء'];

Color _statusColor(String status) {
  switch (status) {
    case 'مهتم':
      return const Color(0xFF16A34A);
    case 'غير مهتم':
      return const Color(0xFFDC2626);
    case 'قام بالشراء':
      return const Color(0xFF2563EB);
    default:
      return const Color(0xFF6B7280);
  }
}

/// Bottom sheet: pick one of [kCustomerStatuses] + optional note.
/// Resolves to `{'status': ..., 'description': ...}` or null when dismissed.
Future<Map<String, String>?> _showStatusSheet(
  BuildContext context, {
  String? current,
}) {
  final noteController = TextEditingController();
  String? selected = kCustomerStatuses.contains(current) ? current : null;
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'تغيير الحالة',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final s in kCustomerStatuses)
                    ListTile(
                      title: Text(s),
                      leading: Icon(
                        selected == s
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected == s
                            ? _statusColor(s)
                            : const Color(0xFF9CA3AF),
                      ),
                      onTap: () => setSheetState(() => selected = s),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: 'ملاحظة (اختياري)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: selected == null
                          ? null
                          : () => Navigator.of(ctx).pop({
                                'status': selected!,
                                'description': noteController.text.trim(),
                              }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF284A63),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Opens the change-status sheet for [customerId] and saves the choice.
/// Returns true when the status was updated (caller should refresh).
Future<bool> changeCustomerStatus(
  BuildContext context,
  String customerId, {
  String? current,
}) async {
  final result = await _showStatusSheet(context, current: current);
  if (result == null) return false;
  try {
    await ApiService.postJson(
      '/api/mobile/customers/$customerId/status',
      body: {
        'status': result['status'],
        if ((result['description'] ?? '').isNotEmpty)
          'description': result['description'],
      },
    );
    Fluttertoast.showToast(msg: 'تم تحديث الحالة');
    return true;
  } catch (e) {
    Fluttertoast.showToast(msg: 'فشل تحديث الحالة: $e');
    return false;
  }
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _customers = [];
  String _search = '';
  bool _canAddCustomer = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final canAdd = await AuthService.canAddCustomer();
    if (mounted) setState(() => _canAddCustomer = canAdd);
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getJson(
        '/api/mobile/customers',
        query: _search.isEmpty ? null : {'search': _search},
      );
      setState(() {
        _customers = List<Map<String, dynamic>>.from(data ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openAddCustomer() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
    );
    if (created == true) {
      _loadData();
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _customers;
    final q = _search.toLowerCase();
    return _customers.where((c) {
      final name = (c['customerName'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || phone.contains(q);
    }).toList();
  }

  String _typeLabel(String? t) {
    switch ((t ?? '').toLowerCase()) {
      case 'individual':
        return 'فرد';
      case 'company':
        return 'شركة';
      default:
        return t ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xFF284A63), Color(0xFF0D9488)],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/logo.png', height: 28, color: Colors.white),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'العملاء',
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_canAddCustomer)
                        Material(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _openAddCustomer,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, color: Colors.white, size: 18),
                                  SizedBox(width: 4),
                                  Text(
                                    'إضافة عميل',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'عملاء مُسنَدون إليك',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'ابحث بالاسم، البريد، أو الهاتف',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'خطأ: $_error',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 64),
                              child: Center(
                                child: Text(
                                  'لا يوجد عملاء مُسنَدون إليك',
                                  style: TextStyle(color: Color(0xFF6B7280)),
                                ),
                              ),
                            )
                          : Column(
                              children: filtered
                                  .map((c) => _buildCustomerCard(c))
                                  .toList(),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final name = (customer['customerName'] ?? '').toString();
    final phone = (customer['phone'] ?? '').toString();
    final email = (customer['email'] ?? '').toString();
    final type = _typeLabel(customer['customerType'] as String?);
    final status = (customer['status'] ?? '').toString();
    final counts = (customer['_count'] as Map?) ?? const {};
    final ownedCount = (counts['ownedApartments'] as num?)?.toInt() ?? 0;
    final tenantCount = (counts['tenantApartments'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomerDetailScreen(
                customerId: customer['id']?.toString() ?? '',
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFDBEAFE),
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first,
                    style: const TextStyle(
                      color: Color(0xFF1E40AF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (type.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            type,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_left,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
            if (phone.isNotEmpty || email.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (phone.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.phone, size: 14, color: Color(0xFF6B7280)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.email, size: 14, color: Color(0xFF6B7280)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final updated = await changeCustomerStatus(
                  context,
                  customer['id']?.toString() ?? '',
                  current: status.isEmpty ? null : status,
                );
                if (updated) _loadData();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusColor(status).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag, size: 14, color: _statusColor(status)),
                    const SizedBox(width: 6),
                    Text(
                      status.isEmpty ? 'تحديد الحالة' : status,
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor(status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit, size: 12, color: _statusColor(status)),
                  ],
                ),
              ),
            ),
            if (ownedCount > 0 || tenantCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (ownedCount > 0)
                    _miniStat(
                      Icons.home,
                      '$ownedCount',
                      'يمتلك',
                      const Color(0xFF16A34A),
                    ),
                  if (ownedCount > 0 && tenantCount > 0)
                    const SizedBox(width: 8),
                  if (tenantCount > 0)
                    _miniStat(
                      Icons.key,
                      '$tenantCount',
                      'يستأجر',
                      const Color(0xFF2563EB),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _customer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await ApiService.getJson('/api/mobile/customers/${widget.customerId}');
      setState(() {
        _customer = Map<String, dynamic>.from(data as Map);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _changeStatus() async {
    final updated = await changeCustomerStatus(
      context,
      widget.customerId,
      current: (_customer?['status'] ?? '').toString(),
    );
    if (updated && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل العميل'),
          backgroundColor: const Color(0xFF284A63),
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'خطأ: $_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                : _buildDetail(),
      ),
    );
  }

  Widget _buildDetail() {
    final c = _customer!;
    final name = (c['customerName'] ?? '').toString();
    final phone = (c['phone'] ?? '').toString();
    final email = (c['email'] ?? '').toString();
    final type = (c['customerType'] ?? '').toString();
    final source = (c['source'] ?? '').toString();
    final subType = (c['type'] ?? '').toString();
    final currentStatus = (c['status'] ?? '').toString();
    final budget = (c['budget'] as num?)?.toDouble();
    final createdAt = c['createdAt']?.toString();
    final favs = List<Map<String, dynamic>>.from(c['favouriteAddresses'] ?? []);
    final logs = List<Map<String, dynamic>>.from(c['statusLogs'] ?? []);
    final owned = List<Map<String, dynamic>>.from(c['ownedApartments'] ?? []);
    final tenant = List<Map<String, dynamic>>.from(c['tenantApartments'] ?? []);

    final money = NumberFormat('#,###');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [Color(0xFF284A63), Color(0xFF0D9488)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  name.isEmpty ? '?' : name.characters.first,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Color(0xFF284A63),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (type.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  type,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
              if (currentStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        currentStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _section('معلومات الاتصال', [
          if (phone.isNotEmpty) _infoRow(Icons.phone, 'الهاتف', phone),
          if (email.isNotEmpty) _infoRow(Icons.email, 'البريد', email),
        ]),
        _section('معلومات عامة', [
          if (type.isNotEmpty) _infoRow(Icons.person, 'نوع العميل', type),
          if (source.isNotEmpty) _infoRow(Icons.source, 'المصدر', source),
          if (subType.isNotEmpty) _infoRow(Icons.category, 'التصنيف', subType),
          if (budget != null && budget > 0)
            _infoRow(Icons.attach_money, 'الميزانية',
                '${money.format(budget)} د.ع'),
          if (createdAt != null && createdAt.isNotEmpty)
            _infoRow(
              Icons.calendar_today,
              'تاريخ الإضافة',
              _formatDate(createdAt),
            ),
        ]),
        if (owned.isNotEmpty)
          _section(
            'العقارات المملوكة (${owned.length})',
            owned.map((a) => _apartmentTile(a, isOwner: true)).toList(),
          ),
        if (tenant.isNotEmpty)
          _section(
            'العقارات المستأجرة (${tenant.length})',
            tenant.map((a) => _apartmentTile(a, isOwner: false)).toList(),
          ),
        if (favs.isNotEmpty)
          _section(
            'عناوين مفضلة',
            favs.map((f) {
              final parts = [
                f['country'],
                f['city'],
                f['district'],
                f['streetAddress'],
              ]
                  .where((p) => p != null && p.toString().isNotEmpty)
                  .join('، ');
              return _infoRow(
                Icons.location_on,
                (f['territory'] ?? '').toString().isEmpty
                    ? 'عنوان'
                    : f['territory'].toString(),
                parts,
              );
            }).toList(),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _changeStatus,
              icon: const Icon(Icons.flag),
              label: const Text('تغيير الحالة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF284A63),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
        if (logs.isNotEmpty)
          _section(
            'سجل الحالات',
            logs.map((l) {
              final status = (l['status'] ?? '').toString();
              final note = (l['description'] ?? '').toString();
              final when =
                  _formatDate((l['datetime'] ?? l['createdAt'])?.toString() ?? '');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1E40AF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          when,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
        if (phone.isNotEmpty)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Fluttertoast.showToast(msg: 'الهاتف: $phone');
              },
              icon: const Icon(Icons.phone),
              label: Text('اتصل بـ $phone'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(d);
    } catch (_) {
      return iso;
    }
  }

  Widget _section(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _apartmentTile(Map<String, dynamic> a, {required bool isOwner}) {
    final number = (a['apartmentNumber'] ?? '').toString();
    final code = (a['apartmentCode'] ?? '').toString();
    final status = (a['status'] ?? '').toString();
    final compound = (a['compound'] as Map?) ?? const {};
    final compoundName = (compound['compoundName'] ?? '').toString();
    final city = (compound['city'] ?? '').toString();
    final amount = isOwner
        ? (a['cashPrice'] as num?)?.toDouble()
        : (a['monthlyRent'] as num?)?.toDouble();
    final amountLabel = isOwner ? 'د.ع سعر' : 'د.ع/شهر';
    final money = NumberFormat('#,###');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isOwner ? Icons.home : Icons.key,
            size: 20,
            color: isOwner ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number${code.isNotEmpty ? ' • $code' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (compoundName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$compoundName${city.isNotEmpty ? ' - $city' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (status.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    if (amount != null && amount > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${money.format(amount)} $amountLabel',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _budgetController = TextEditingController();
  String? _customerType;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    final budgetText = _budgetController.text.trim();
    final budget = num.tryParse(budgetText);
    final body = <String, dynamic>{
      'customerName': _nameController.text.trim(),
      if (_phoneController.text.trim().isNotEmpty)
        'phone': _phoneController.text.trim(),
      if (_emailController.text.trim().isNotEmpty)
        'email': _emailController.text.trim(),
      if (_customerType != null) 'customerType': _customerType,
      'budget': ?budget,
    };

    try {
      await ApiService.postJson('/api/mobile/customers', body: body);
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'تمت إضافة العميل بنجاح');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      Fluttertoast.showToast(msg: 'فشل إضافة العميل: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إضافة عميل'),
          backgroundColor: const Color(0xFF284A63),
          foregroundColor: Colors.white,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field(
                controller: _nameController,
                label: 'اسم العميل *',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'اسم العميل مطلوب'
                    : null,
              ),
              _field(
                controller: _phoneController,
                label: 'الهاتف',
                keyboardType: TextInputType.phone,
              ),
              _field(
                controller: _emailController,
                label: 'البريد الإلكتروني',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return t.contains('@') ? null : 'بريد إلكتروني غير صالح';
                },
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: _customerType,
                  decoration: _decoration('نوع العميل'),
                  items: const [
                    DropdownMenuItem(value: 'individual', child: Text('فرد')),
                    DropdownMenuItem(value: 'company', child: Text('شركة')),
                  ],
                  onChanged: (v) => setState(() => _customerType = v),
                ),
              ),
              _field(
                controller: _budgetController,
                label: 'الميزانية',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF284A63),
                    foregroundColor: Colors.white,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('حفظ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: _decoration(label),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
    );
  }
}
