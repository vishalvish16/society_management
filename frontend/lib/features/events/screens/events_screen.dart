import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../../../shared/widgets/app_module_scaffold.dart';
import '../providers/events_provider.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> with SingleTickerProviderStateMixin {
  static const _adminRoles = {'PRAMUKH', 'CHAIRMAN', 'SECRETARY'};
  late final TabController _tabCtrl;

  bool _isAdmin(String? role) => _adminRoles.contains((role ?? '').toUpperCase());

  @override
  void initState() {
    super.initState();
    final role = ref.read(authProvider).user?.role;
    _tabCtrl = TabController(length: _isAdmin(role) ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role;
    final isAdmin = _isAdmin(role);
    final st = ref.watch(eventsProvider);

    final tabs = <Tab>[
      const Tab(text: 'Upcoming'),
      const Tab(text: 'Past'),
      if (isAdmin) const Tab(text: 'All'),
    ];

    TabBar eventsTabBar({required bool onDarkHeader}) => TabBar(
          controller: _tabCtrl,
          tabs: tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: onDarkHeader
              ? Colors.white.withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.8),
          dividerColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
        );

    final headerActions = <Widget>[
      IconButton(
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: () => ref.read(eventsProvider.notifier).refresh(),
      ),
    ];

    return AppModuleScaffold(
      title: 'Events',
      icon: Icons.event_rounded,
      headerActions: headerActions,
      wideAppBarBottom: eventsTabBar(onDarkHeader: false),
      wideAppBarActions: [
        ...AppModuleScaffold.actionsForPrimaryAppBar(headerActions),
        if (isAdmin)
          IconButton(
            tooltip: 'Create event',
            onPressed: () => _showCreateEventSheet(context, ref),
            icon: const Icon(Icons.add_rounded, color: AppColors.textOnPrimary),
          ),
        const SizedBox(width: 8),
      ],
      filterRow: eventsTabBar(onDarkHeader: true),
      primaryFab: isAdmin
          ? ModuleFabConfig(
              onPressed: () => _showCreateEventSheet(context, ref),
              icon: Icons.add_rounded,
              tooltip: 'Create event',
              wideExtendedLabel: 'Create event',
            )
          : null,
      fabHeroTagPrefix: 'events',
      child: st.isLoading && st.events.isEmpty
          ? const AppLoadingShimmer(itemCount: 4, itemHeight: 140)
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _EventList(events: _upcoming(st.events), isAdmin: isAdmin),
                _EventList(events: _past(st.events), isAdmin: isAdmin),
                if (isAdmin) _EventList(events: st.events, isAdmin: isAdmin),
              ],
            ),
    );
  }

  List<Map<String, dynamic>> _upcoming(List<Map<String, dynamic>> events) {
    return events.where((e) {
      final s = (e['status'] ?? '').toString().toUpperCase();
      return s == 'UPCOMING' || s == 'ONGOING';
    }).toList();
  }

  List<Map<String, dynamic>> _past(List<Map<String, dynamic>> events) {
    return events.where((e) {
      final s = (e['status'] ?? '').toString().toUpperCase();
      return s == 'COMPLETED' || s == 'CANCELLED';
    }).toList();
  }
}

// ─── Event List ──────────────────────────────────────────────────────────────

