import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';

class SosAlertScreen extends ConsumerStatefulWidget {
  final String? unitId;
  final String? unitCode;
  final String? actorName;
  final String? actorRole;
  final String? message;
  final String? notificationId;

  const SosAlertScreen({
    super.key,
    this.unitId,
    this.unitCode,
    this.actorName,
    this.actorRole,
    this.message,
    this.notificationId,
  });

  @override
  ConsumerState<SosAlertScreen> createState() => _SosAlertScreenState();
}

class _SosAlertScreenState extends ConsumerState<SosAlertScreen> {
  bool _ackLoading = false;

  Future<void> _acknowledge() async {
    setState(() => _ackLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('sos/ack', data: {'notificationId': widget.notificationId});
    } catch (_) {
      // best-effort
    }
    if (mounted) {
      setState(() => _ackLoading = false);
      // back to home/dashboard
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = (widget.unitCode?.isNotEmpty ?? false) ? widget.unitCode! : '-';
    final actor = (widget.actorName?.isNotEmpty ?? false) ? widget.actorName! : 'Security';
    final role = (widget.actorRole?.isNotEmpty ?? false) ? widget.actorRole! : '';
    final msg = (widget.message?.trim().isNotEmpty ?? false)
        ? widget.message!.trim()
        : 'Emergency alert triggered. Please respond immediately.';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.18),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.55)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'SOS EMERGENCY',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Unit $unitLabel',
                textAlign: TextAlign.center,
                style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 34),
              ),
              const SizedBox(height: 8),
              Text(
                'Triggered by $actor${role.isNotEmpty ? ' ($role)' : ''}',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Text(
                  msg,
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _ackLoading ? null : () => context.go('/notifications'),
                      icon: const Icon(Icons.notifications_rounded),
                      label: const Text('Open Notifications'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _ackLoading ? null : _acknowledge,
                      icon: _ackLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: const Text('Acknowledge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Tip: If this is a real emergency, call security / society office immediately.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

