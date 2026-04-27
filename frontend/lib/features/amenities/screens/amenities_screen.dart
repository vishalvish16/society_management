import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../providers/amenities_provider.dart';
import '../../bills/screens/upi_pay_sheet.dart';
import '../../../core/providers/dio_provider.dart';

// ─── icon helper ──────────────────────────────────────────────────────────────
IconData _amenityIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('gym') || n.contains('fitness')) return Icons.fitness_center_rounded;
  if (n.contains('pool') || n.contains('swim')) return Icons.pool_rounded;
  if (n.contains('garden') || n.contains('park')) return Icons.park_rounded;
  if (n.contains('temple') || n.contains('mandir') || n.contains('puja')) return Icons.temple_hindu_rounded;
  if (n.contains('hall') || n.contains('community') || n.contains('banquet')) return Icons.meeting_room_rounded;
  if (n.contains('terrace') || n.contains('roof')) return Icons.roofing_rounded;
  if (n.contains('kids') || n.contains('play') || n.contains('child')) return Icons.child_care_rounded;
  if (n.contains('parking')) return Icons.local_parking_rounded;
  if (n.contains('library') || n.contains('reading')) return Icons.menu_book_rounded;
  return Icons.stadium_rounded;
}

// ─── booking type label ───────────────────────────────────────────────────────
String _bookingTypeLabel(String t) {
  switch (t) {
    case 'FREE': return 'Free Access';
    case 'SLOT': return 'Hourly Slots';
    case 'HALF_DAY': return 'Half / Full Day';
    case 'MONTHLY': return 'Monthly Pass';
    default: return t;
  }
}

Color _bookingTypeColor(String t) {
  switch (t) {
    case 'FREE': return AppColors.success;
    case 'SLOT': return AppColors.info;
    case 'HALF_DAY': return AppColors.warning;
    case 'MONTHLY': return AppColors.primary;
    default: return AppColors.textMuted;
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Main Screen
// ════════════════════════════════════════════════════════════════════════════

class AmenitiesScreen extends ConsumerWidget {
  const AmenitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.role.toUpperCase() ?? '';
    final isAdmin = isAmenityAdmin(role);
    final state = ref.watch(amenitiesProvider);
    final user = ref.watch(authProvider).user;

    if (isAdmin) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            title: const Text('Amenities'),
            bottom: TabBar(
              labelColor: AppColors.textOnPrimary,
              unselectedLabelColor: AppColors.textOnPrimary.withValues(alpha: 0.75),
              indicatorColor: AppColors.textOnPrimary,
              tabs: const [
                Tab(text: 'Amenities'),
                Tab(text: 'Pending Approvals'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAmenityForm(context, ref, null),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add_rounded, color: AppColors.textOnPrimary),
            label: Text(
              'Add Amenity',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary),
            ),
          ),
          body: TabBarView(
            children: [
              _AmenitiesTabBody(
                state: state,
                user: user,
                isAdmin: isAdmin,
                onBook: _showBookingFlow,
                onCalendar: _showCalendar,
                onEditAmenity: _showAmenityForm,
                onDeleteAmenity: (ctx, r, id) => _confirmDelete(ctx, r, id),
              ),
              const _AmenityApprovalsTab(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAmenityForm(context, ref, null),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: AppColors.textOnPrimary),
              label: Text('Add Amenity', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary)),
            )
          : null,
      body: state.isLoading
          ? const AppLoadingShimmer(itemCount: 6, itemHeight: 140)
          : state.error != null
              ? Center(child: _ErrorBox(message: state.error!,
                  onRetry: () => ref.read(amenitiesProvider.notifier).loadAmenities()))
              : state.amenities.isEmpty
                  ? const AppEmptyState(emoji: '🏊', title: 'No Amenities',
                      subtitle: 'No amenities have been added yet.')
                  : RefreshIndicator(
                      onRefresh: () => ref.read(amenitiesProvider.notifier).loadAmenities(),
                      child: CustomScrollView(
                        slivers: [
                          // My bookings strip (if user has a unit)
                          if (user?.unitId != null)
                            SliverToBoxAdapter(child: _MyBookingsStrip(unitId: user!.unitId!)),
                          SliverPadding(
                            padding: const EdgeInsets.all(AppDimensions.screenPadding),
                            sliver: SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: MediaQuery.of(context).size.width >= 600 ? 3 : 2,
                                crossAxisSpacing: AppDimensions.md,
                                mainAxisSpacing: AppDimensions.md,
                                childAspectRatio: 0.78,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _AmenityCard(
                                  amenity: state.amenities[i],
                                  isAdmin: isAdmin,
                                  user: user,
                                  onBook: () => _showBookingFlow(context, ref, state.amenities[i], user),
                                  onCalendar: () => _showCalendar(context, ref, state.amenities[i]),
                                  onEdit: () => _showAmenityForm(context, ref, state.amenities[i]),
                                  onDelete: () => _confirmDelete(context, ref, state.amenities[i]['id'] as String),
                                ),
                                childCount: state.amenities.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  // ── Admin form ──────────────────────────────────────────────────────────────
  void _showAmenityForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl))),
      builder: (_) => _AmenityFormSheet(
        existing: existing,
        onSubmit: (data) async {
          final err = existing != null
              ? await ref.read(amenitiesProvider.notifier).updateAmenity(existing['id'] as String, data)
              : await ref.read(amenitiesProvider.notifier).createAmenity(data);
          if (context.mounted) {
            Navigator.pop(context);
            _snack(context, err ?? (existing != null ? 'Amenity updated.' : 'Amenity created.'), err == null);
          }
        },
      ),
    );
  }

  // ── Booking flow dispatcher ─────────────────────────────────────────────────
  void _showBookingFlow(BuildContext context, WidgetRef ref, Map<String, dynamic> amenity, dynamic user) {
    final bookingType = amenity['bookingType'] as String? ?? 'SLOT';
    if (bookingType == 'FREE') {
      _snack(context, 'This amenity is free — no booking needed!', true);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl))),
      builder: (_) => _BookingSheet(amenity: amenity, user: user,
        onSubmit: (data) async {
          try {
            final created = await ref.read(amenitiesProvider.notifier).createBooking(data);
            if (!context.mounted) return;
            Navigator.pop(context);
            _snack(context, 'Booking submitted successfully!', true);
            ref.invalidate(myAmenityBookingsProvider);

            final billId = created?['billId'] as String?;
            if (billId != null && billId.isNotEmpty) {
              final dio = ref.read(dioProvider);
              final billRes = await dio.get('bills/$billId');
              if (billRes.data['success'] == true) {
                final bill = Map<String, dynamic>.from(billRes.data['data'] as Map);
                if (context.mounted) showPaySheet(context, bill: bill);
              }
            }
          } catch (e) {
            if (!context.mounted) return;
            Navigator.pop(context);
            _snack(context, e.toString().replaceFirst('Exception: ', ''), false);
          }
        }),
    );
  }

  // ── Availability calendar ───────────────────────────────────────────────────
  void _showCalendar(BuildContext context, WidgetRef ref, Map<String, dynamic> amenity) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AmenityCalendarScreen(amenity: amenity, notifier: ref.read(amenitiesProvider.notifier)),
    ));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showConfirmSheet(context: context, title: 'Deactivate Amenity',
        message: 'This amenity will be marked inactive. Existing bookings are not affected.',
        confirmLabel: 'Deactivate');
    if (ok && context.mounted) {
      final err = await ref.read(amenitiesProvider.notifier).deleteAmenity(id);
      if (context.mounted) _snack(context, err ?? 'Amenity deactivated.', err == null);
    }
  }

  static void _snack(BuildContext context, String msg, bool ok) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
}