class _EventList extends ConsumerWidget {
  final List<Map<String, dynamic>> events;
  final bool isAdmin;
  const _EventList({required this.events, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (events.isEmpty) {
      return const AppEmptyState(
        emoji: '🎉',
        title: 'No events',
        subtitle: 'Events created by your society will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(eventsProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.md),
        itemBuilder: (ctx, i) => _EventCard(event: events[i], isAdmin: isAdmin),
      ),
    );
  }
}

// ─── Event Card ──────────────────────────────────────────────────────────────

class _EventCard extends ConsumerWidget {
  final Map<String, dynamic> event;
  final bool isAdmin;
  const _EventCard({required this.event, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = event['title'] ?? '';
    final description = event['description'] ?? '';
    final location = event['location'] ?? '';
    final status = (event['status'] ?? 'UPCOMING').toString().toUpperCase();
    final organizer = event['organizerName'] ?? '';
    final startDate = DateTime.tryParse(event['startDate'] ?? '');
    final registered = event['registeredCount'] ?? 0;
    final maxReg = event['maxTotalRegistrations'];
    final myReg = event['myRegistration'];
    final isRegistered = myReg != null;

    final attachments = (event['attachments'] as List?) ?? [];
    final firstImage = attachments.isNotEmpty
        ? attachments.firstWhere(
            (a) => (a['fileType'] ?? '').toString().startsWith('image'),
            orElse: () => null,
          )
        : null;

    return AppCard(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _showEventDetail(context, ref, event['id']),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner image or gradient header
            if (firstImage != null)
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.network(
                  AppConstants.uploadUrlFromPath(firstImage['fileUrl']) ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _GradientHeader(title: title),
                ),
              )
            else
              _GradientHeader(title: title),

            Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status + date row
                  Row(
                    children: [
                      _StatusChip(status: status),
                      const SizedBox(width: AppDimensions.sm),
                      if (isRegistered)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.successSurface,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            border: Border.all(color: AppColors.successBorder),
                          ),
                          child: Text('Registered', style: AppTextStyles.labelSmall.copyWith(color: AppColors.successText)),
                        ),
                      const Spacer(),
                      if (startDate != null)
                        Text(
                          DateFormat('MMM dd, yyyy').format(startDate),
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),

                  // Title
                  if (firstImage != null)
                    Text(title, style: AppTextStyles.h2, maxLines: 2, overflow: TextOverflow.ellipsis),

                  if (description.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppDimensions.md),

                  // Info row
                  Wrap(
                    spacing: AppDimensions.lg,
                    runSpacing: AppDimensions.sm,
                    children: [
                      _InfoChip(icon: Icons.location_on_outlined, text: location),
                      if (startDate != null)
                        _InfoChip(
                          icon: Icons.access_time_rounded,
                          text: DateFormat('h:mm a').format(startDate),
                        ),
                      _InfoChip(
                        icon: Icons.people_outline_rounded,
                        text: maxReg != null ? '$registered / $maxReg' : '$registered registered',
                      ),
                      _InfoChip(icon: Icons.person_outline_rounded, text: organizer),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientHeader extends StatelessWidget {
  final String title;
  const _GradientHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.event_rounded, color: Colors.white70, size: 20),
          const SizedBox(height: AppDimensions.xs),
          Text(
            title,
            style: AppTextStyles.h2.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label;
    switch (status) {
      case 'UPCOMING':
        bg = AppColors.primarySurface;
        fg = AppColors.primary;
        label = 'Upcoming';
        break;
      case 'ONGOING':
        bg = AppColors.successSurface;
        fg = AppColors.successText;
        label = 'Ongoing';
        break;
      case 'COMPLETED':
        bg = AppColors.surfaceVariant;
        fg = AppColors.textMuted;
        label = 'Completed';
        break;
      case 'CANCELLED':
        bg = AppColors.dangerSurface;
        fg = AppColors.dangerText;
        label = 'Cancelled';
        break;
      default:
        bg = AppColors.surfaceVariant;
        fg = AppColors.textMuted;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: fg)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

// ─── Event Detail Sheet ──────────────────────────────────────────────────────

void _showEventDetail(BuildContext context, WidgetRef ref, String eventId) {
  showAppSheet(
    context: context,
    builder: (_) => _EventDetailSheet(eventId: eventId),
  );
}

class _EventDetailSheet extends ConsumerStatefulWidget {
  final String eventId;
  const _EventDetailSheet({required this.eventId});

  @override
  ConsumerState<_EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends ConsumerState<_EventDetailSheet> {
  Map<String, dynamic>? _event;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ref.read(eventsProvider.notifier).getEvent(widget.eventId);
    if (mounted) setState(() { _event = data; _loading = false; });
  }

  bool get _isAdmin {
    final r = ref.read(authProvider).user?.role.toUpperCase() ?? '';
    return r == 'PRAMUKH' || r == 'CHAIRMAN' || r == 'SECRETARY';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
        child: const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      );
    }
    if (_event == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
        child: const SizedBox(height: 120, child: Center(child: Text('Event not found'))),
      );
    }

    final e = _event!;
    final status = (e['status'] ?? 'UPCOMING').toString().toUpperCase();
    final startDate = DateTime.tryParse(e['startDate'] ?? '');
    final endDate = DateTime.tryParse(e['endDate'] ?? '');
    final myReg = e['myRegistration'];
    final isRegistered = myReg != null;
    final canRegister = status == 'UPCOMING' || status == 'ONGOING';
    final registered = e['registeredCount'] ?? 0;
    final maxReg = e['maxTotalRegistrations'];
    final totalMembers = e['totalRegisteredMembers'] ?? 0;
    final maxPerReg = e['maxMembersPerRegistration'] ?? 5;
    final attachments = (e['attachments'] as List?) ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: EdgeInsets.fromLTRB(AppDimensions.screenPadding, AppDimensions.lg, AppDimensions.screenPadding, 16 + bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            // Title + status
            Row(
              children: [
                Expanded(child: Text(e['title'] ?? '', style: AppTextStyles.h1)),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: AppDimensions.md),

            // Date & time
            if (startDate != null && endDate != null) ...[
              _DetailRow(
                icon: Icons.calendar_today_rounded,
                label: 'Date',
                value: '${DateFormat('EEE, MMM dd yyyy').format(startDate)} - ${DateFormat('EEE, MMM dd yyyy').format(endDate)}',
              ),
              _DetailRow(
                icon: Icons.access_time_rounded,
                label: 'Time',
                value: '${DateFormat('h:mm a').format(startDate)} - ${DateFormat('h:mm a').format(endDate)}',
              ),
            ],

            _DetailRow(icon: Icons.location_on_rounded, label: 'Location', value: e['location'] ?? ''),
            _DetailRow(icon: Icons.person_rounded, label: 'Organizer', value: e['organizerName'] ?? ''),
            _DetailRow(icon: Icons.phone_rounded, label: 'Contact', value: e['organizerContact'] ?? ''),

            // Capacity info
            const SizedBox(height: AppDimensions.md),
            AppCard(
              backgroundColor: AppColors.primarySurface,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('$registered', style: AppTextStyles.h1.copyWith(color: AppColors.primary)),
                        Text(maxReg != null ? 'of $maxReg spots' : 'Registrations', style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.primaryBorder),
                  Expanded(
                    child: Column(
                      children: [
                        Text('$totalMembers', style: AppTextStyles.h1.copyWith(color: AppColors.primary)),
                        Text('Total Members', style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.primaryBorder),
                  Expanded(
                    child: Column(
                      children: [
                        Text('$maxPerReg', style: AppTextStyles.h1.copyWith(color: AppColors.primary)),
                        Text('Max per Reg', style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Description
            if ((e['description'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: AppDimensions.lg),
              Text('Description', style: AppTextStyles.h3),
              const SizedBox(height: AppDimensions.xs),
              Text(e['description'], style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            ],

            // Rules
            if ((e['rules'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: AppDimensions.lg),
              Text('Rules & Guidelines', style: AppTextStyles.h3),
              const SizedBox(height: AppDimensions.xs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.warningBorder),
                ),
                child: Text(e['rules'], style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningText)),
              ),
            ],

            // Attachments
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.lg),
              Text('Attachments', style: AppTextStyles.h3),
              const SizedBox(height: AppDimensions.sm),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.sm),
                  itemBuilder: (_, i) {
                    final a = attachments[i];
                    final isImage = (a['fileType'] ?? '').toString().startsWith('image');
                    final url = AppConstants.uploadUrlFromPath(a['fileUrl']);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      child: isImage && url != null
                          ? Image.network(url, width: 80, height: 80, fit: BoxFit.cover)
                          : Container(
                              width: 80, height: 80,
                              color: AppColors.surfaceVariant,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.insert_drive_file_rounded, color: AppColors.textMuted),
                                  const SizedBox(height: 2),
                                  Text(
                                    a['fileName'] ?? 'File',
                                    style: AppTextStyles.caption,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: AppDimensions.xxl),

            // Action buttons
            if (canRegister && !isRegistered)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showRegisterSheet(context, ref, e),
                  icon: const Icon(Icons.how_to_reg_rounded),
                  label: const Text('Register for Event'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                  ),
                ),
              ),

            if (isRegistered) ...[
              AppCard(
                backgroundColor: AppColors.successSurface,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('You are registered!', style: AppTextStyles.labelLarge.copyWith(color: AppColors.successText)),
                          Text('${myReg['memberCount']} member(s)', style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText)),
                        ],
                      ),
                    ),
                    if (canRegister)
                      TextButton(
                        onPressed: () => _cancelReg(context, ref, e['id']),
                        child: Text('Cancel', style: AppTextStyles.labelMedium.copyWith(color: AppColors.danger)),
                      ),
                  ],
                ),
              ),
            ],

            // Admin actions
            if (_isAdmin) ...[
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRegistrationsSheet(context, ref, e['id'], e['title']),
                      icon: const Icon(Icons.list_alt_rounded, size: 18),
                      label: const Text('View Registrations'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  if (status == 'UPCOMING' || status == 'ONGOING')
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (val) => _handleAdminAction(context, ref, e['id'], val),
                      itemBuilder: (_) => [
                        if (status == 'UPCOMING')
                          const PopupMenuItem(value: 'ONGOING', child: Text('Mark as Ongoing')),
                        const PopupMenuItem(value: 'COMPLETED', child: Text('Mark as Completed')),
                        const PopupMenuItem(value: 'CANCELLED', child: Text('Cancel Event')),
                        const PopupMenuItem(value: 'DELETE', child: Text('Delete Event', style: TextStyle(color: AppColors.danger))),
                      ],
                    ),
                ],
              ),
            ],

            const SizedBox(height: AppDimensions.lg),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelReg(BuildContext context, WidgetRef ref, String eventId) async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Cancel Registration',
      message: 'Are you sure you want to cancel your registration?',
      confirmLabel: 'Yes, cancel',
    );
    if (!ok || !mounted) return;
    final err = await ref.read(eventsProvider.notifier).cancelRegistration(eventId);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Registration cancelled')),
      );
    }
  }

