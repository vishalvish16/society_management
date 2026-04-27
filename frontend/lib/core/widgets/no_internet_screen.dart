import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_colors.dart';

class NoInternetScreen extends ConsumerWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              _WifiAnimatedIcon(isDark: isDark),
              const SizedBox(height: 40),
              Text(
                'No Internet Connection',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "It seems you're offline. Please check your Wi-Fi or mobile data and try again.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _TroubleshootTile(
                icon: Icons.wifi_rounded,
                label: 'Check Wi-Fi connection',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _TroubleshootTile(
                icon: Icons.signal_cellular_alt_rounded,
                label: 'Check mobile data',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _TroubleshootTile(
                icon: Icons.airplanemode_active_rounded,
                label: 'Turn off Airplane mode',
                isDark: isDark,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => ref.invalidate(connectivityProvider),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _TroubleshootTile extends StatelessWidget {
  const _TroubleshootTile({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFCBD5E1) : AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: isDark ? const Color(0xFF475569) : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _WifiAnimatedIcon extends StatefulWidget {
  const _WifiAnimatedIcon({required this.isDark});
  final bool isDark;

  @override
  State<_WifiAnimatedIcon> createState() => _WifiAnimatedIconState();
}

class _WifiAnimatedIconState extends State<_WifiAnimatedIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF1E293B)
              : AppColors.primarySurface,
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.isDark
                ? const Color(0xFF334155)
                : AppColors.primaryBorder,
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.wifi_off_rounded,
          size: 56,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