class _AmenitiesTabBody extends ConsumerWidget {
  final AmenitiesState state;
  final dynamic user;
  final bool isAdmin;
  final void Function(BuildContext context, WidgetRef ref, Map<String, dynamic> amenity, dynamic user) onBook;
  final void Function(BuildContext context, WidgetRef ref, Map<String, dynamic> amenity) onCalendar;
  final void Function(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) onEditAmenity;
  final void Function(BuildContext context, WidgetRef ref, String amenityId) onDeleteAmenity;

  const _AmenitiesTabBody({
    required this.state,
    required this.user,
    required this.isAdmin,
    required this.onBook,
    required this.onCalendar,
    required this.onEditAmenity,
    required this.onDeleteAmenity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return const AppLoadingShimmer(itemCount: 6, itemHeight: 120);
    }
    if (state.error != null) {
      return Center(
        child: _ErrorBox(
          message: state.error!,
          onRetry: () => ref.read(amenitiesProvider.notifier).loadAmenities(),
        ),
      );
    }
    if (state.amenities.isEmpty) {
      return const AppEmptyState(
        emoji: '🏊',
        title: 'No Amenities',
        subtitle: 'No amenities have been added yet.',
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 1000;
    final crossAxisCount = isWide ? 4 : (MediaQuery.of(context).size.width >= 600 ? 3 : 2);
    final cardAspectRatio = crossAxisCount <= 2 ? 0.78 : (crossAxisCount == 3 ? 0.92 : 1.08);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(amenitiesProvider.notifier).loadAmenities();
      },
      child: CustomScrollView(
        slivers: [
          if (user?.unitId != null)
            SliverToBoxAdapter(child: _MyBookingsStrip(unitId: user!.unitId!)),
          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.md),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AppDimensions.md,
                mainAxisSpacing: AppDimensions.md,
                childAspectRatio: cardAspectRatio,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final a = state.amenities[i];
                  return _AmenityCard(
                    amenity: a,
                    isAdmin: isAdmin,
                    user: user,
                    onBook: () => onBook(context, ref, a, user),
                    onCalendar: () => onCalendar(context, ref, a),
                    onEdit: () => onEditAmenity(context, ref, a),
                    onDelete: () => onDeleteAmenity(context, ref, a['id'] as String),
                  );
                },
                childCount: state.amenities.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenityApprovalsTab extends ConsumerWidget {
  const _AmenityApprovalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingAmenityBookingsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (bookings) {
        final pending = bookings.whereType<Map>().map((b) => Map<String, dynamic>.from(b)).toList();

        if (pending.isEmpty) {
          return const AppEmptyState(
            emoji: '✅',
            title: 'No Pending Approvals',
            subtitle: 'All amenity bookings are already processed.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            return ref.refresh(pendingAmenityBookingsProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            itemCount: pending.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
            itemBuilder: (_, i) {
              final b = pending[i];
              final amenityName = b['amenity']?['name']?.toString() ?? 'Amenity';
              final unitCode = b['unit']?['fullCode']?.toString() ?? '-';
              final bookedBy = b['bookedBy']?['name']?.toString() ?? '';
              final phone = b['bookedBy']?['phone']?.toString() ?? '';
              final bookingDate = b['bookingDate'] != null
                  ? DateFormat('dd MMM yyyy').format(DateTime.parse(b['bookingDate']))
                  : (b['monthYear']?.toString() ?? '');
              final time = (b['startTime'] != null && b['endTime'] != null)
                  ? '${b['startTime']} - ${b['endTime']}'
                  : (b['halfDaySlot']?.toString() ?? '');
              final fee = b['feeCharged']?.toString() ?? '0';
              final payStatus = (b['paymentStatus'] as String? ?? 'UNPAID').toUpperCase();

              return AppCard(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('$amenityName · $unitCode', style: AppTextStyles.h3),
                        ),
                        AppStatusChip(status: 'pending'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Date: $bookingDate${time.isNotEmpty ? ' · $time' : ''}',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 4),
                    Text('Booked by: $bookedBy ${phone.isNotEmpty ? '($phone)' : ''}', style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Text('Fee: ₹$fee · Payment: $payStatus', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppDimensions.sm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final err = await ref.read(amenitiesProvider.notifier).updateBookingStatus(
                                b['id'] as String,
                                'CANCELLED',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(err ?? 'Booking rejected'),
                                  backgroundColor: err == null ? AppColors.success : AppColors.danger,
                                ));
                                // ignore: unused_result
                                await ref.refresh(pendingAmenityBookingsProvider.future);
                              }
                            },
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.sm),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              final err = await ref.read(amenitiesProvider.notifier).updateBookingStatus(
                                b['id'] as String,
                                'CONFIRMED',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(err ?? 'Booking approved'),
                                  backgroundColor: err == null ? AppColors.success : AppColors.danger,
                                ));
                                // ignore: unused_result
                                await ref.refresh(pendingAmenityBookingsProvider.future);
                              }
                            },
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Note: approvals require payment first.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  My Bookings horizontal strip
// ════════════════════════════════════════════════════════════════════════════

class _MyBookingsStrip extends ConsumerWidget {
  final String unitId;
  const _MyBookingsStrip({required this.unitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAmenityBookingsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, s) => const SizedBox.shrink(),
      data: (bookings) {
        final active = bookings.where((b) {
          final s = (b['status'] as String? ?? '').toUpperCase();
          return s == 'PENDING' || s == 'CONFIRMED';
        }).toList().take(8).toList();
        if (active.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.screenPadding, AppDimensions.md, AppDimensions.screenPadding, 6),
              child: Text('My Bookings', style: AppTextStyles.h3),
            ),
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
                itemCount: active.length,
                separatorBuilder: (_, i) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final b = active[i] as Map<String, dynamic>;
                  final name = b['amenity']?['name'] ?? '';
                  final status = (b['status'] as String? ?? '').toUpperCase();
                  String dateStr = '';
                  if (b['bookingDate'] != null) {
                    dateStr = DateFormat('dd MMM').format(DateTime.parse(b['bookingDate']));
                  } else if (b['monthYear'] != null) {
                    dateStr = b['monthYear'];
                  }
                  final slot = b['halfDaySlot'] != null
                      ? _halfDayLabel(b['halfDaySlot'])
                      : (b['startTime'] != null ? '${b['startTime']} - ${b['endTime']}' : '');
                  return Container(
                    width: 140,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(name, style: AppTextStyles.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        AppStatusChip(status: status.toLowerCase()),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        slot.isNotEmpty ? '$dateStr · $slot' : dateStr,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  String _halfDayLabel(String? slot) {
    switch (slot) {
      case 'FIRST_HALF': return 'First Half';
      case 'SECOND_HALF': return 'Second Half';
      case 'FULL': return 'Full Day';
      default: return slot ?? '';
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Amenity Card
// ════════════════════════════════════════════════════════════════════════════

class _AmenityCard extends StatelessWidget {
  final Map<String, dynamic> amenity;
  final bool isAdmin;
  final dynamic user;
  final VoidCallback onBook;
  final VoidCallback onCalendar;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AmenityCard({
    required this.amenity,
    required this.isAdmin,
    required this.user,
    required this.onBook,
    required this.onCalendar,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = amenity['name'] as String? ?? '-';
    final bookingType = amenity['bookingType'] as String? ?? 'SLOT';
    final isActive = (amenity['status'] as String? ?? '').toUpperCase() == 'ACTIVE';
    final isFree = bookingType == 'FREE';

    String feeStr = '';
    if (!isFree) {
      if (bookingType == 'HALF_DAY') {
        final hf = amenity['halfDayFee']?.toString() ?? '0';
        final fd = amenity['fullDayFee']?.toString() ?? '0';
        feeStr = '½ ₹$hf / Full ₹$fd';
      } else if (bookingType == 'MONTHLY') {
        feeStr = '₹${amenity['monthlyFee'] ?? 0}/mo';
      } else {
        feeStr = '₹${amenity['bookingFee'] ?? 0}/slot';
      }
    }

    final openTime = amenity['openTime'] as String? ?? '';
    final closeTime = amenity['closeTime'] as String? ?? '';
    final capacity = amenity['capacity']?.toString();

    return AppCard(
      onTap: isActive ? (isFree ? null : onBook) : null,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primarySurface : AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_amenityIcon(name), size: 20,
                  color: isActive ? AppColors.primary : AppColors.textMuted),
            ),
            const Spacer(),
            AppStatusChip(status: isActive ? 'active' : 'inactive'),
          ]),
          const SizedBox(height: AppDimensions.sm),
          Text(name, style: AppTextStyles.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),

          // Booking type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _bookingTypeColor(bookingType).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(_bookingTypeLabel(bookingType),
                style: AppTextStyles.caption.copyWith(
                    color: _bookingTypeColor(bookingType), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: AppDimensions.xs),

          if (openTime.isNotEmpty)
            _iconRow(Icons.schedule_rounded, '$openTime – $closeTime'),
          if (capacity != null)
            _iconRow(Icons.people_outline_rounded, 'Cap: $capacity'),
          if (feeStr.isNotEmpty)
            _iconRow(Icons.currency_rupee_rounded, feeStr),

          const Spacer(),

          if (isActive) ...[
            // Calendar & Book buttons
            Row(children: [
              Expanded(
                child: _OutlineBtn(
                  icon: Icons.calendar_month_rounded,
                  label: 'Availability',
                  onTap: onCalendar,
                ),
              ),
              if (!isFree) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: _FilledBtn(
                    icon: Icons.event_available_rounded,
                    label: 'Book',
                    onTap: onBook,
                  ),
                ),
              ],
            ]),
          ],

          if (isAdmin) ...[
            const SizedBox(height: AppDimensions.xs),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              GestureDetector(onTap: onEdit,
                  child: const Icon(Icons.edit_rounded, size: 15, color: AppColors.textMuted)),
              const SizedBox(width: AppDimensions.sm),
              GestureDetector(onTap: onDelete,
                  child: const Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.danger)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _iconRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(children: [
      Icon(icon, size: 11, color: AppColors.textMuted),
      const SizedBox(width: 3),
      Expanded(child: Text(text, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _OutlineBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 12, color: AppColors.primary),
        const SizedBox(width: 3),
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _FilledBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FilledBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 12, color: AppColors.textOnPrimary),
        const SizedBox(width: 3),
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textOnPrimary, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  Amenity Form Sheet (Create / Edit)
// ════════════════════════════════════════════════════════════════════════════

class _AmenityFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  const _AmenityFormSheet({this.existing, required this.onSubmit});

  @override
  State<_AmenityFormSheet> createState() => _AmenityFormSheetState();
}

class _AmenityFormSheetState extends State<_AmenityFormSheet> {
  final _nameCtrl      = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _openCtrl      = TextEditingController(text: '06:00');
  final _closeCtrl     = TextEditingController(text: '22:00');
  final _durationCtrl  = TextEditingController(text: '60');
  final _capacityCtrl  = TextEditingController();
  final _feeCtrl       = TextEditingController(text: '0');
  final _halfFeeCtrl   = TextEditingController(text: '0');
  final _fullFeeCtrl   = TextEditingController(text: '0');
  final _monthFeeCtrl  = TextEditingController(text: '0');
  final _splitCtrl     = TextEditingController(text: '13:00');
  final _maxHrsCtrl    = TextEditingController();
  final _advDaysCtrl   = TextEditingController(text: '30');
  final _rulesCtrl     = TextEditingController();

  String _bookingType = 'SLOT';
  bool _requireApproval = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text     = e['name'] ?? '';
      _descCtrl.text     = e['description'] ?? '';
      _openCtrl.text     = e['openTime'] ?? '06:00';
      _closeCtrl.text    = e['closeTime'] ?? '22:00';
      _durationCtrl.text = e['bookingDuration']?.toString() ?? '60';
      _capacityCtrl.text = e['capacity']?.toString() ?? '';
      _feeCtrl.text      = e['bookingFee']?.toString() ?? '0';
      _halfFeeCtrl.text  = e['halfDayFee']?.toString() ?? '0';
      _fullFeeCtrl.text  = e['fullDayFee']?.toString() ?? '0';
      _monthFeeCtrl.text = e['monthlyFee']?.toString() ?? '0';
      _splitCtrl.text    = e['firstHalfEnd'] ?? '13:00';
      _maxHrsCtrl.text   = e['maxDailyHours']?.toString() ?? '';
      _advDaysCtrl.text  = e['maxAdvanceDays']?.toString() ?? '30';
      _rulesCtrl.text    = e['rules'] ?? '';
      _bookingType       = e['bookingType'] ?? 'SLOT';
      _requireApproval   = e['requireApproval'] == true;
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _descCtrl, _openCtrl, _closeCtrl, _durationCtrl,
      _capacityCtrl, _feeCtrl, _halfFeeCtrl, _fullFeeCtrl, _monthFeeCtrl,
      _splitCtrl, _maxHrsCtrl, _advDaysCtrl, _rulesCtrl]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20,
          MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(isEdit ? 'Edit Amenity' : 'Add Amenity', style: AppTextStyles.h1),
          const SizedBox(height: 20),

          _label('Amenity Name *'),
          _field(_nameCtrl, 'e.g. Swimming Pool, Gym, Temple'),
          const SizedBox(height: 12),

          _label('Description'),
          _field(_descCtrl, 'Brief description...', maxLines: 2),
          const SizedBox(height: 12),

          _label('Booking Type *'),
          const SizedBox(height: 6),
          _BookingTypeSelector(
            value: _bookingType,
            onChanged: (v) => setState(() => _bookingType = v),
          ),
          const SizedBox(height: 12),

          // ── Type-specific fields ───────────────────────────────────────────
          if (_bookingType != 'FREE') ...[
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Open Time'),
                _timeField(_openCtrl, context),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Close Time'),
                _timeField(_closeCtrl, context),
              ])),
            ]),
            const SizedBox(height: 12),
          ],

          if (_bookingType == 'SLOT') ...[
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Slot Duration (mins)'),
                _field(_durationCtrl, '60', type: TextInputType.number),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Fee per Slot (₹)'),
                _field(_feeCtrl, '0', type: TextInputType.number),
              ])),
            ]),
            const SizedBox(height: 12),
          ],

          if (_bookingType == 'HALF_DAY') ...[
            _label('First-Half Ends At (split time)'),
            _timeField(_splitCtrl, context),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Half-Day Fee (₹)'),
                _field(_halfFeeCtrl, '0', type: TextInputType.number),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Full-Day Fee (₹)'),
                _field(_fullFeeCtrl, '0', type: TextInputType.number),
              ])),
            ]),
            const SizedBox(height: 12),
          ],

          if (_bookingType == 'MONTHLY') ...[
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Monthly Fee (₹)'),
                _field(_monthFeeCtrl, '0', type: TextInputType.number),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Max Daily Hours'),
                _field(_maxHrsCtrl, 'e.g. 2', type: TextInputType.number),
              ])),
            ]),
            const SizedBox(height: 12),
          ],

          // ── Common fields ──────────────────────────────────────────────────
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Capacity (persons)'),
              _field(_capacityCtrl, 'e.g. 20', type: TextInputType.number),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Max Advance Days'),
              _field(_advDaysCtrl, '30', type: TextInputType.number),
            ])),
          ]),
          const SizedBox(height: 12),

          _label('Rules / Notes'),
          _field(_rulesCtrl, 'Any usage rules...', maxLines: 2),
          const SizedBox(height: 12),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('Require Admin Approval', style: AppTextStyles.labelLarge),
            subtitle: Text('Bookings need approval before confirmed', style: AppTextStyles.caption),
            value: _requireApproval,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryLight,
            onChanged: (v) => setState(() => _requireApproval = v),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary))
                  : Text(isEdit ? 'Update Amenity' : 'Create Amenity', style: AppTextStyles.buttonLarge),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(t, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
  );

  Widget _field(TextEditingController ctrl, String hint,
      {int maxLines = 1, TextInputType type = TextInputType.text}) =>
      TextField(
        controller: ctrl, maxLines: maxLines, keyboardType: type,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
          filled: true, fillColor: AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary)),
        ),
      );

  Widget _timeField(TextEditingController ctrl, BuildContext context) =>
      GestureDetector(
        onTap: () async {
          final parts = ctrl.text.split(':');
          final init = TimeOfDay(
            hour: int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0,
            minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
          );
          final picked = await showTimePicker(context: context, initialTime: init,
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
              child: child!,
            ));
          if (picked != null) {
            ctrl.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          }
        },
        child: AbsorbPointer(child: _field(ctrl, 'HH:MM')),
      );

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amenity name is required'), backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _submitting = true);
    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'bookingType': _bookingType,
      'openTime': _openCtrl.text.trim(),
      'closeTime': _closeCtrl.text.trim(),
      'bookingDuration': int.tryParse(_durationCtrl.text.trim()) ?? 60,
      'capacity': _capacityCtrl.text.trim().isEmpty ? null : int.tryParse(_capacityCtrl.text.trim()),
      'bookingFee': double.tryParse(_feeCtrl.text.trim()) ?? 0,
      'halfDayFee': double.tryParse(_halfFeeCtrl.text.trim()) ?? 0,
      'fullDayFee': double.tryParse(_fullFeeCtrl.text.trim()) ?? 0,
      'monthlyFee': double.tryParse(_monthFeeCtrl.text.trim()) ?? 0,
      'firstHalfEnd': _splitCtrl.text.trim().isEmpty ? null : _splitCtrl.text.trim(),
      'maxDailyHours': _maxHrsCtrl.text.trim().isEmpty ? null : int.tryParse(_maxHrsCtrl.text.trim()),
      'maxAdvanceDays': int.tryParse(_advDaysCtrl.text.trim()) ?? 30,
      'rules': _rulesCtrl.text.trim().isEmpty ? null : _rulesCtrl.text.trim(),
      'requireApproval': _requireApproval,
    };
    await widget.onSubmit(data);
    if (mounted) setState(() => _submitting = false);
  }
}

