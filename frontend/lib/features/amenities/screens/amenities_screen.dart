import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../providers/amenities_provider.dart';
import '../../../shared/widgets/show_app_sheet.dart';

class AmenitiesScreen extends ConsumerWidget {
  const AmenitiesScreen({super.key});

  static const _adminRoles = {'PRAMUKH', 'CHAIRMAN', 'SECRETARY'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.role.toUpperCase() ?? '';
    final isAdmin = _adminRoles.contains(role);
    final state = ref.watch(amenitiesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Amenities',
            style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAmenitySheet(context, ref, null),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: AppColors.textOnPrimary),
              label: Text('Add Amenity',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textOnPrimary)),
            )
          : null,
      body: state.isLoading
          ? const AppLoadingShimmer()
          : state.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.screenPadding),
                    child: AppCard(
                      backgroundColor: AppColors.dangerSurface,
                      child: Text('Error: ${state.error}',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.dangerText)),
                    ),
                  ),
                )
              : state.amenities.isEmpty
                  ? const AppEmptyState(
                      emoji: '🏊',
                      title: 'No Amenities',
                      subtitle: 'No amenities have been configured.',
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(amenitiesProvider.notifier).loadAmenities(),
                      child: GridView.builder(
                        padding:
                            const EdgeInsets.all(AppDimensions.screenPadding),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.of(context).size.width >= 600 ? 3 : 2,
                          crossAxisSpacing: AppDimensions.md,
                          mainAxisSpacing: AppDimensions.md,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: state.amenities.length,
                        itemBuilder: (_, i) => _AmenityCard(
                          amenity: state.amenities[i],
                          isAdmin: isAdmin,
                          onBook: () => _showBookingSheet(
                              context, ref, state.amenities[i]),
                          onEdit: () =>
                              _showAmenitySheet(context, ref, state.amenities[i]),
                          onDelete: () => _confirmDelete(context, ref,
                              state.amenities[i]['id'] as String? ?? ''),
                        ),
                      ),
                    ),
    );
  }

  void _showAmenitySheet(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => _AmenityFormSheet(
        existing: existing,
        onSubmit: (data) async {
          bool ok;
          if (existing != null) {
            ok = await ref.read(amenitiesProvider.notifier).updateAmenity(
                existing['id'] as String, data);
          } else {
            ok = await ref.read(amenitiesProvider.notifier).createAmenity(data);
          }
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok
                  ? (existing != null ? 'Amenity updated.' : 'Amenity created.')
                  : 'Failed to save amenity.'),
              backgroundColor: ok ? AppColors.success : AppColors.danger,
            ));
          }
        },
      ),
    );
  }

  void _showBookingSheet(
      BuildContext context, WidgetRef ref, Map<String, dynamic> amenity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => _BookingSheet(
        amenity: amenity,
        onSubmit: (data) async {
          final ok =
              await ref.read(amenitiesProvider.notifier).bookAmenity(data);
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(ok ? 'Booking submitted.' : 'Failed to book amenity.'),
              backgroundColor: ok ? AppColors.success : AppColors.danger,
            ));
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Delete Amenity',
      message: 'Are you sure you want to delete this amenity?',
      confirmLabel: 'Delete',
    );
    if (ok && context.mounted) {
      final success = await ref.read(amenitiesProvider.notifier).deleteAmenity(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Amenity deleted.' : 'Failed to delete amenity.'),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ));
      }
    }
  }
}

// ── Amenity Card ──────────────────────────────────────────────────────────────