  Future<void> _handleAdminAction(BuildContext context, WidgetRef ref, String eventId, String action) async {
    if (action == 'DELETE') {
      final ok = await showConfirmSheet(
        context: context,
        title: 'Delete Event',
        message: 'This will permanently delete the event and all registrations.',
        confirmLabel: 'Delete',
      );
      if (!ok || !mounted) return;
      final err = await ref.read(eventsProvider.notifier).deleteEvent(eventId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Event deleted')));
      }
      return;
    }
    final err = await ref.read(eventsProvider.notifier).updateEvent(eventId, {'status': action});
    if (mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Event updated')));
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppDimensions.sm),
          SizedBox(width: 70, child: Text(label, style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted))),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

// ─── Registration Sheet ──────────────────────────────────────────────────────

void _showRegisterSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> event) {
  showAppSheet(
    context: context,
    builder: (_) => _RegisterSheet(event: event),
  );
}

class _RegisterSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;
  const _RegisterSheet({required this.event});

  @override
  ConsumerState<_RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends ConsumerState<_RegisterSheet> {
  int _memberCount = 1;
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  int get _maxPerReg => widget.event['maxMembersPerRegistration'] ?? 5;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppDimensions.screenPadding, AppDimensions.lg, AppDimensions.screenPadding, 16 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Text('Register for Event', style: AppTextStyles.h1),
          const SizedBox(height: AppDimensions.xs),
          Text(widget.event['title'] ?? '', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppDimensions.xxl),

          Text('Number of Members', style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              IconButton.filled(
                onPressed: _memberCount > 1 ? () => setState(() => _memberCount--) : null,
                icon: const Icon(Icons.remove_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primarySurface,
                  foregroundColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimensions.lg),
              Text('$_memberCount', style: AppTextStyles.amountLarge),
              const SizedBox(width: AppDimensions.lg),
              IconButton.filled(
                onPressed: _memberCount < _maxPerReg ? () => setState(() => _memberCount++) : null,
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primarySurface,
                  foregroundColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Text('max $_maxPerReg', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),

          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Any special requirements...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppDimensions.xxl),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm Registration'),
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final err = await ref.read(eventsProvider.notifier).register(
      eventId: widget.event['id'],
      memberCount: _memberCount,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Registered successfully!')),
    );
  }
}

// ─── View Registrations Sheet (Admin) ────────────────────────────────────────

void _showRegistrationsSheet(BuildContext context, WidgetRef ref, String eventId, String title) {
  showAppSheet(
    context: context,
    builder: (_) => _RegistrationsSheet(eventId: eventId, eventTitle: title),
  );
}

class _RegistrationsSheet extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;
  const _RegistrationsSheet({required this.eventId, required this.eventTitle});

  @override
  ConsumerState<_RegistrationsSheet> createState() => _RegistrationsSheetState();
}