// Booking-type selector pills
class _BookingTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _BookingTypeSelector({required this.value, required this.onChanged});

  static const _types = [
    ('FREE', 'Free Access', Icons.lock_open_rounded),
    ('SLOT', 'Hourly Slots', Icons.timer_rounded),
    ('HALF_DAY', 'Half/Full Day', Icons.wb_sunny_rounded),
    ('MONTHLY', 'Monthly Pass', Icons.calendar_month_rounded),
  ];

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: _types.map((t) {
    final selected = value == t.$1;
    return GestureDetector(
      onTap: () => onChanged(t.$1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(t.$3, size: 13, color: selected ? AppColors.textOnPrimary : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(t.$2, style: AppTextStyles.labelMedium.copyWith(
              color: selected ? AppColors.textOnPrimary : AppColors.textSecondary)),
        ]),
      ),
    );
  }).toList());
}

// ════════════════════════════════════════════════════════════════════════════
//  Booking Sheet (Smart — adapts to booking type)
// ════════════════════════════════════════════════════════════════════════════

class _BookingSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> amenity;
  final dynamic user;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  const _BookingSheet({required this.amenity, required this.user, required this.onSubmit});

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  DateTime? _selectedDate;
  String? _selectedSlotStart;
  String? _selectedSlotEnd;
  String? _selectedHalfDay;
  String? _monthYear;
  int? _dailyHours;
  final _purposeCtrl = TextEditingController();
  bool _loadingSlots = false;
  List<Map<String, dynamic>> _slots = [];
  bool _submitting = false;

  String get _bookingType => widget.amenity['bookingType'] as String? ?? 'SLOT';

  @override
  void dispose() {
    _purposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSlots(DateTime date) async {
    setState(() { _loadingSlots = true; _slots = []; _selectedSlotStart = null; _selectedHalfDay = null; });
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final data = await ref.read(amenitiesProvider.notifier).fetchSlots(widget.amenity['id'], dateStr);
    if (mounted) {
      setState(() {
        _loadingSlots = false;
        _slots = data != null
            ? List<Map<String, dynamic>>.from((data['slots'] as List?) ?? [])
            : [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.amenity['name'] as String? ?? 'Amenity';
    final type = _bookingType;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Icon(_amenityIcon(name), color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('Book $name', style: AppTextStyles.h1)),
          ]),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _bookingTypeColor(type).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(_bookingTypeLabel(type),
                style: AppTextStyles.caption.copyWith(color: _bookingTypeColor(type), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 20),

          // ── MONTHLY ────────────────────────────────────────────────────────
          if (type == 'MONTHLY') ...[
            Text('Select Month', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            _MonthYearPicker(
              value: _monthYear,
              onChanged: (v) => setState(() => _monthYear = v),
            ),
            const SizedBox(height: 12),
            if (widget.amenity['maxDailyHours'] != null) ...[
              Text('Daily Hours Limit (max ${widget.amenity['maxDailyHours']}h)',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _HoursStepper(
                value: _dailyHours ?? 1,
                max: (widget.amenity['maxDailyHours'] as num).toInt(),
                onChanged: (v) => setState(() => _dailyHours = v),
              ),
            ],
          ],

          // ── SLOT / HALF_DAY — Date picker ──────────────────────────────────
          if (type != 'MONTHLY') ...[
            Text('Select Date', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            _DatePickerRow(
              selected: _selectedDate,
              maxDays: (widget.amenity['maxAdvanceDays'] as num?)?.toInt() ?? 30,
              onPick: (d) {
                setState(() { _selectedDate = d; _selectedSlotStart = null; _selectedHalfDay = null; });
                _loadSlots(d);
              },
            ),
            const SizedBox(height: 16),
          ],

          // ── HALF_DAY slot chips ────────────────────────────────────────────
          if (type == 'HALF_DAY' && _selectedDate != null) ...[
            Text('Select Slot', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            _loadingSlots
                ? const Center(child: CircularProgressIndicator())
                : _HalfDaySlotPicker(
                    slots: _slots,
                    selected: _selectedHalfDay,
                    onSelected: (k) => setState(() => _selectedHalfDay = k),
                  ),
            const SizedBox(height: 12),
          ],

          // ── SLOT time chips ───────────────────────────────────────────────
          if (type == 'SLOT' && _selectedDate != null) ...[
            Text('Select Time Slot', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            _loadingSlots
                ? const Center(child: CircularProgressIndicator())
                : _SlotChips(
                    slots: _slots,
                    selected: _selectedSlotStart,
                    onSelected: (start, end) => setState(() {
                      _selectedSlotStart = start;
                      _selectedSlotEnd = end;
                    }),
                  ),
            const SizedBox(height: 12),
          ],

          // Fee display
          _FeePreview(amenity: widget.amenity, type: type, halfDaySlot: _selectedHalfDay),
          const SizedBox(height: 12),

          Text('Purpose (optional)', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _purposeCtrl,
            maxLines: 2,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'What will you use it for?',
              hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary))
                  : Text('Confirm Booking', style: AppTextStyles.buttonLarge),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _submit() async {
    final user = widget.user;
    final unitId = user?.unitId as String?;
    if (unitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No unit assigned to your account'), backgroundColor: AppColors.danger));
      return;
    }

    Map<String, dynamic> data = {
      'amenityId': widget.amenity['id'],
      'unitId': unitId,
      'purpose': _purposeCtrl.text.trim().isEmpty ? null : _purposeCtrl.text.trim(),
    };

    if (_bookingType == 'MONTHLY') {
      if (_monthYear == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please select a month'), backgroundColor: AppColors.warning));
        return;
      }
      data['monthYear'] = _monthYear;
      if (_dailyHours != null) data['dailyHoursLimit'] = _dailyHours;
    } else if (_bookingType == 'HALF_DAY') {
      if (_selectedDate == null || _selectedHalfDay == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please select a date and slot'), backgroundColor: AppColors.warning));
        return;
      }
      data['bookingDate'] = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      data['halfDaySlot'] = _selectedHalfDay;
    } else {
      if (_selectedDate == null || _selectedSlotStart == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please select a date and time slot'), backgroundColor: AppColors.warning));
        return;
      }
      data['bookingDate'] = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      data['startTime'] = _selectedSlotStart;
      data['endTime'] = _selectedSlotEnd;
    }

    setState(() => _submitting = true);
    await widget.onSubmit(data);
    if (mounted) setState(() => _submitting = false);
  }
}

// ── Booking sub-widgets ───────────────────────────────────────────────────────

class _DatePickerRow extends StatelessWidget {
  final DateTime? selected;
  final int maxDays;
  final ValueChanged<DateTime> onPick;
  const _DatePickerRow({this.selected, required this.maxDays, required this.onPick});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: now.add(Duration(days: maxDays)),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
          child: child!,
        ),
      );
      if (picked != null) onPick(picked);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected != null ? AppColors.primary : AppColors.border),
      ),
      child: Row(children: [
        Icon(Icons.calendar_today_rounded, size: 16,
            color: selected != null ? AppColors.primary : AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          selected != null ? DateFormat('EEEE, dd MMM yyyy').format(selected!) : 'Tap to select date',
          style: AppTextStyles.bodyMedium.copyWith(
              color: selected != null ? AppColors.textPrimary : AppColors.textMuted),
        ),
      ]),
    ),
  );
}

class _MonthYearPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  const _MonthYearPicker({this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(12, (i) {
      final d = DateTime(now.year, now.month + i, 1);
      return ('${d.year}-${d.month.toString().padLeft(2, '0')}',
          DateFormat('MMMM yyyy').format(d));
    });
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        filled: true, fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
      ),
      hint: Text('Select month', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
      items: months.map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2, style: AppTextStyles.bodyMedium))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}

class _HoursStepper extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  const _HoursStepper({required this.value, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    IconButton(onPressed: value > 1 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.primary)),
    Text('$value hr${value > 1 ? 's' : ''}', style: AppTextStyles.h3),
    IconButton(onPressed: value < max ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary)),
    Text('/ day  (max ${max}h)', style: AppTextStyles.caption),
  ]);
}

