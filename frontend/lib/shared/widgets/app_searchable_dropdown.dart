import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';

class AppDropdownItem<T> {
  final T value;
  final String label;
  const AppDropdownItem({required this.value, required this.label});

  @override
  bool operator ==(Object other) =>
      other is AppDropdownItem<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class AppSearchableDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final bool enabled;

  const AppSearchableDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedItem =
        items.where((i) => i.value == value).firstOrNull;

    return DropdownSearch<AppDropdownItem<T>>(
      selectedItem: selectedItem,
      items: (filter, _) => items
          .where((i) =>
              filter.isEmpty ||
              i.label.toLowerCase().contains(filter.toLowerCase()))
          .toList(),
      itemAsString: (item) => item.label,
      compareFn: (a, b) => a.value == b.value,
      onSelected: (item) => onChanged(item?.value),
      enabled: enabled,
      decoratorProps: DropDownDecoratorProps(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint ?? 'Select...',
          labelStyle: AppTextStyles.bodyMedium.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: AppDimensions.md,
          ),
        ),
      ),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: 'Search...',
            prefixIcon: Icon(Icons.search, size: 18, color: scheme.onSurfaceVariant),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: AppDimensions.sm),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
          ),
        ),
        menuProps: MenuProps(
          elevation: 4,
          backgroundColor: scheme.surface,
        ),
        itemBuilder: (ctx, item, isDisabled, isSelected) => ListTile(
          dense: true,
          title: Text(item.label,
              style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurface)),
          selected: isSelected,
          selectedColor: AppColors.primary,
          selectedTileColor: AppColors.primary.withValues(alpha: 0.12),
          trailing: isSelected
              ? const Icon(Icons.check_rounded,
                  color: AppColors.primary, size: 16)
              : null,
        ),
        constraints: const BoxConstraints(maxHeight: 250),
      ),
    );
  }
}