class _RegistrationsSheetState extends ConsumerState<_RegistrationsSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await ref.read(eventsProvider.notifier).getRegistrations(widget.eventId);
    if (mounted) setState(() { _data = d; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_data == null || _data!.containsKey('_error')) {
          return Center(child: Text(_data?['_error'] ?? 'Failed to load'));
        }

        final regs = (_data!['registrations'] as List?) ?? [];
        final totalRegistered = _data!['totalRegistered'] ?? 0;
        final totalMembers = _data!['totalMembers'] ?? 0;
        final totalCancelled = _data!['totalCancelled'] ?? 0;

        return SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              Text('Registrations', style: AppTextStyles.h1),
              Text(widget.eventTitle, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppDimensions.lg),

              // Summary
              Row(
                children: [
                  _SummaryPill(label: 'Registered', value: '$totalRegistered', color: AppColors.success),
                  const SizedBox(width: AppDimensions.sm),
                  _SummaryPill(label: 'Members', value: '$totalMembers', color: AppColors.primary),
                  const SizedBox(width: AppDimensions.sm),
                  _SummaryPill(label: 'Cancelled', value: '$totalCancelled', color: AppColors.danger),
                ],
              ),
              const SizedBox(height: AppDimensions.lg),

              if (regs.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No registrations yet'),
                ))
              else
                ...regs.map((r) {
                  final user = r['user'] as Map<String, dynamic>? ?? {};
                  final regStatus = (r['status'] ?? 'REGISTERED').toString().toUpperCase();
                  final isCancelled = regStatus == 'CANCELLED';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                    child: AppCard(
                      backgroundColor: isCancelled ? AppColors.dangerSurface : null,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primarySurface,
                            child: Text(
                              (user['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                              style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user['name'] ?? 'Unknown', style: AppTextStyles.h3),
                                Text(user['phone'] ?? '', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${r['memberCount']} members', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                              if (isCancelled)
                                Text('Cancelled', style: AppTextStyles.labelSmall.copyWith(color: AppColors.danger)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.h2.copyWith(color: color)),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

// ─── Create Event Sheet ──────────────────────────────────────────────────────

void _showCreateEventSheet(BuildContext context, WidgetRef ref) {
  showAppSheet(
    context: context,
    builder: (_) => const _CreateEventSheet(),
  );
}

class _CreateEventSheet extends ConsumerStatefulWidget {
  const _CreateEventSheet();

  @override
  ConsumerState<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends ConsumerState<_CreateEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _rulesCtrl = TextEditingController();
  final _organizerNameCtrl = TextEditingController();
  final _organizerContactCtrl = TextEditingController();
  final _maxPerRegCtrl = TextEditingController(text: '5');
  final _maxTotalCtrl = TextEditingController();

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _organizerNameCtrl.text = user?.name ?? '';
    _organizerContactCtrl.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _rulesCtrl.dispose();
    _organizerNameCtrl.dispose();
    _organizerContactCtrl.dispose();
    _maxPerRegCtrl.dispose();
    _maxTotalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: scrollCtrl,
          padding: EdgeInsets.fromLTRB(AppDimensions.screenPadding, AppDimensions.lg, AppDimensions.screenPadding, 16 + bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              Text('Create Event', style: AppTextStyles.h1),
              const SizedBox(height: AppDimensions.xxl),

              _field(_titleCtrl, 'Event Name *', 'Enter event name', validator: (v) => (v == null || v.trim().length < 3) ? 'Min 3 characters' : null),
              _field(_descCtrl, 'Description', 'Describe the event...', maxLines: 3),

              // Start date/time
              Text('Start Date & Time *', style: AppTextStyles.h3),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  Expanded(child: _datePicker('Start Date', _startDate, (d) => setState(() => _startDate = d))),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(child: _timePicker('Start Time', _startTime, (t) => setState(() => _startTime = t))),
                ],
              ),
              const SizedBox(height: AppDimensions.md),

              // End date/time
              Text('End Date & Time *', style: AppTextStyles.h3),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  Expanded(child: _datePicker('End Date', _endDate, (d) => setState(() => _endDate = d))),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(child: _timePicker('End Time', _endTime, (t) => setState(() => _endTime = t))),
                ],
              ),
              const SizedBox(height: AppDimensions.md),

              _field(_locationCtrl, 'Location *', 'e.g. Community Hall, Garden Area', validator: (v) => (v == null || v.trim().length < 2) ? 'Required' : null),
              _field(_rulesCtrl, 'Rules & Guidelines', 'Any rules or guidelines for attendees...', maxLines: 3),

              Text('Organizer Details', style: AppTextStyles.h3),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  Expanded(child: _field(_organizerNameCtrl, 'Name *', '', validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(child: _field(_organizerContactCtrl, 'Contact *', '', validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)),
                ],
              ),

              Text('Registration Limits', style: AppTextStyles.h3),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  Expanded(child: _field(_maxPerRegCtrl, 'Max Members/Reg', '5', keyboardType: TextInputType.number)),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(child: _field(_maxTotalCtrl, 'Max Total Regs', 'Unlimited', keyboardType: TextInputType.number)),
                ],
              ),

              const SizedBox(height: AppDimensions.xxl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Event'),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, {int maxLines = 1, String? Function(String?)? validator, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) onPicked(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
        ),
        child: Text(
          value != null ? DateFormat('MMM dd, yyyy').format(value) : 'Select',
          style: value != null ? AppTextStyles.bodyMedium : AppTextStyles.bodyMediumMuted,
        ),
      ),
    );
  }

  Widget _timePicker(String label, TimeOfDay? value, ValueChanged<TimeOfDay> onPicked) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: value ?? TimeOfDay.now());
        if (t != null) onPicked(t);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: const Icon(Icons.access_time_rounded, size: 18),
        ),
        child: Text(
          value != null ? value.format(context) : 'Select',
          style: value != null ? AppTextStyles.bodyMedium : AppTextStyles.bodyMediumMuted,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _startTime == null || _endDate == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end date/time')),
      );
      return;
    }

    final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day, _startTime!.hour, _startTime!.minute);
    final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, _endTime!.hour, _endTime!.minute);

    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date/time must be after start')),
      );
      return;
    }

    setState(() => _submitting = true);

    final err = await ref.read(eventsProvider.notifier).createEvent(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      startDate: start,
      endDate: end,
      location: _locationCtrl.text.trim(),
      rules: _rulesCtrl.text.trim().isNotEmpty ? _rulesCtrl.text.trim() : null,
      organizerName: _organizerNameCtrl.text.trim(),
      organizerContact: _organizerContactCtrl.text.trim(),
      maxMembersPerRegistration: int.tryParse(_maxPerRegCtrl.text) ?? 5,
      maxTotalRegistrations: _maxTotalCtrl.text.trim().isNotEmpty ? int.tryParse(_maxTotalCtrl.text) : null,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (err == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }
}