class _HalfDaySlotPicker extends StatelessWidget {
  final List<Map<String, dynamic>> slots;
  final String? selected;
  final ValueChanged<String> onSelected;
  const _HalfDaySlotPicker({required this.slots, this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return Text('No slots available', style: AppTextStyles.caption);
    return Column(children: slots.map((s) {
      final key = s['key'] as String;
      final label = s['label'] as String;
      final start = s['startTime'] as String;
      final end = s['endTime'] as String;
      final fee = s['fee'] as num? ?? 0;
      final avail = s['available'] as bool? ?? false;
      final isSel = selected == key;

      return GestureDetector(
        onTap: avail ? () => onSelected(key) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: !avail ? AppColors.background : isSel ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSel ? AppColors.primary : AppColors.border),
          ),
          child: Row(children: [
            Icon(key == 'FULL' ? Icons.wb_sunny_rounded : Icons.wb_twilight_rounded,
                size: 16, color: !avail ? AppColors.textMuted : isSel ? AppColors.textOnPrimary : AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTextStyles.labelLarge.copyWith(
                  color: !avail ? AppColors.textMuted : isSel ? AppColors.textOnPrimary : AppColors.textPrimary)),
              Text('$start – $end', style: AppTextStyles.caption.copyWith(
                  color: !avail ? AppColors.textMuted : isSel ? AppColors.textOnPrimary.withValues(alpha: 0.7) : AppColors.textSecondary)),
            ])),
            if (!avail)
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.dangerSurface, borderRadius: BorderRadius.circular(4)),
                  child: Text('Booked', style: AppTextStyles.caption.copyWith(color: AppColors.dangerText)))
            else
              Text('₹${fee.toStringAsFixed(0)}', style: AppTextStyles.labelLarge.copyWith(
                  color: isSel ? AppColors.textOnPrimary : AppColors.primary)),
          ]),
        ),
      );
    }).toList());
  }
}

