import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Compact single-date picker field + dialog helper
// ─────────────────────────────────────────────────────────────────────────────

/// Tap-to-pick single date field styled to match app forms.
class AppDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool required;
  final bool clearable;
  final VoidCallback? onClear;

  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.required = false,
    this.clearable = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd MMM yyyy');
    final hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(
            color: hasValue ? AppColors.primary : scheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 18,
                color: hasValue ? AppColors.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$label${required ? ' *' : ''}',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: hasValue ? AppColors.primary : scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? fmt.format(value!) : 'Select date',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: hasValue ? scheme.onSurface : scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (clearable && hasValue)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 18, color: scheme.onSurfaceVariant),
              )
            else
              Icon(Icons.expand_more_rounded, size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Shows a compact dialog-mode date picker (not full-screen).
Future<DateTime?> pickSingleDate(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: firstDate ?? DateTime(2020),
    lastDate: lastDate ?? DateTime(2100),
    initialEntryMode: DatePickerEntryMode.calendarOnly,
    builder: (ctx, child) => Theme(
      data: _pickerTheme(Theme.of(ctx)),
      child: child!,
    ),
  );
}

ThemeData _pickerTheme(ThemeData base) {
  final scheme = base.colorScheme;
  return base.copyWith(
    colorScheme: scheme.copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.textOnPrimary,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact date-range picker field + dialog helper
// ─────────────────────────────────────────────────────────────────────────────

/// Tap-to-pick date range field showing "Start → End" in one row.
class AppDateRangeField extends StatelessWidget {
  final String label;
  final DateTime? from;
  final DateTime? to;
  final VoidCallback onTap;
  final bool clearable;
  final VoidCallback? onClear;

  const AppDateRangeField({
    super.key,
    required this.label,
    required this.from,
    required this.to,
    required this.onTap,
    this.clearable = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd MMM yyyy');
    final hasValue = from != null && to != null;
    final display = hasValue
        ? '${fmt.format(from!)}  →  ${fmt.format(to!)}'
        : 'Select date range';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(
            color: hasValue ? AppColors.primary : scheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range_rounded,
                size: 18,
                color: hasValue ? AppColors.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: AppTextStyles.labelSmall.copyWith(
                          color: hasValue ? AppColors.primary : scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(display,
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: hasValue ? scheme.onSurface : scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (clearable && hasValue)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 18, color: scheme.onSurfaceVariant),
              )
            else
              Icon(Icons.expand_more_rounded, size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Shows a compact inline date range picker inside a bottom-sheet style dialog.
/// Much better UX than the full-screen Material date range picker.
Future<DateTimeRange?> pickDateRange(
  BuildContext context, {
  DateTime? initialFrom,
  DateTime? initialTo,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  DateTime? from = initialFrom;
  DateTime? to = initialTo;
  final result = await showDialog<DateTimeRange>(
    context: context,
    barrierColor: Colors.black45,
    builder: (ctx) => _CompactRangePickerDialog(
      initialFrom: from,
      initialTo: to,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2100),
    ),
  );
  return result;
}

class _CompactRangePickerDialog extends StatefulWidget {
  final DateTime? initialFrom;
  final DateTime? initialTo;
  final DateTime firstDate;
  final DateTime lastDate;

  const _CompactRangePickerDialog({
    this.initialFrom,
    this.initialTo,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_CompactRangePickerDialog> createState() => _CompactRangePickerDialogState();
}

class _CompactRangePickerDialogState extends State<_CompactRangePickerDialog> {
  late DateTime _viewMonth;
  DateTime? _from;
  DateTime? _to;
  bool _pickingFrom = true; // first tap = from, second = to

  final _monthFmt = DateFormat('MMMM yyyy');
  final _dayFmt = DateFormat('d');

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
    _viewMonth = DateTime(
      (widget.initialFrom ?? DateTime.now()).year,
      (widget.initialFrom ?? DateTime.now()).month,
    );
  }

  void _prevMonth() => setState(() =>
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1));

  void _nextMonth() => setState(() =>
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1));

  void _onDayTap(DateTime day) {
    setState(() {
      if (_pickingFrom) {
        _from = day;
        _to = null;
        _pickingFrom = false;
      } else {
        if (day.isBefore(_from!)) {
          _to = _from;
          _from = day;
        } else {
          _to = day;
        }
        _pickingFrom = true;
      }
    });
  }

  bool _isSelected(DateTime day) =>
      (_from != null && _isSameDay(day, _from!)) ||
      (_to != null && _isSameDay(day, _to!));

  bool _isInRange(DateTime day) =>
      _from != null &&
      _to != null &&
      day.isAfter(_from!) &&
      day.isBefore(_to!);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime day) => _isSameDay(day, DateTime.now());

  bool _isDisabled(DateTime day) =>
      day.isBefore(widget.firstDate) || day.isAfter(widget.lastDate);

  List<DateTime?> _buildCalendarDays() {
    final first = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final last = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
    final startPad = first.weekday % 7; // Sun=0
    final days = <DateTime?>[];
    for (var i = 0; i < startPad; i++) { days.add(null); }
    for (var d = 1; d <= last.day; d++) {
      days.add(DateTime(_viewMonth.year, _viewMonth.month, d));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = _buildCalendarDays();
    final fmt = DateFormat('dd MMM yyyy');
    final fromLabel = _from != null ? fmt.format(_from!) : '—';
    final toLabel = _to != null ? fmt.format(_to!) : '—';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('Select Date Range',
                    style: AppTextStyles.h2.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Selected range display ───────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _RangeLabel(
                      label: 'From',
                      value: fromLabel,
                      active: _pickingFrom,
                    ),
                  ),
                  Container(width: 1, height: 32, color: scheme.outlineVariant),
                  Expanded(
                    child: _RangeLabel(
                      label: 'To',
                      value: toLabel,
                      active: !_pickingFrom && _from != null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Month navigation ─────────────────────────────────────
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _prevMonth,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Expanded(
                  child: Text(_monthFmt.format(_viewMonth),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelLarge.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _nextMonth,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),

            // ── Day-of-week headers ──────────────────────────────────
            Row(
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((h) => Expanded(
                        child: Center(
                          child: Text(h,
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: scheme.onSurfaceVariant)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),

            // ── Calendar grid ────────────────────────────────────────
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 36,
                mainAxisSpacing: 2,
                crossAxisSpacing: 0,
              ),
              itemCount: days.length,
              itemBuilder: (_, i) {
                final day = days[i];
                if (day == null) return const SizedBox();
                final disabled = _isDisabled(day);
                final selected = _isSelected(day);
                final inRange = _isInRange(day);
                final today = _isToday(day);

                Color bg = Colors.transparent;
                Color textColor = scheme.onSurface;
                if (selected) {
                  bg = AppColors.primary;
                  textColor = Colors.white;
                } else if (inRange) {
                  bg = scheme.primary.withValues(alpha: 0.12);
                  textColor = AppColors.primary;
                } else if (disabled) {
                  textColor = scheme.onSurfaceVariant.withValues(alpha: 0.45);
                }

                return GestureDetector(
                  onTap: disabled ? null : () => _onDayTap(day),
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: bg,
                      shape: selected ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: selected ? null : BorderRadius.circular(6),
                      border: today && !selected
                          ? Border.all(color: AppColors.primary, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        _dayFmt.format(day),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                          color: disabled
                              ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
                              : textColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Action buttons ───────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      side: BorderSide(color: scheme.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (_from != null && _to != null)
                        ? () => Navigator.pop(
                            context, DateTimeRange(start: _from!, end: _to!))
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _RangeLabel extends StatelessWidget {
  final String label;
  final String value;
  final bool active;
  const _RangeLabel({required this.label, required this.value, required this.active});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.labelSmall.copyWith(
                  color: active ? AppColors.primary : scheme.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: AppTextStyles.bodySmall.copyWith(
                  color: active ? AppColors.primary : scheme.onSurface,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }
}