class _AmenityCard extends StatelessWidget {
  final Map<String, dynamic> amenity;
  final bool isAdmin;
  final VoidCallback onBook;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AmenityCard({
    required this.amenity,
    required this.isAdmin,
    required this.onBook,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final a = amenity;
    final name = a['name'] as String? ?? '-';
    final openTime = a['openTime'] as String? ?? '-';
    final closeTime = a['closeTime'] as String? ?? '-';
    final capacity = a['capacity']?.toString() ?? '-';
    final fee = a['bookingFee']?.toString() ?? '0';
    final isActive = (a['status'] as String? ?? 'INACTIVE').toUpperCase() == 'ACTIVE';

    return AppCard(
      onTap: isActive ? onBook : null,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.meeting_room_rounded,
                size: 20,
                color: isActive ? AppColors.primary : AppColors.textMuted,
              ),
              const Spacer(),
              AppStatusChip(status: isActive ? 'active' : 'disabled'),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            name,
            style: AppTextStyles.h3,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimensions.xs),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 11, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  '$openTime - $closeTime',
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Row(
            children: [
              const Icon(Icons.people_outline_rounded,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text('Cap: $capacity', style: AppTextStyles.caption),
              const SizedBox(width: AppDimensions.sm),
              const Icon(Icons.currency_rupee_rounded,
                  size: 11, color: AppColors.textMuted),
              Text(fee, style: AppTextStyles.caption),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: AppDimensions.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Text(
                'Tap to Book',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (isAdmin) ...[
            const SizedBox(height: AppDimensions.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_rounded,
                      size: 15, color: AppColors.textMuted),
                ),
                const SizedBox(width: AppDimensions.sm),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 15, color: AppColors.danger),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Amenity Form Bottom Sheet ─────────────────────────────────────────────────

class _AmenityFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  const _AmenityFormSheet({this.existing, required this.onSubmit});

  @override
  State<_AmenityFormSheet> createState() => _AmenityFormSheetState();
}

class _AmenityFormSheetState extends State<_AmenityFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _openCtrl;
  late final TextEditingController _closeCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _feeCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name'] as String? ?? '');
    _descCtrl = TextEditingController(text: e?['description'] as String? ?? '');
    _openCtrl = TextEditingController(text: e?['openTime'] as String? ?? '');
    _closeCtrl = TextEditingController(text: e?['closeTime'] as String? ?? '');
    _durationCtrl = TextEditingController(
        text: e?['bookingDuration']?.toString() ?? '');
    _capacityCtrl =
        TextEditingController(text: e?['capacity']?.toString() ?? '');
    _feeCtrl =
        TextEditingController(text: e?['bookingFee']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _openCtrl.dispose();
    _closeCtrl.dispose();
    _durationCtrl.dispose();
    _capacityCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding,
        AppDimensions.lg,
        AppDimensions.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(isEdit ? 'Edit Amenity' : 'Add Amenity', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            _label('Name'),
            const SizedBox(height: AppDimensions.xs),
            _textField(_nameCtrl, 'e.g. Swimming Pool'),
            const SizedBox(height: AppDimensions.md),
            _label('Description (optional)'),
            const SizedBox(height: AppDimensions.xs),
            _textField(_descCtrl, 'Brief description...', maxLines: 2),
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Open Time'),
                      const SizedBox(height: AppDimensions.xs),
                      _textField(_openCtrl, '06:00'),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Close Time'),
                      const SizedBox(height: AppDimensions.xs),
                      _textField(_closeCtrl, '22:00'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Duration (mins)'),
                      const SizedBox(height: AppDimensions.xs),
                      _textField(_durationCtrl, '60',
                          keyboardType: TextInputType.number),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Capacity'),
                      const SizedBox(height: AppDimensions.xs),
                      _textField(_capacityCtrl, '20',
                          keyboardType: TextInputType.number),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            _label('Booking Fee'),
            const SizedBox(height: AppDimensions.xs),
            _textField(_feeCtrl, '0',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: AppDimensions.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(vertical: AppDimensions.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.textOnPrimary),
                      )
                    : Text(isEdit ? 'Update' : 'Create',
                        style: AppTextStyles.buttonLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary));

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md, vertical: AppDimensions.md),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      );

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _openCtrl.text.trim().isEmpty ||
        _closeCtrl.text.trim().isEmpty ||
        _durationCtrl.text.trim().isEmpty ||
        _capacityCtrl.text.trim().isEmpty ||
        _feeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill in all required fields.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    setState(() => _submitting = true);
    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'openTime': _openCtrl.text.trim(),
      'closeTime': _closeCtrl.text.trim(),
      'bookingDuration': int.tryParse(_durationCtrl.text.trim()) ?? 60,
      'capacity': int.tryParse(_capacityCtrl.text.trim()) ?? 1,
      'bookingFee': double.tryParse(_feeCtrl.text.trim()) ?? 0,
    };
    final desc = _descCtrl.text.trim();
    if (desc.isNotEmpty) data['description'] = desc;
    await widget.onSubmit(data);
    if (mounted) setState(() => _submitting = false);
  }
}

// ── Booking Bottom Sheet ──────────────────────────────────────────────────────

class _BookingSheet extends StatefulWidget {
  final Map<String, dynamic> amenity;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  const _BookingSheet({required this.amenity, required this.onSubmit});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  final _timeSlotCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _selectedDate;
  bool _submitting = false;

  @override
  void dispose() {
    _timeSlotCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.amenity['name'] as String? ?? 'Amenity';
    final openTime = widget.amenity['openTime'] as String? ?? '';
    final closeTime = widget.amenity['closeTime'] as String? ?? '';
    final duration = widget.amenity['bookingDuration']?.toString() ?? '';
    final fee = widget.amenity['bookingFee']?.toString() ?? '0';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding,
        AppDimensions.lg,
        AppDimensions.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text('Book $name', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.xs),
            Text(
              '$openTime - $closeTime  •  ${duration}min slots  •  ₹$fee',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppDimensions.lg),
            _label('Date'),
            const SizedBox(height: AppDimensions.xs),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md, vertical: AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: AppColors.textMuted),
                    const SizedBox(width: AppDimensions.sm),
                    Text(
                      _selectedDate != null
                          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                          : 'Select a date',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _selectedDate != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            _label('Time Slot'),
            const SizedBox(height: AppDimensions.xs),
            _textField(_timeSlotCtrl, 'e.g. 09:00-10:00'),
            const SizedBox(height: AppDimensions.md),
            _label('Notes (optional)'),
            const SizedBox(height: AppDimensions.xs),
            _textField(_notesCtrl, 'Any special requests...', maxLines: 2),
            const SizedBox(height: AppDimensions.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(vertical: AppDimensions.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.textOnPrimary),
                      )
                    : Text('Confirm Booking', style: AppTextStyles.buttonLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary));

  Widget _textField(TextEditingController ctrl, String hint, {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md, vertical: AppDimensions.md),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (_selectedDate == null || _timeSlotCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a date and enter a time slot.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    setState(() => _submitting = true);
    final data = <String, dynamic>{
      'amenityId': widget.amenity['id'] as String? ?? '',
      'date':
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
      'timeSlot': _timeSlotCtrl.text.trim(),
    };
    final notes = _notesCtrl.text.trim();
    if (notes.isNotEmpty) data['notes'] = notes;
    await widget.onSubmit(data);
    if (mounted) setState(() => _submitting = false);
  }
}
