import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:fluttertoast/fluttertoast.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
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
                  const Text(
                    'العملاء',
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
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
        if (logs.isNotEmpty)
          _section(
            'سجل الحالات',
            logs.map((l) {
              final status = (l['status'] ?? '').toString();
              final note = (l['notes'] ?? '').toString();
              final when = _formatDate(l['createdAt']?.toString() ?? '');
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
