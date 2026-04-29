import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';

/// A searchable unit picker that shows a dropdown list of units
/// (fetched from /units) and returns the selected unit's id + fullCode.
///
/// When [readOnly] is true the widget renders as a non-interactive display
/// field showing the pre-filled unit with a lock icon. No dropdown is shown.
///
/// Usage:
///   UnitPickerField(
///     selectedUnitId: _selectedUnitId,
///     selectedUnitCode: _selectedUnitCode,
///     onChanged: (id, code) => setState(() { _selectedUnitId = id; _selectedUnitCode = code; }),
///     readOnly: true,   // lock the field for member-role users
///   )
class UnitPickerField extends ConsumerStatefulWidget {
  final String? selectedUnitId;
  final String? selectedUnitCode;
  final void Function(String id, String fullCode) onChanged;
  final String label;
  /// When true, renders a locked read-only display instead of the picker.
  final bool readOnly;

  const UnitPickerField({
    super.key,
    required this.onChanged,
    this.selectedUnitId,
    this.selectedUnitCode,
    this.label = 'Unit *',
    this.readOnly = false,
  });

  @override
  ConsumerState<UnitPickerField> createState() => _UnitPickerFieldState();
}

class _UnitPickerFieldState extends ConsumerState<UnitPickerField> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _units = [];
  bool _loading = false;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _fetchUnits();
    if (widget.selectedUnitCode != null) {
      _searchCtrl.text = widget.selectedUnitCode!;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUnits() async {
    setState(() => _loading = true);
    try {
      final res = await DioClient().dio.get('/units', queryParameters: {'limit': 200});
      final data = res.data['data'];
      setState(() {
        _units = List<Map<String, dynamic>>.from(data['units'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _units;
    return _units.where((u) =>
      (u['fullCode'] as String? ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // ── Read-only mode: locked display for member-role users ──────────────────
    if (widget.readOnly) {
      final code = widget.selectedUnitCode ?? 'No unit assigned';
      final hasUnit = widget.selectedUnitId != null;
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: hasUnit ? AppColors.primary.withValues(alpha: 0.5) : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: AppTextStyles.caption
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    code,
                    style: hasUnit
                        ? AppTextStyles.bodyMedium
                        : AppTextStyles.bodyMedium
                            .copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.lock_outline_rounded,
              color: hasUnit
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : scheme.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      );
    }

    // ── Interactive picker ────────────────────────────────────────────────────
    final isSelected = widget.selectedUnitId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(
                color: isSelected ? AppColors.primary : scheme.outlineVariant,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isSelected
                        ? widget.selectedUnitCode ?? 'Unit selected'
                        : widget.label,
                    style: isSelected
                        ? AppTextStyles.bodyMedium.copyWith(color: scheme.onSurface)
                        : AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(
                    _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: scheme.onSurfaceVariant,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search unit (e.g. A-101)',
                      hintStyle: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                      prefixIcon: Icon(Icons.search, size: 18, color: scheme.onSurfaceVariant),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: scheme.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: scheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: _filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(AppDimensions.md),
                          child: Text('No units found',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: scheme.onSurfaceVariant)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final u = _filtered[i];
                            final id = u['id'] as String;
                            final code = u['fullCode'] as String? ?? id;
                            final isSelected = id == widget.selectedUnitId;
                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor: AppColors.primary.withValues(alpha: 0.12),
                              title: Text(code,
                                  style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurface)),
                              subtitle: u['wing'] != null
                                  ? Text('Wing ${u['wing']} • Floor ${u['floor'] ?? '-'}',
                                      style: AppTextStyles.caption.copyWith(color: scheme.onSurfaceVariant))
                                  : null,
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded,
                                      color: AppColors.primary, size: 18)
                                  : null,
                              onTap: () {
                                widget.onChanged(id, code);
                                _searchCtrl.text = code;
                                setState(() => _open = false);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
