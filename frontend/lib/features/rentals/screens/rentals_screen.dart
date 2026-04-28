import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../../units/providers/unit_provider.dart';
import '../providers/rentals_provider.dart';

class RentalsScreen extends ConsumerStatefulWidget {
  const RentalsScreen({super.key});

  @override
  ConsumerState<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends ConsumerState<RentalsScreen> {
  final ScrollController _scrollController = ScrollController();
  String _filter = 'Active';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(rentalsProvider.notifier).loadNextPage();
    }
  }

  void _updateFilter(String f) {
    setState(() => _filter = f);
    ref.read(rentalsProvider.notifier).loadRentals();
  }

  @override
  Widget build(BuildContext context) {
    final rentalsAsync = ref.watch(rentalsProvider);
    final notifier = ref.read(rentalsProvider.notifier);
    final currentUser = ref.watch(authProvider).user;
    final canManage = !(currentUser?.isUnitLocked ?? false);
    final isWide = MediaQuery.of(context).size.width >= 768;

    final filtersWidget = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.lg,
        vertical: AppDimensions.md,
      ),
      child: Row(
        children: [
          _FilterChip(label: 'Active', isSelected: _filter == 'Active', onTap: () => _updateFilter('Active')),
          _FilterChip(label: 'All', isSelected: _filter == 'All', onTap: () => _updateFilter('All')),
          _FilterChip(label: 'Ended', isSelected: _filter == 'Ended', onTap: () => _updateFilter('Ended')),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              title: Text(
                'Rentals & Tenants',
                style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(72),
                child: filtersWidget,
              ),
            )
          : AppBar(
              backgroundColor: AppColors.primary,
              toolbarHeight: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(72),
                child: filtersWidget,
              ),
            ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEditSheet(context, ref),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.textOnPrimary),
              label: Text(
                'Add Tenant',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary),
              ),
            )
          : null,
      body: rentalsAsync.when(
        loading: () => const AppLoadingShimmer(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            child: AppCard(
              backgroundColor: AppColors.dangerSurface,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(child: Text('Error: $e', style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText))),
                  TextButton(onPressed: () => ref.read(rentalsProvider.notifier).loadRentals(), child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
        data: (records) {
          final filtered = _filter == 'Active'
              ? records.where((r) => r.isActive).toList()
              : _filter == 'Ended'
                  ? records.where((r) => !r.isActive).toList()
                  : records;

          if (filtered.isEmpty) {
            return AppEmptyState(
              emoji: '🏠',
              title: _filter == 'Active' ? 'No Active Rentals' : 'No Rental Records',
              subtitle: _filter == 'Active'
                  ? 'No units are currently rented out.\nTap + to add a tenant.'
                  : 'No rental history found.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.read(rentalsProvider.notifier).loadRentals(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.md),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _RentalCard(
                        record: filtered[i],
                        canManage: canManage,
                        onTap: () => _showDetailSheet(context, ref, filtered[i]),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),
                if (notifier.hasMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: notifier.isLoadingMore
                            ? const CircularProgressIndicator()
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDetailSheet(BuildContext context, WidgetRef ref, RentalRecord record) {
    final canManage = !(ref.read(authProvider).user?.isUnitLocked ?? false);
    final dateFormat = DateFormat('dd MMM yyyy');

    showAppSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimensions.screenPadding,
          AppDimensions.lg,
          AppDimensions.screenPadding,
          MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.xxxl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: AppDimensions.lg),
              Row(
                children: [
                  Expanded(
                    child: Text('Tenant Details', style: AppTextStyles.h1),
                  ),
                  AppStatusChip(status: record.isActive ? 'active' : 'ended'),
                ],
              ),
              const SizedBox(height: AppDimensions.lg),

              _DetailSection(title: 'Unit', children: [
                _DetailRow(label: 'Unit', value: record.unitCode),
                if (record.portion != null && record.portion!.isNotEmpty)
                  _DetailRow(label: 'Portion / Floor', value: record.portion!),
                if (record.ownerName != null) _DetailRow(label: 'Owner', value: record.ownerName!),
              ]),

              _DetailSection(title: 'Tenant Information', children: [
                _DetailRow(label: 'Name', value: record.tenantName),
                _DetailRow(label: 'Phone', value: record.tenantPhone),
                if (record.tenantEmail != null) _DetailRow(label: 'Email', value: record.tenantEmail!),
                if (record.tenantAadhaar != null) _DetailRow(label: 'Aadhaar', value: record.tenantAadhaar!),
                _DetailRow(label: 'Total People', value: record.membersCount.toString()),
                if (record.nokName != null) _DetailRow(label: 'Next of Kin', value: record.nokName!),
                if (record.nokPhone != null) _DetailRow(label: 'NoK Phone', value: record.nokPhone!),
              ]),

              if (record.members.isNotEmpty)
                _DetailSection(title: 'Who Stays Here (${record.members.length})', children: [
                  ...record.members.map((m) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      border: Border.all(color: const Color(0xFFFFE0B2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFE65100).withOpacity(0.15),
                          child: Icon(
                            m.relation == 'CHILD' ? Icons.child_care : Icons.person,
                            size: 14,
                            color: const Color(0xFFE65100),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                              Text(
                                [
                                  m.relationLabel,
                                  if (m.age != null) '${m.age} yrs',
                                  if (m.gender != null) m.gender!.toLowerCase(),
                                ].join(' \u2022 '),
                                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        if (m.phone != null && m.phone!.isNotEmpty)
                          Text(m.phone!, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  )),
                ]),

              _DetailSection(title: 'Agreement', children: [
                _DetailRow(label: 'Type', value: record.agreementType),
                if (record.rentAmount != null)
                  _DetailRow(label: 'Rent Amount', value: '\u20B9${record.rentAmount!.toStringAsFixed(0)}/mo'),
                if (record.securityDeposit != null)
                  _DetailRow(label: 'Security Deposit', value: '\u20B9${record.securityDeposit!.toStringAsFixed(0)}'),
                _DetailRow(label: 'Start Date', value: dateFormat.format(record.agreementStartDate)),
                if (record.agreementEndDate != null)
                  _DetailRow(label: 'End Date', value: dateFormat.format(record.agreementEndDate!)),
                _DetailRow(
                  label: 'Police Verification',
                  value: record.policeVerification ? 'Done' : 'Pending',
                  valueColor: record.policeVerification ? AppColors.success : AppColors.warning,
                ),
              ]),

              if (record.documents.isNotEmpty)
                _DetailSection(title: 'Documents (${record.documents.length})', children: [
                  ...record.documents.map((doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        final url = AppConstants.uploadUrlFromPath(doc.fileUrl);
                        if (url != null) launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      },
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              doc.fileType.contains('pdf') ? Icons.picture_as_pdf : Icons.image_outlined,
                              size: 20,
                              color: doc.fileType.contains('pdf') ? AppColors.danger : AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(doc.docTypeLabel, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                                  Text(doc.fileName, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            const Icon(Icons.open_in_new, size: 16, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  )),
                ]),

              if (record.notes != null && record.notes!.isNotEmpty) ...[
                _DetailSection(title: 'Notes', children: [
                  Text(record.notes!, style: AppTextStyles.bodySmall),
                ]),
              ],

              if (canManage) ...[
                const SizedBox(height: AppDimensions.lg),
                Row(
                  children: [
                    if (record.isActive)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final ok = await showConfirmSheet(
                              context: context,
                              title: 'End Rental',
                              message: 'End rental for ${record.tenantName} at unit ${record.unitCode}? The unit will revert to owner-occupied.',
                              confirmLabel: 'End Rental',
                            );
                            if (ok && context.mounted) {
                              final error = await ref.read(rentalsProvider.notifier).endRental(record.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(error == null ? 'Rental ended' : error),
                                  backgroundColor: error == null ? AppColors.success : AppColors.danger,
                                ));
                                ref.read(unitsProvider.notifier).fetchUnits();
                              }
                            }
                          },
                          icon: const Icon(Icons.stop_circle_outlined, color: AppColors.warning),
                          label: const Text('End Rental'),
                        ),
                      ),
                    if (record.isActive) const SizedBox(width: AppDimensions.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddEditSheet(context, ref, record: record);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEditSheet(BuildContext context, WidgetRef ref, {RentalRecord? record}) {
    final isEdit = record != null;
    final nameCtrl = TextEditingController(text: record?.tenantName);
    final phoneCtrl = TextEditingController(text: record?.tenantPhone);
    final emailCtrl = TextEditingController(text: record?.tenantEmail);
    final aadhaarCtrl = TextEditingController(text: record?.tenantAadhaar);
    final rentCtrl = TextEditingController(text: record?.rentAmount?.toStringAsFixed(0) ?? '');
    final depositCtrl = TextEditingController(text: record?.securityDeposit?.toStringAsFixed(0) ?? '');
    final portionCtrl = TextEditingController(text: record?.portion);
    final nokNameCtrl = TextEditingController(text: record?.nokName);
    final nokPhoneCtrl = TextEditingController(text: record?.nokPhone);
    final notesCtrl = TextEditingController(text: record?.notes);

    String? selectedUnitId = record?.unitId;
    String agreementType = record?.agreementType ?? 'RENT';
    DateTime startDate = record?.agreementStartDate ?? DateTime.now();
    DateTime? endDate = record?.agreementEndDate;
    bool policeVerification = record?.policeVerification ?? false;

    // Document attachments: map of docType -> picked file
    final Map<String, XFile?> docFiles = {};
    // Already uploaded docs (for edit mode)
    final List<RentalDocument> existingDocs = record?.documents ?? [];

    // Family members list
    final List<_MemberEntry> memberEntries = [];
    if (record != null && record.members.isNotEmpty) {
      for (final m in record.members) {
        memberEntries.add(_MemberEntry(
          nameCtrl: TextEditingController(text: m.name),
          phoneCtrl: TextEditingController(text: m.phone ?? ''),
          ageCtrl: TextEditingController(text: m.age?.toString() ?? ''),
          relation: m.relation,
          gender: m.gender,
          isAdult: m.isAdult,
        ));
      }
    }

    ref.read(unitsProvider.notifier).fetchUnits();

    showAppSheet(
      context: context,
      builder: (ctx) {
        String? errorMsg;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            bool hasAadhaarDoc = docFiles.containsKey('AADHAAR') || existingDocs.any((d) => d.docType == 'AADHAAR');
            bool hasAgreementDoc = docFiles.containsKey('RENT_AGREEMENT') || existingDocs.any((d) => d.docType == 'RENT_AGREEMENT');

            Future<void> pickDoc(String docType) async {
              final result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                allowMultiple: false,
              );
              if (result != null && result.files.isNotEmpty) {
                final f = result.files.first;
                if (f.path != null) {
                  setDlgState(() => docFiles[docType] = XFile(f.path!, name: f.name));
                }
              }
            }

            Widget buildDocSlot(String docType, String label, {bool mandatory = false}) {
              final hasExisting = existingDocs.any((d) => d.docType == docType);
              final hasPicked = docFiles.containsKey(docType);
              final picked = docFiles[docType];

              return Container(
                margin: const EdgeInsets.only(bottom: AppDimensions.sm),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (hasPicked || hasExisting) ? AppColors.successSurface : (mandatory ? const Color(0xFFFFF8E1) : AppColors.surfaceVariant),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                    color: (hasPicked || hasExisting)
                        ? AppColors.success
                        : (mandatory ? AppColors.warning : AppColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (hasPicked || hasExisting) ? Icons.check_circle : Icons.upload_file_rounded,
                      color: (hasPicked || hasExisting) ? AppColors.success : (mandatory ? AppColors.warning : AppColors.textMuted),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                              if (mandatory) ...[
                                const SizedBox(width: 4),
                                Text('*', style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold)),
                              ],
                            ],
                          ),
                          if (hasPicked)
                            Text(picked!.name, style: AppTextStyles.caption.copyWith(color: AppColors.successText), maxLines: 1, overflow: TextOverflow.ellipsis)
                          else if (hasExisting)
                            Text(existingDocs.firstWhere((d) => d.docType == docType).fileName, style: AppTextStyles.caption.copyWith(color: AppColors.successText), maxLines: 1, overflow: TextOverflow.ellipsis)
                          else
                            Text('Tap to upload (JPG, PNG, PDF)', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    if (hasPicked)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                        onPressed: () => setDlgState(() => docFiles.remove(docType)),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      )
                    else
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, size: 22, color: (hasPicked || hasExisting) ? AppColors.success : AppColors.primary),
                        onPressed: () => pickDoc(docType),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.screenPadding,
                AppDimensions.lg,
                AppDimensions.screenPadding,
                MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.xxxl,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    Text(isEdit ? 'Edit Rental' : 'Add Tenant', style: AppTextStyles.h1),
                    const SizedBox(height: AppDimensions.sm),
                    Text(
                      isEdit
                          ? 'Update rental details for ${record.tenantName}'
                          : 'Register a new tenant for a rented unit',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppDimensions.lg),

                    // Unit selection
                    if (!isEdit)
                      Consumer(
                        builder: (ctx, ref, _) {
                          final unitsAsync = ref.watch(unitsProvider);
                          return unitsAsync.when(
                            data: (units) => AppSearchableDropdown<String?>(
                              label: 'Unit *',
                              value: units.any((u) => u['id'].toString() == selectedUnitId)
                                  ? selectedUnitId
                                  : null,
                              items: [
                                const AppDropdownItem(value: null, label: 'Select Unit'),
                                ...units.map((u) => AppDropdownItem(
                                  value: u['id'].toString(),
                                  label: u['fullCode'],
                                )),
                              ],
                              onChanged: (v) => setDlgState(() => selectedUnitId = v),
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) => const Text('Error loading units'),
                          );
                        },
                      ),
                    if (!isEdit) const SizedBox(height: AppDimensions.md),

                    // Portion / Floor (useful for multi-tenant units)
                    AppTextField(
                      label: 'Portion / Floor (optional)',
                      controller: portionCtrl,
                      hint: 'e.g. Ground Floor, 1st Floor, Room A',
                    ),
                    const SizedBox(height: AppDimensions.md),

                    // Tenant Details
                    Text('Tenant Details', style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                    const Divider(height: AppDimensions.md),
                    AppTextField(label: 'Tenant Name *', controller: nameCtrl),
                    const SizedBox(height: AppDimensions.md),
                    Row(
                      children: [
                        Expanded(child: AppTextField(label: 'Phone *', controller: phoneCtrl, keyboardType: TextInputType.phone)),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(child: AppTextField(label: 'Email', controller: emailCtrl, keyboardType: TextInputType.emailAddress)),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),
                    AppTextField(label: 'Aadhaar No.', controller: aadhaarCtrl, keyboardType: TextInputType.number),

                    // Family Members Section
                    const SizedBox(height: AppDimensions.lg),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0).withOpacity(0.55),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(color: const Color(0xFFFFE0B2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.groups_rounded, color: Color(0xFFE65100)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Family Members / Who Stays',
                                        style: AppTextStyles.h3.copyWith(color: const Color(0xFFE65100)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE65100).withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Total: ${memberEntries.where((e) => e.nameCtrl.text.trim().isNotEmpty).length + 1}',
                                        style: AppTextStyles.caption.copyWith(
                                          color: const Color(0xFFE65100),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add spouse/children/parents so society can see exactly who stays in the unit.',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      setDlgState(() {
                                        memberEntries.add(_MemberEntry(
                                          nameCtrl: TextEditingController(),
                                          phoneCtrl: TextEditingController(),
                                          ageCtrl: TextEditingController(),
                                        ));
                                      });
                                    },
                                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                                    label: const Text('Add family member'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    if (memberEntries.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: AppColors.textMuted.withOpacity(0.8)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No family members added yet. Tap “Add family member”.',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ...List.generate(memberEntries.length, (i) {
                      final entry = memberEntries[i];
                      final relationLabel = {
                        'SELF': 'Self (Tenant)',
                        'SPOUSE': 'Spouse',
                        'CHILD': 'Child',
                        'PARENT': 'Parent',
                        'SIBLING': 'Sibling',
                        'OTHER': 'Other',
                      }[entry.relation] ?? 'Other';

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppDimensions.sm),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    'Person ${i + 1} • $relationLabel',
                                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Remove',
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                  onPressed: () => setDlgState(() => memberEntries.removeAt(i)),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.sm),
                            AppTextField(label: 'Full name *', controller: entry.nameCtrl),
                            const SizedBox(height: AppDimensions.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: AppSearchableDropdown<String>(
                                    label: 'Relation',
                                    value: entry.relation,
                                    items: const [
                                      AppDropdownItem(value: 'SELF', label: 'Self (Tenant)'),
                                      AppDropdownItem(value: 'SPOUSE', label: 'Spouse'),
                                      AppDropdownItem(value: 'CHILD', label: 'Child'),
                                      AppDropdownItem(value: 'PARENT', label: 'Parent'),
                                      AppDropdownItem(value: 'SIBLING', label: 'Sibling'),
                                      AppDropdownItem(value: 'OTHER', label: 'Other'),
                                    ],
                                    onChanged: (v) => setDlgState(() => entry.relation = v ?? 'OTHER'),
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.sm),
                                SizedBox(
                                  width: 74,
                                  child: AppTextField(
                                    label: 'Age',
                                    controller: entry.ageCtrl,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: AppSearchableDropdown<String?>(
                                    label: 'Gender (optional)',
                                    value: entry.gender,
                                    items: const [
                                      AppDropdownItem(value: null, label: 'Select'),
                                      AppDropdownItem(value: 'MALE', label: 'Male'),
                                      AppDropdownItem(value: 'FEMALE', label: 'Female'),
                                      AppDropdownItem(value: 'OTHER', label: 'Other'),
                                    ],
                                    onChanged: (v) => setDlgState(() => entry.gender = v),
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.sm),
                                Expanded(
                                  child: AppTextField(
                                    label: 'Phone (optional)',
                                    controller: entry.phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    // Documents Section
                    const SizedBox(height: AppDimensions.lg),
                    Text('Documents', style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                    const Divider(height: AppDimensions.md),
                    buildDocSlot('AADHAAR', 'Aadhaar Card', mandatory: true),
                    buildDocSlot('RENT_AGREEMENT', 'Rent Agreement', mandatory: true),
                    buildDocSlot('POLICE_VERIFICATION', 'Police Verification'),
                    buildDocSlot('ID_PROOF', 'ID Proof (PAN, Passport, etc.)'),
                    buildDocSlot('OTHER', 'Other Document'),

                    // Agreement Details
                    const SizedBox(height: AppDimensions.lg),
                    Text('Agreement Details', style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                    const Divider(height: AppDimensions.md),

                    AppSearchableDropdown<String>(
                      label: 'Agreement Type',
                      value: agreementType,
                      items: const [
                        AppDropdownItem(value: 'RENT', label: 'Rent'),
                        AppDropdownItem(value: 'LEASE', label: 'Lease'),
                        AppDropdownItem(value: 'LICENSE', label: 'Leave & License'),
                      ],
                      onChanged: (v) => setDlgState(() => agreementType = v ?? 'RENT'),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Row(
                      children: [
                        Expanded(child: AppTextField(label: 'Rent Amount (\u20B9)', controller: rentCtrl, keyboardType: TextInputType.number)),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(child: AppTextField(label: 'Security Deposit (\u20B9)', controller: depositCtrl, keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),

                    Row(
                      children: [
                        Expanded(
                          child: _DatePickerField(
                            label: 'Start Date *',
                            value: startDate,
                            onChanged: (d) => setDlgState(() => startDate = d),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: _DatePickerField(
                            label: 'End Date',
                            value: endDate,
                            onChanged: (d) => setDlgState(() => endDate = d),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),

                    SwitchListTile(
                      title: const Text('Police Verification Done'),
                      value: policeVerification,
                      onChanged: (v) => setDlgState(() => policeVerification = v),
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.success,
                    ),

                    const SizedBox(height: AppDimensions.md),
                    Text('Emergency Contact', style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                    const Divider(height: AppDimensions.md),
                    Row(
                      children: [
                        Expanded(child: AppTextField(label: 'Next of Kin Name', controller: nokNameCtrl)),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(child: AppTextField(label: 'NoK Phone', controller: nokPhoneCtrl, keyboardType: TextInputType.phone)),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),
                    AppTextField(label: 'Notes', controller: notesCtrl, maxLines: 2),

                    if (errorMsg != null) ...[
                      const SizedBox(height: AppDimensions.md),
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.sm),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSurface,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Text(errorMsg!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
                      ),
                    ],

                    const SizedBox(height: AppDimensions.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
                                  setDlgState(() => errorMsg = 'Name and phone are required');
                                  return;
                                }
                                if (!isEdit && selectedUnitId == null) {
                                  setDlgState(() => errorMsg = 'Please select a unit');
                                  return;
                                }
                                // Validate mandatory documents
                                if (!hasAadhaarDoc) {
                                  setDlgState(() => errorMsg = 'Aadhaar Card document is mandatory. Please upload it.');
                                  return;
                                }
                                if (!hasAgreementDoc) {
                                  setDlgState(() => errorMsg = 'Rent Agreement document is mandatory. Please upload it.');
                                  return;
                                }

                                setDlgState(() { isSaving = true; errorMsg = null; });

                                // Build members list from entries
                                final List<RentalMember> membersList = memberEntries
                                    .where((e) => e.nameCtrl.text.trim().isNotEmpty)
                                    .map((e) => RentalMember(
                                      name: e.nameCtrl.text.trim(),
                                      relation: e.relation,
                                      age: int.tryParse(e.ageCtrl.text),
                                      gender: e.gender,
                                      phone: e.phoneCtrl.text.trim().isEmpty ? null : e.phoneCtrl.text.trim(),
                                      isAdult: (int.tryParse(e.ageCtrl.text) ?? 18) >= 18,
                                    ))
                                    .toList();

                                final data = <String, dynamic>{
                                  'portion': portionCtrl.text.trim().isEmpty ? null : portionCtrl.text.trim(),
                                  'tenantName': nameCtrl.text.trim(),
                                  'tenantPhone': phoneCtrl.text.trim(),
                                  'tenantEmail': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                                  'tenantAadhaar': aadhaarCtrl.text.trim().isEmpty ? null : aadhaarCtrl.text.trim(),
                                  'membersCount': membersList.isNotEmpty ? membersList.length : 1,
                                  'agreementType': agreementType,
                                  'rentAmount': double.tryParse(rentCtrl.text),
                                  'securityDeposit': double.tryParse(depositCtrl.text),
                                  'agreementStartDate': startDate.toIso8601String(),
                                  'policeVerification': policeVerification,
                                  'nokName': nokNameCtrl.text.trim().isEmpty ? null : nokNameCtrl.text.trim(),
                                  'nokPhone': nokPhoneCtrl.text.trim().isEmpty ? null : nokPhoneCtrl.text.trim(),
                                  'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                };
                                if (endDate != null) data['agreementEndDate'] = endDate!.toIso8601String();
                                if (!isEdit) data['unitId'] = selectedUnitId;

                                // Collect files and their types
                                final List<XFile> fileList = [];
                                final List<String> typeList = [];
                                for (final entry in docFiles.entries) {
                                  if (entry.value != null) {
                                    typeList.add(entry.key);
                                    fileList.add(entry.value!);
                                  }
                                }

                                String? error;
                                if (isEdit) {
                                  error = await ref.read(rentalsProvider.notifier).updateRental(record.id, data, files: fileList, docTypes: typeList);
                                  if (error == null && membersList.isNotEmpty) {
                                    error = await ref.read(rentalsProvider.notifier).syncMembers(record.id, membersList);
                                  }
                                } else {
                                  error = await ref.read(rentalsProvider.notifier).createRental(data, files: fileList, docTypes: typeList, members: membersList);
                                }

                                if (ctx.mounted) {
                                  if (error == null) {
                                    Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(isEdit ? 'Rental updated' : 'Tenant added'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                      ref.read(unitsProvider.notifier).fetchUnits();
                                    }
                                  } else {
                                    setDlgState(() { isSaving = false; errorMsg = error; });
                                  }
                                }
                              },
                        child: isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isEdit ? 'Update' : 'Add Tenant'),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Supporting Widgets ─────────────────────────────────────────────────

class _RentalCard extends StatelessWidget {
  final RentalRecord record;
  final bool canManage;
  final VoidCallback onTap;

  const _RentalCard({required this.record, required this.canManage, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final isExpiring = record.isActive &&
        record.agreementEndDate != null &&
        record.agreementEndDate!.difference(DateTime.now()).inDays <= 30 &&
        record.agreementEndDate!.isAfter(DateTime.now());
    final isExpired = record.isActive &&
        record.agreementEndDate != null &&
        record.agreementEndDate!.isBefore(DateTime.now());

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth > 800 ? 800 : constraints.maxWidth;
        return Center(
          child: Container(
            width: maxWidth,
            margin: const EdgeInsets.only(bottom: AppDimensions.md),
            child: AppCard(
              onTap: onTap,
              leftBorderColor: record.isActive
                  ? (isExpired ? AppColors.danger : isExpiring ? AppColors.warning : AppColors.primary)
                  : AppColors.textMuted,
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: record.isActive ? AppColors.primarySurface : AppColors.background,
                        child: Text(
                          record.tenantName.isNotEmpty ? record.tenantName[0].toUpperCase() : '?',
                          style: AppTextStyles.h3.copyWith(color: record.isActive ? AppColors.primary : AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.tenantName,
                              style: AppTextStyles.h3.copyWith(
                                color: record.isActive ? AppColors.textPrimary : AppColors.textMuted,
                                decoration: record.isActive ? null : TextDecoration.lineThrough,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.apartment_rounded, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  'Unit ${record.unitCode}',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                                ),
                                if (record.portion != null && record.portion!.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Text('- ${record.portion}', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                                ],
                                const SizedBox(width: AppDimensions.sm),
                                AppStatusChip(status: record.agreementType),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppStatusChip(
                            status: !record.isActive
                                ? 'ended'
                                : isExpired
                                    ? 'expired'
                                    : isExpiring
                                        ? 'expiring'
                                        : 'active',
                          ),
                          if (record.rentAmount != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '\u20B9${record.rentAmount!.toStringAsFixed(0)}/mo',
                              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  const Divider(height: 1),
                  const SizedBox(height: AppDimensions.sm),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(record.tenantPhone, style: AppTextStyles.caption),
                      const Spacer(),
                      const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${dateFormat.format(record.agreementStartDate)}${record.agreementEndDate != null ? ' - ${dateFormat.format(record.agreementEndDate!)}' : ''}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  if (record.documents.isNotEmpty || (!record.policeVerification && record.isActive)) ...[
                    const SizedBox(height: AppDimensions.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (record.documents.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.infoSurface,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.attach_file, size: 14, color: AppColors.info),
                                const SizedBox(width: 4),
                                Text('${record.documents.length} doc${record.documents.length > 1 ? 's' : ''}', style: AppTextStyles.caption.copyWith(color: AppColors.info)),
                              ],
                            ),
                          ),
                        if (!record.policeVerification && record.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warningSurface,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                                const SizedBox(width: 4),
                                Text('Police verification pending', style: AppTextStyles.caption.copyWith(color: AppColors.warningText)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimensions.md),
        Text(title, style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
        const Divider(height: AppDimensions.md),
        ...children,
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  const _DatePickerField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value != null ? dateFormat.format(value!) : 'Select date',
          style: AppTextStyles.bodySmall.copyWith(
            color: value != null ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _MemberEntry {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController ageCtrl;
  String relation;
  String? gender;
  bool isAdult;

  _MemberEntry({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.ageCtrl,
    this.relation = 'SELF',
    this.gender,
    this.isAdult = true,
  });
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppDimensions.sm),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
