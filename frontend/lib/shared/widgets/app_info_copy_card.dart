import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';

class AppInfoCopyCard extends StatelessWidget {
  final String text;
  final IconData leadingIcon;
  final String copiedMessage;
  final bool enableCopy;

  const AppInfoCopyCard({
    super.key,
    required this.text,
    this.leadingIcon = Icons.receipt_outlined,
    this.copiedMessage = 'Copied',
    this.enableCopy = true,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final messenger = ScaffoldMessenger.maybeOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(leadingIcon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          if (enableCopy)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.copy_rounded,
                  size: 14, color: AppColors.textMuted),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text(copiedMessage),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