class _SlotChips extends StatelessWidget {
  final List<Map<String, dynamic>> slots;
  final String? selected;
  final void Function(String start, String end) onSelected;
  const _SlotChips({required this.slots, this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return Text('No slots available for this date', style: AppTextStyles.caption);
    return Wrap(spacing: 8, runSpacing: 8, children: slots.map((s) {
      final start = s['startTime'] as String;
      final end = s['endTime'] as String;
      final avail = s['available'] as bool? ?? false;
      final fee = s['fee'] as num? ?? 0;
      final isSel = selected == start;
      return GestureDetector(
        onTap: avail ? () => onSelected(start, end) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: !avail ? AppColors.background : isSel ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: !avail ? AppColors.border : isSel ? AppColors.primary : AppColors.border),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(start, style: AppTextStyles.labelMedium.copyWith(
                color: !avail ? AppColors.textMuted : isSel ? AppColors.textOnPrimary : AppColors.textPrimary)),
            Text('${fee.toStringAsFixed(0)}₹', style: AppTextStyles.caption.copyWith(
                color: !avail ? AppColors.textMuted : isSel ? AppColors.textOnPrimary.withValues(alpha: 0.8) : AppColors.textSecondary)),
            if (!avail)
              Container(margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.dangerSurface, borderRadius: BorderRadius.circular(3)),
                  child: Text('Full', style: AppTextStyles.caption.copyWith(color: AppColors.dangerText, fontSize: 8))),
          ]),
        ),
      );
    }).toList());
  }
}

