// NOTE: This form mirrors `apartmentSchema` in
// real-estate-app/src/lib/validations.ts. If you add or rename a field in that
// schema, update this form to match so mobile and admin stay in lockstep.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../widgets/animated_bottom_sheet.dart';
import '../widgets/staggered_column.dart';
import '../services/api_service.dart';

class ApartmentsScreen extends StatefulWidget {
  const ApartmentsScreen({super.key});

  @override
  State<ApartmentsScreen> createState() => _ApartmentsScreenState();
}

class _ApartmentsScreenState extends State<ApartmentsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _apartments = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await ApiService.getJson('/api/mobile/apartments');
      if (!mounted) return;
      setState(() {
        _apartments = List<Map<String, dynamic>>.from(data['apartments'] ?? []);
        _stats = Map<String, dynamic>.from(data['stats'] ?? {});
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normStatus(String s) => s.toLowerCase().replaceAll(' ', '_');

  Color _getStatusBgColor(String status) {
    switch (_normStatus(status)) {
      case 'vacant': return const Color(0xFFDCFCE7);
      case 'occupied': return const Color(0xFFD9DAD9);
      case 'reserved': return const Color(0xFFDBEAFE);
      case 'sold': return const Color(0xFFFEE2E2);
      default: return const Color(0xFFFFF7ED);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (_normStatus(status)) {
      case 'vacant': return const Color(0xFF15803D);
      case 'occupied': return const Color(0xFF284A63);
      case 'reserved': return const Color(0xFF1E40AF);
      case 'sold': return const Color(0xFFB91C1C);
      default: return const Color(0xFFC2410C);
    }
  }

  String _getStatusText(String status) {
    switch (_normStatus(status)) {
      case 'vacant': return 'متاحة';
      case 'occupied': return 'مؤجرة';
      case 'reserved': return 'محجوزة';
      case 'sold': return 'مباعة';
      case 'under_maintenance': return 'صيانة';
      default: return status;
    }
  }

  Future<void> _showEditAvailableUnitsDialog(Map<String, dynamic> apartment) async {
    final id = apartment['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final current = apartment['availableUnits'];
    final controller = TextEditingController(
      text: current == null ? '' : current.toString(),
    );
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('تعديل عدد الوحدات'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الشقة: ${apartment['apartmentNumber'] ?? ''}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'عدد الوحدات المتاحة',
                        hintText: '0',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final text = controller.text.trim();
                            final parsed = text.isEmpty ? null : int.tryParse(text);
                            if (text.isNotEmpty && (parsed == null || parsed < 0)) {
                              Fluttertoast.showToast(msg: 'أدخل رقمًا صحيحًا');
                              return;
                            }
                            setDialogState(() => saving = true);
                            try {
                              await ApiService.patchJson(
                                '/api/mobile/apartments/$id',
                                body: {'availableUnits': parsed},
                              );
                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                              Fluttertoast.showToast(msg: 'تم حفظ التعديل');
                              _loadData();
                            } catch (e) {
                              setDialogState(() => saving = false);
                              Fluttertoast.showToast(msg: 'خطأ: $e');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('حفظ'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddApartmentDialog() async {
    // Load compounds (with blocks) from the mobile API
    List<Map<String, dynamic>> compounds = [];
    String? compoundsError;
    try {
      final data = await ApiService.getJson('/api/mobile/apartments/compounds');
      compounds = List<Map<String, dynamic>>.from(data ?? []);
    } catch (e) {
      compoundsError = e.toString();
    }

    if (!mounted) return;

    // --- Controllers ---
    final apartmentNumberController = TextEditingController();
    final buildingNumberController = TextEditingController();
    final floorNumberController = TextEditingController();
    final bedroomsController = TextEditingController();
    final bathroomsController = TextEditingController();
    final livingRoomsController = TextEditingController();
    final areaController = TextEditingController();
    final netAreaController = TextEditingController();
    final numberOfFloorsController = TextEditingController();
    final availableUnitsController = TextEditingController();
    final rentController = TextEditingController();
    final monthlyMaintenanceFeeController = TextEditingController();
    final securityDepositController = TextEditingController();
    final outstandingBalanceController = TextEditingController();
    final notesController = TextEditingController();
    final cashPriceController = TextEditingController();
    final downPaymentController = TextEditingController();
    final monthlyInstallmentController = TextEditingController();
    final installmentYearsController = TextEditingController();
    final totalInstallmentPriceController = TextEditingController();
    final leaseStartController = TextEditingController();
    final leaseEndController = TextEditingController();
    final moveInController = TextEditingController();
    final floorPlanController = TextEditingController();

    // --- State ---
    String? selectedCompoundId;
    String? selectedBlockId;
    String? selectedApartmentType;
    String selectedStatus = 'Vacant';
    String? selectedOccupancyType;
    String? selectedFurnishing;
    String? selectedViewType;
    String? selectedCondition;
    String? selectedBuildingStatus;
    String? selectedPaymentMethod;
    String selectedInstallmentFrequency = 'Monthly';
    bool directFromOwner = false;
    bool throughBroker = false;

    bool hasBalcony = false;
    bool hasMaidRoom = false;
    bool hasElevator = false;
    bool hasSecurity = false;
    bool hasSwimmingPool = false;
    bool hasPrivateGarden = false;
    bool hasKidsPlayArea = false;
    bool hasCoveredParking = false;
    bool hasAirConditioning = false;
    bool petsAllowed = false;
    bool hasLandlinePhone = false;
    bool hasKitchenAppliances = false;
    bool hasWaterMeter = false;
    bool hasElectricityMeter = false;
    bool hasNaturalGasMeter = false;

    List<File> selectedImages = [];

    // --- Options ---
    final apartmentTypes = ['Studio', '1BR', '2BR', '3BR', '4BR', 'Penthouse', 'Duplex', 'Villa', 'Furnished Apartment', 'Chalet', 'Land', 'Building', 'Commercial', 'Administrative', 'Medical', 'Other'];
    final statusOptions = ['Vacant', 'Occupied', 'Under Maintenance', 'Reserved', 'Sold'];
    final occupancyOptions = ['Rent', 'Sale', 'Both'];
    final furnishingOptions = ['Unfurnished', 'Semi-Furnished', 'Fully Furnished'];
    final viewOptions = ['Main Street', 'Side Street', 'Corner', 'Back', 'Garden', 'Pool', 'Sea', 'City', 'Internal', 'Nile', 'Golf', 'Plaza', 'Club', 'Lake', 'Other'];
    final conditionOptions = ['New', 'Excellent', 'Good', 'Needs Renovation'];
    final buildingStatusOptions = ['Completed', 'Under Construction', 'Off-Plan'];
    final paymentMethodOptions = ['Cash', 'Installments'];
    final frequencyOptions = ['Monthly', 'Quarterly', 'Semi-Annual', 'Annual'];

    final statusLabels = {
      'Vacant': 'شاغرة',
      'Occupied': 'مشغولة',
      'Under Maintenance': 'تحت الصيانة',
      'Reserved': 'محجوزة',
      'Sold': 'مباعة',
    };
    final occupancyLabels = {'Rent': 'إيجار', 'Sale': 'بيع', 'Both': 'كلاهما'};
    final furnishingLabels = {'Unfurnished': 'بدون أثاث', 'Semi-Furnished': 'مفروشة جزئياً', 'Fully Furnished': 'مفروشة بالكامل'};
    final viewLabels = {
      'Main Street': 'شارع رئيسي', 'Side Street': 'شارع جانبي', 'Corner': 'ناصية',
      'Back': 'خلفي', 'Garden': 'حديقة', 'Pool': 'مسبح', 'Sea': 'بحر',
      'City': 'مدينة', 'Internal': 'داخلي', 'Nile': 'نيل', 'Golf': 'غولف',
      'Plaza': 'ساحة', 'Club': 'نادي', 'Lake': 'بحيرة', 'Other': 'أخرى',
    };
    final conditionLabels = {'New': 'جديدة', 'Excellent': 'ممتازة', 'Good': 'جيدة', 'Needs Renovation': 'تحتاج تجديد'};
    final buildingStatusLabels = {'Completed': 'مكتمل', 'Under Construction': 'قيد الإنشاء', 'Off-Plan': 'على الخرائط'};
    final paymentMethodLabels = {'Cash': 'نقدي', 'Installments': 'أقساط'};
    final frequencyLabels = {'Monthly': 'شهري', 'Quarterly': 'ربع سنوي', 'Semi-Annual': 'نصف سنوي', 'Annual': 'سنوي'};

    Future<void> pickDate(TextEditingController c) async {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        locale: const Locale('ar'),
      );
      if (date != null) c.text = DateFormat('yyyy-MM-dd').format(date);
    }

    showAnimatedBottomSheet(
      context: context,
      title: 'إضافة شقة جديدة',
      subtitle: 'املأ البيانات لإضافة شقة جديدة',
      children: [
        StatefulBuilder(
          builder: (context, setSheetState) {
            final selectedCompound = compounds.firstWhere(
              (c) => c['id'] == selectedCompoundId,
              orElse: () => <String, dynamic>{},
            );
            final blocks = List<Map<String, dynamic>>.from(selectedCompound['blocks'] ?? []);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Required ---
                const Text('المجمع السكني *', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                const SizedBox(height: 8),
                if (compoundsError != null)
                  Text('خطأ: $compoundsError', style: const TextStyle(color: Colors.red, fontSize: 13))
                else if (compounds.isEmpty)
                  const Text('لا توجد مجمعات', style: TextStyle(color: Colors.orange, fontSize: 13))
                else
                  DropdownButtonFormField<String>(
                    value: selectedCompoundId,
                    isExpanded: true,
                    hint: const Text('اختر المجمع'),
                    items: compounds.map((c) => DropdownMenuItem<String>(
                      value: c['id'] as String?,
                      child: Text((c['compoundName'] ?? '').toString()),
                    )).toList(),
                    onChanged: (v) => setSheetState(() {
                      selectedCompoundId = v;
                      selectedBlockId = null;
                    }),
                  ),

                const SizedBox(height: 12),
                const Text('المبنى (Block) *', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedBlockId,
                  isExpanded: true,
                  hint: const Text('اختر المبنى'),
                  items: blocks.map((b) => DropdownMenuItem<String>(
                    value: b['id'] as String?,
                    child: Text((b['name'] ?? '').toString()),
                  )).toList(),
                  onChanged: (v) => setSheetState(() => selectedBlockId = v),
                ),

                const SizedBox(height: 12),
                _buildField('رقم الشقة *', apartmentNumberController, 'مثال: A-101'),

                const SizedBox(height: 16),
                const Divider(),
                const Text('معلومات المبنى', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _buildField('رقم المبنى', buildingNumberController, 'B1')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField('رقم الطابق', floorNumberController, '3', isNumber: true)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _buildField('عدد الطوابق', numberOfFloorsController, '10', isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField('الوحدات المتاحة', availableUnitsController, '5', isNumber: true)),
                ]),

                const SizedBox(height: 16),
                const Divider(),
                const Text('مواصفات الوحدة', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedApartmentType,
                  isExpanded: true,
                  hint: const Text('نوع الشقة'),
                  items: apartmentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setSheetState(() => selectedApartmentType = v),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _buildField('غرف النوم', bedroomsController, '3', isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField('الحمامات', bathroomsController, '2', isNumber: true)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _buildField('غرف المعيشة', livingRoomsController, '1', isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField('المساحة (م²)', areaController, '150', isNumber: true)),
                ]),
                const SizedBox(height: 12),
                _buildField('المساحة الصافية (م²)', netAreaController, '130', isNumber: true),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: SwitchListTile(title: const Text('بلكونة', style: TextStyle(fontSize: 14)), value: hasBalcony, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setSheetState(() => hasBalcony = v))),
                  Expanded(child: SwitchListTile(title: const Text('غرفة خادمة', style: TextStyle(fontSize: 14)), value: hasMaidRoom, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setSheetState(() => hasMaidRoom = v))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('حالة التأثيث', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedFurnishing,
                        isExpanded: true, hint: const Text('اختر'),
                        items: furnishingOptions.map((f) => DropdownMenuItem(value: f, child: Text(furnishingLabels[f] ?? f))).toList(),
                        onChanged: (v) => setSheetState(() => selectedFurnishing = v),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('الإطلالة', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedViewType,
                        isExpanded: true, hint: const Text('اختر'),
                        items: viewOptions.map((v) => DropdownMenuItem(value: v, child: Text(viewLabels[v] ?? v))).toList(),
                        onChanged: (v) => setSheetState(() => selectedViewType = v),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('الحالة الإنشائية', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedCondition,
                        isExpanded: true, hint: const Text('اختر'),
                        items: conditionOptions.map((c) => DropdownMenuItem(value: c, child: Text(conditionLabels[c] ?? c))).toList(),
                        onChanged: (v) => setSheetState(() => selectedCondition = v),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('حالة البناء', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedBuildingStatus,
                        isExpanded: true, hint: const Text('اختر'),
                        items: buildingStatusOptions.map((s) => DropdownMenuItem(value: s, child: Text(buildingStatusLabels[s] ?? s))).toList(),
                        onChanged: (v) => setSheetState(() => selectedBuildingStatus = v),
                      ),
                    ]),
                  ),
                ]),

                // --- Amenities ---
                const SizedBox(height: 16),
                const Divider(),
                const Text('المرافق', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  _buildAmenityChip('مصعد', hasElevator, (v) => setSheetState(() => hasElevator = v)),
                  _buildAmenityChip('أمن', hasSecurity, (v) => setSheetState(() => hasSecurity = v)),
                  _buildAmenityChip('مسبح', hasSwimmingPool, (v) => setSheetState(() => hasSwimmingPool = v)),
                  _buildAmenityChip('حديقة خاصة', hasPrivateGarden, (v) => setSheetState(() => hasPrivateGarden = v)),
                  _buildAmenityChip('ألعاب أطفال', hasKidsPlayArea, (v) => setSheetState(() => hasKidsPlayArea = v)),
                  _buildAmenityChip('موقف مغطى', hasCoveredParking, (v) => setSheetState(() => hasCoveredParking = v)),
                  _buildAmenityChip('تكييف مركزي', hasAirConditioning, (v) => setSheetState(() => hasAirConditioning = v)),
                  _buildAmenityChip('حيوانات أليفة', petsAllowed, (v) => setSheetState(() => petsAllowed = v)),
                  _buildAmenityChip('هاتف أرضي', hasLandlinePhone, (v) => setSheetState(() => hasLandlinePhone = v)),
                  _buildAmenityChip('أجهزة مطبخ', hasKitchenAppliances, (v) => setSheetState(() => hasKitchenAppliances = v)),
                  _buildAmenityChip('عداد ماء', hasWaterMeter, (v) => setSheetState(() => hasWaterMeter = v)),
                  _buildAmenityChip('عداد كهرباء', hasElectricityMeter, (v) => setSheetState(() => hasElectricityMeter = v)),
                  _buildAmenityChip('عداد غاز', hasNaturalGasMeter, (v) => setSheetState(() => hasNaturalGasMeter = v)),
                ]),

                // --- Status & Financial ---
                const SizedBox(height: 16),
                const Divider(),
                const Text('الحالة والإيجار', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('الحالة', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        isExpanded: true,
                        items: statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(statusLabels[s] ?? s))).toList(),
                        onChanged: (v) => setSheetState(() => selectedStatus = v ?? 'Vacant'),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('نوع العرض', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedOccupancyType,
                        isExpanded: true, hint: const Text('اختر'),
                        items: occupancyOptions.map((o) => DropdownMenuItem(value: o, child: Text(occupancyLabels[o] ?? o))).toList(),
                        onChanged: (v) => setSheetState(() => selectedOccupancyType = v),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _buildField('الإيجار الشهري', rentController, '750000', isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField('رسوم الصيانة', monthlyMaintenanceFeeController, '50000', isNumber: true)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _buildField('الضمان', securityDepositController, '1000000', isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField('الرصيد المستحق', outstandingBalanceController, '0', isNumber: true)),
                ]),
                const SizedBox(height: 12),
                _buildDateField('بداية الإيجار', leaseStartController, () => pickDate(leaseStartController)),
                const SizedBox(height: 12),
                _buildDateField('نهاية الإيجار', leaseEndController, () => pickDate(leaseEndController)),
                const SizedBox(height: 12),
                _buildDateField('تاريخ الانتقال', moveInController, () => pickDate(moveInController)),

                // --- Payment ---
                const SizedBox(height: 16),
                const Divider(),
                const Text('الدفع', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedPaymentMethod,
                        isExpanded: true, hint: const Text('اختر'),
                        items: paymentMethodOptions.map((p) => DropdownMenuItem(value: p, child: Text(paymentMethodLabels[p] ?? p))).toList(),
                        onChanged: (v) => setSheetState(() => selectedPaymentMethod = v),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(children: [
                      SwitchListTile(title: const Text('من المالك', style: TextStyle(fontSize: 13)), value: directFromOwner, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setSheetState(() => directFromOwner = v)),
                      SwitchListTile(title: const Text('عبر وسيط', style: TextStyle(fontSize: 13)), value: throughBroker, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setSheetState(() => throughBroker = v)),
                    ]),
                  ),
                ]),
                if (selectedPaymentMethod == 'Cash') ...[
                  const SizedBox(height: 12),
                  _buildField('السعر النقدي', cashPriceController, '500000', isNumber: true),
                ],
                if (selectedPaymentMethod == 'Installments') ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _buildField('الدفعة الأولى', downPaymentController, '100000', isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildField('قسط شهري', monthlyInstallmentController, '25000', isNumber: true)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('تكرار الدفع', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedInstallmentFrequency,
                          isExpanded: true,
                          items: frequencyOptions.map((f) => DropdownMenuItem(value: f, child: Text(frequencyLabels[f] ?? f))).toList(),
                          onChanged: (v) => setSheetState(() => selectedInstallmentFrequency = v ?? 'Monthly'),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildField('المدة (سنوات)', installmentYearsController, '5', isNumber: true)),
                  ]),
                  const SizedBox(height: 12),
                  _buildField('السعر الإجمالي', totalInstallmentPriceController, '750000', isNumber: true),
                ],

                const SizedBox(height: 16),
                const Divider(),
                const Text('ملاحظات', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(controller: notesController, maxLines: 3, decoration: const InputDecoration(hintText: 'أدخل ملاحظات...')),
                const SizedBox(height: 12),
                _buildField('رابط الخطة (Floor Plan URL)', floorPlanController, 'https://...'),

                const SizedBox(height: 16),
                const Divider(),
                const Text('صور الشقة', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ...selectedImages.asMap().entries.map((entry) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(entry.value, width: 80, height: 80, fit: BoxFit.cover)),
                      Positioned(top: -4, right: -4, child: GestureDetector(
                        onTap: () => setSheetState(() => selectedImages.removeAt(entry.key)),
                        child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)),
                      )),
                    ],
                  )),
                  GestureDetector(
                    onTap: () async {
                      final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
                      if (picked.isNotEmpty) {
                        setSheetState(() => selectedImages.addAll(picked.map((p) => File(p.path))));
                      }
                    },
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD1D5DB))),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_a_photo_outlined, size: 24, color: Color(0xFF9CA3AF)),
                        SizedBox(height: 4),
                        Text('إضافة صور', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                      ]),
                    ),
                  ),
                ]),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedCompoundId == null || selectedBlockId == null || apartmentNumberController.text.isEmpty) {
                        Fluttertoast.showToast(msg: 'يرجى ملء المجمع، المبنى، ورقم الشقة');
                        return;
                      }
                      try {
                        List<Map<String, String>> uploadedDocs = [];
                        for (final img in selectedImages) {
                          final url = await ApiService.uploadFile(img);
                          uploadedDocs.add({'documentName': 'Photo', 'documentType': 'Photo', 'file': url});
                        }

                        num? numOrNull(String s) => s.isEmpty ? null : num.tryParse(s);

                        final body = <String, dynamic>{
                          'compoundId': selectedCompoundId,
                          'compoundBlockId': selectedBlockId,
                          'apartmentNumber': apartmentNumberController.text,
                          'buildingNumber': buildingNumberController.text.isEmpty ? null : buildingNumberController.text,
                          'floorNumber': numOrNull(floorNumberController.text),
                          'apartmentType': selectedApartmentType,
                          'numberOfBedrooms': numOrNull(bedroomsController.text),
                          'numberOfBathrooms': numOrNull(bathroomsController.text),
                          'numberOfLivingRooms': numOrNull(livingRoomsController.text),
                          'totalArea': numOrNull(areaController.text),
                          'netArea': numOrNull(netAreaController.text),
                          'numberOfFloors': numOrNull(numberOfFloorsController.text),
                          'availableUnits': numOrNull(availableUnitsController.text),
                          'furnishingStatus': selectedFurnishing,
                          'viewType': selectedViewType,
                          'condition': selectedCondition,
                          'buildingStatus': selectedBuildingStatus,
                          'hasBalcony': hasBalcony,
                          'hasMaidRoom': hasMaidRoom,
                          'hasElevator': hasElevator,
                          'hasSecurity': hasSecurity,
                          'hasSwimmingPool': hasSwimmingPool,
                          'hasPrivateGarden': hasPrivateGarden,
                          'hasKidsPlayArea': hasKidsPlayArea,
                          'hasCoveredParking': hasCoveredParking,
                          'hasAirConditioning': hasAirConditioning,
                          'petsAllowed': petsAllowed,
                          'hasLandlinePhone': hasLandlinePhone,
                          'hasKitchenAppliances': hasKitchenAppliances,
                          'hasWaterMeter': hasWaterMeter,
                          'hasElectricityMeter': hasElectricityMeter,
                          'hasNaturalGasMeter': hasNaturalGasMeter,
                          'status': selectedStatus,
                          'occupancyType': selectedOccupancyType,
                          'monthlyRent': numOrNull(rentController.text),
                          'monthlyMaintenanceFee': numOrNull(monthlyMaintenanceFeeController.text),
                          'securityDeposit': numOrNull(securityDepositController.text),
                          'outstandingBalance': numOrNull(outstandingBalanceController.text),
                          'leaseStartDate': leaseStartController.text.isEmpty ? null : leaseStartController.text,
                          'leaseEndDate': leaseEndController.text.isEmpty ? null : leaseEndController.text,
                          'moveInDate': moveInController.text.isEmpty ? null : moveInController.text,
                          'paymentMethod': selectedPaymentMethod,
                          'directFromOwner': directFromOwner,
                          'throughBroker': throughBroker,
                          'cashPrice': numOrNull(cashPriceController.text),
                          'downPayment': numOrNull(downPaymentController.text),
                          'monthlyInstallment': numOrNull(monthlyInstallmentController.text),
                          'installmentFrequency': selectedPaymentMethod == 'Installments' ? selectedInstallmentFrequency : null,
                          'installmentYears': numOrNull(installmentYearsController.text),
                          'totalInstallmentPrice': numOrNull(totalInstallmentPriceController.text),
                          'notes': notesController.text.isEmpty ? null : notesController.text,
                          'floorPlan': floorPlanController.text.isEmpty ? null : floorPlanController.text,
                          'documents': uploadedDocs,
                        };

                        await ApiService.postJson('/api/mobile/apartments', body: body);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        Fluttertoast.showToast(msg: 'تم إضافة الشقة بنجاح!');
                        _loadData();
                      } catch (e) {
                        Fluttertoast.showToast(msg: 'خطأ: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('إضافة الشقة', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(controller: controller, keyboardType: isNumber ? TextInputType.number : TextInputType.text, decoration: InputDecoration(hintText: hint)),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          decoration: const InputDecoration(hintText: 'اختر التاريخ', suffixIcon: Icon(Icons.calendar_today, size: 18)),
        ),
      ],
    );
  }

  Widget _buildAmenityChip(String label, bool selected, ValueChanged<bool> onSelected) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 13, color: selected ? Colors.white : const Color(0xFF374151))),
      selected: selected,
      onSelected: onSelected,
      selectedColor: const Color(0xFF16A34A),
      checkmarkColor: Colors.white,
      backgroundColor: const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,###');
    final total = (_stats['total'] as num?)?.toInt() ?? 0;
    final available = (_stats['available'] as num?)?.toInt() ?? 0;
    final rented = (_stats['rented'] as num?)?.toInt() ?? 0;
    final revenue = (_stats['total_revenue'] as num?)?.toDouble() ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [Color(0xFF16A34A), Color(0xFF0D9488)]),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/logo.png', height: 28, color: Colors.white),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إدارة الشقق', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600)),
                    ElevatedButton.icon(
                      onPressed: _showAddApartmentDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة شقة'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_loading)
                  const Center(child: CircularProgressIndicator(color: Colors.white))
                else
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: [
                      _buildStatCard('$total', 'إجمالي الشقق'),
                      _buildStatCard('$available', 'شقق متاحة'),
                      _buildStatCard('$rented', 'شقق مؤجرة'),
                      _buildStatCard('${numberFormat.format(revenue.toInt())} د.ع', 'الإيرادات الشهرية'),
                    ],
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                : StaggeredColumn(
                    children: [
                      Text('شققي (${_apartments.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      if (_apartments.isEmpty)
                        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('لا توجد شقق', style: TextStyle(color: Color(0xFF9CA3AF)))))
                      else
                        ..._apartments.map((apt) => _buildApartmentCard(apt, numberFormat)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildApartmentCard(Map<String, dynamic> apartment, NumberFormat numberFormat) {
    final status = (apartment['status'] ?? 'Vacant').toString();
    final price = (apartment['monthlyRent'] as num?)?.toInt() ?? 0;
    final bedrooms = (apartment['numberOfBedrooms'] as num?)?.toInt() ?? 0;
    final bathrooms = (apartment['numberOfBathrooms'] as num?)?.toInt() ?? 0;
    final area = (apartment['totalArea'] as num?)?.toInt() ?? 0;
    final compound = apartment['compound'] as Map? ?? {};
    final compoundName = (compound['compoundName'] ?? '').toString();
    final city = (compound['city'] ?? '').toString();
    final district = (compound['district'] ?? '').toString();
    final location = [compoundName, district, city].where((s) => s.isNotEmpty).join('، ');
    final title = 'شقة ${apartment['apartmentNumber'] ?? ''}';
    final code = (apartment['apartmentCode'] ?? '').toString();

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
                      Text('$title${code.isNotEmpty ? ' ($code)' : ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.location_on, size: 16, color: Color(0xFF353535)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(location, style: const TextStyle(fontSize: 14, color: Color(0xFF353535)))),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: _getStatusBgColor(status), borderRadius: BorderRadius.circular(20)),
                  child: Text(_getStatusText(status), style: TextStyle(fontSize: 12, color: _getStatusTextColor(status))),
                ),
              ],
            ),
            if ((apartment['notes'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(apartment['notes'].toString(), style: const TextStyle(fontSize: 14, color: Color(0xFF353535))),
            ],
            const SizedBox(height: 12),
            Row(children: [
              _buildInfoTile(Icons.monetization_on, numberFormat.format(price), 'د.ع/شهر', const Color(0xFF16A34A)),
              const SizedBox(width: 8),
              _buildInfoTile(Icons.bed, '$bedrooms', 'غرف', const Color(0xFF284A63)),
              const SizedBox(width: 8),
              _buildInfoTile(Icons.bathtub, '$bathrooms', 'حمامات', const Color(0xFF9333EA)),
              const SizedBox(width: 8),
              _buildInfoTile(Icons.crop_square, '$area', 'م²', const Color(0xFFEA580C)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditAvailableUnitsDialog(apartment),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('تعديل عدد الوحدات'),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF16A34A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String value, String label, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ]),
      ),
    );
  }
}