class _FeePreview extends StatelessWidget {
  final Map<String, dynamic> amenity;
  final String type;
  final String? halfDaySlot;
  const _FeePreview({required this.amenity, required this.type, this.halfDaySlot});

  @override
  Widget build(BuildContext context) {
    double fee = 0;
    String label = '';
    if (type == 'SLOT') {
      fee = double.tryParse(amenity['bookingFee']?.toString() ?? '0') ?? 0;
      label = 'per slot';
    } else if (type == 'HALF_DAY') {
      if (halfDaySlot == 'FULL') {
        fee = double.tryParse(amenity['fullDayFee']?.toString() ?? '0') ?? 0;
        label = 'full day';
      } else if (halfDaySlot != null) {
        fee = double.tryParse(amenity['halfDayFee']?.toString() ?? '0') ?? 0;
        label = 'half day';
      } else {
        return const SizedBox.shrink();
      }
    } else if (type == 'MONTHLY') {
      fee = double.tryParse(amenity['monthlyFee']?.toString() ?? '0') ?? 0;
      label = 'per month';
    }
    if (fee == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const Icon(Icons.currency_rupee_rounded, size: 16, color: AppColors.primary),
        Text('${fee.toStringAsFixed(0)} $label',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
        const Spacer(),
        Text('Booking fee', style: AppTextStyles.caption),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Availability Calendar Screen
// ════════════════════════════════════════════════════════════════════════════

class AmenityCalendarScreen extends StatefulWidget {
  final Map<String, dynamic> amenity;
  final AmenitiesNotifier notifier;
  const AmenityCalendarScreen({super.key, required this.amenity, required this.notifier});

  @override
  State<AmenityCalendarScreen> createState() => _AmenityCalendarScreenState();
}

class _AmenityCalendarScreenState extends State<AmenityCalendarScreen> {
  late DateTime _focusedMonth;
  Map<String, dynamic>? _calendarData;
  bool _loading = true;
  String? _selectedDate;
  List<Map<String, dynamic>> _daySlots = [];
  bool _loadingSlots = false;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadCalendar();
  }

  String get _monthKey =>
      '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}';

  Future<void> _loadCalendar() async {
    setState(() { _loading = true; _calendarData = null; });
    final data = await widget.notifier.fetchCalendar(widget.amenity['id'], _monthKey);
    if (mounted) setState(() { _loading = false; _calendarData = data; });
  }

  Future<void> _loadDaySlots(String date) async {
    setState(() { _selectedDate = date; _loadingSlots = true; _daySlots = []; });
    final data = await widget.notifier.fetchSlots(widget.amenity['id'], date);
    if (mounted) {
      setState(() {
        _loadingSlots = false;
        _daySlots = data != null
            ? List<Map<String, dynamic>>.from((data['slots'] as List?) ?? [])
            : [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.amenity['name'] as String? ?? 'Amenity';
    final bookingType = widget.amenity['bookingType'] as String? ?? 'SLOT';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$name — Availability'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Column(children: [
        // Month navigator
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () {
                setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1));
                _loadCalendar();
              },
            ),
            Expanded(child: Text(DateFormat('MMMM yyyy').format(_focusedMonth),
                textAlign: TextAlign.center, style: AppTextStyles.h2)),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () {
                setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1));
                _loadCalendar();
              },
            ),
          ]),
        ),

        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _LegendDot(color: AppColors.success, label: 'Available'),
            const SizedBox(width: 16),
            _LegendDot(color: AppColors.warning, label: 'Partial'),
            const SizedBox(width: 16),
            _LegendDot(color: AppColors.danger, label: 'Full'),
          ]),
        ),

        // Calendar grid
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (bookingType == 'FREE')
          Expanded(child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_open_rounded, size: 48, color: AppColors.success),
              const SizedBox(height: 12),
              Text('Free Access — No booking needed', style: AppTextStyles.h3),
              const SizedBox(height: 4),
              Text('This amenity is open to all residents anytime.',
                  style: AppTextStyles.caption),
            ]),
          ))
        else
          Expanded(child: Column(children: [
            // Day-of-week headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
                  .map((d) => Expanded(child: Center(child: Text(d,
                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)))))
                  .toList()),
            ),
            const SizedBox(height: 4),
            Expanded(child: _CalendarGrid(
              month: _focusedMonth,
              days: _calendarData?['days'] as List? ?? [],
              selectedDate: _selectedDate,
              onDayTap: _loadDaySlots,
            )),

            // Day slot detail
            if (_selectedDate != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(DateFormat('EEEE, dd MMM yyyy').format(DateTime.parse(_selectedDate!)),
                      style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  _loadingSlots
                      ? const Center(child: SizedBox(height: 24, width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                      : _DaySlotDetail(slots: _daySlots, bookingType: bookingType),
                ]),
              ),
            ],
          ])),
      ]),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final List days;
  final String? selectedDate;
  final ValueChanged<String> onDayTap;
  const _CalendarGrid({required this.month, required this.days,
      this.selectedDate, required this.onDayTap});

  @override
  Widget build(BuildContext context) {
    final statusMap = <String, String>{};
    for (final d in days) {
      statusMap[d['date'] as String] = d['status'] as String? ?? 'available';
    }

    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final startOffset = firstDay.weekday % 7; // Sunday=0

    final cells = <Widget>[];
    for (int i = 0; i < startOffset; i++) { cells.add(const SizedBox.shrink()); }
    for (int d = 1; d <= daysInMonth; d++) {
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final status = statusMap[key] ?? 'available';
      final isSel = selectedDate == key;
      final isPast = DateTime(month.year, month.month, d).isBefore(
          DateTime.now().subtract(const Duration(days: 1)));

      Color bg;
      Color textColor;
      if (isSel) {
        bg = AppColors.primary;
        textColor = AppColors.textOnPrimary;
      } else if (isPast) {
        bg = AppColors.background;
        textColor = AppColors.textMuted;
      } else {
        bg = status == 'full' ? AppColors.dangerSurface
            : status == 'partial' ? AppColors.warningSurface
            : AppColors.successSurface;
        textColor = status == 'full' ? AppColors.dangerText
            : status == 'partial' ? AppColors.warningText
            : AppColors.successText;
      }

      cells.add(GestureDetector(
        onTap: isPast ? null : () => onDayTap(key),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8),
              border: isSel ? Border.all(color: AppColors.primary, width: 2) : null),
          child: Center(child: Text('$d',
              style: AppTextStyles.labelMedium.copyWith(color: textColor))),
        ),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: cells,
    );
  }
}

class _DaySlotDetail extends StatelessWidget {
  final List<Map<String, dynamic>> slots;
  final String bookingType;
  const _DaySlotDetail({required this.slots, required this.bookingType});

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return Text('No slot data available', style: AppTextStyles.caption);
    final avail = slots.where((s) => s['available'] == true).length;
    final total = slots.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$avail of $total slots available', style: AppTextStyles.bodySmall
          .copyWith(color: avail > 0 ? AppColors.successText : AppColors.dangerText)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: slots.map((s) {
        final avail = s['available'] as bool? ?? false;
        final label = bookingType == 'HALF_DAY'
            ? (s['label'] as String? ?? s['key'] as String? ?? '')
            : (s['startTime'] as String? ?? '');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: avail ? AppColors.successSurface : AppColors.dangerSurface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label, style: AppTextStyles.caption.copyWith(
              color: avail ? AppColors.successText : AppColors.dangerText)),
        );
      }).toList()),
    ]);
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 4),
    Text(label, style: AppTextStyles.caption),
  ]);
}

// ── Misc ──────────────────────────────────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppDimensions.screenPadding),
    child: AppCard(
      backgroundColor: AppColors.dangerSurface,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Error: $message', style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    ),
  );
}
