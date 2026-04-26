import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../providers/tasks_provider.dart';

class TaskFormSheet extends ConsumerStatefulWidget {
  const TaskFormSheet({super.key});

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _category;
  String? _subCategory;
  String _priority = 'MEDIUM';
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _selectedAssigneeIds = [];
  final List<XFile> _attachments = [];
  bool _isSubmitting = false;

  // Members fetched from API
  List<Map<String, dynamic>> _availableMembers = [];
  bool _loadingMembers = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 7));
    _loadMembers();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final dio = ref.read(authProvider.notifier).client.dio;
      final res = await dio.get('members', queryParameters: {'limit': '1000'});
      if (res.data['success'] == true) {
        final data = res.data['data'];
        final List raw = data is Map ? (data['members'] as List? ?? []) : (data is List ? data : []);
        setState(() => _availableMembers = raw.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
    setState(() => _loadingMembers = false);
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(tasksProvider);
    final categories = tasksState.categories;
    final subCategories = _category != null ? (categories[_category]?.subCategories ?? []) : <String>[];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Row(
            children: [
              const Expanded(
                child: Text('Create New Task', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceVariant,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
                iconSize: 18,
              ),
            ],
          ),
          const SizedBox(height: 20),

          Flexible(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    _sectionLabel('Task Title *'),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: _inputDecor('Enter task title', Icons.title_rounded),
                      validator: (v) => (v == null || v.trim().length < 3) ? 'Min 3 characters' : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _sectionLabel('Description'),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: _inputDecor('Enter task description', Icons.description_rounded),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Category & SubCategory
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Category *'),
                              DropdownButtonFormField<String>(
                                value: _category,
                                decoration: _inputDecor('Select category', Icons.category_rounded),
                                items: categories.entries
                                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.label)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _category = v;
                                  _subCategory = null;
                                }),
                                validator: (v) => v == null ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Sub-Category'),
                              DropdownButtonFormField<String>(
                                value: _subCategory,
                                decoration: _inputDecor('Select sub-category', Icons.subdirectory_arrow_right_rounded),
                                items: subCategories
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (v) => setState(() => _subCategory = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Priority
                    _sectionLabel('Priority *'),
                    _buildPrioritySelector(),
                    const SizedBox(height: 16),

                    // Dates
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Start Date *'),
                              _datePicker(
                                value: _startDate,
                                onPicked: (d) => setState(() => _startDate = d),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('End Date *'),
                              _datePicker(
                                value: _endDate,
                                onPicked: (d) => setState(() => _endDate = d),
                                firstDate: _startDate,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Assign Members
                    _sectionLabel('Assign To *'),
                    _buildAssigneePicker(),
                    const SizedBox(height: 16),

                    // Attachments
                    _sectionLabel('Attachments'),
                    _buildAttachmentSection(),
                    const SizedBox(height: 28),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_rounded),
                        label: Text(_isSubmitting ? 'Creating...' : 'Create Task'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }

  InputDecoration _inputDecor(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildPrioritySelector() {
    const priorities = [
      ('LOW', 'Low', AppColors.textMuted, Icons.arrow_downward_rounded),
      ('MEDIUM', 'Medium', AppColors.primary, Icons.remove_rounded),
      ('HIGH', 'High', AppColors.warning, Icons.arrow_upward_rounded),
      ('URGENT', 'Urgent', AppColors.danger, Icons.priority_high_rounded),
    ];
    return Row(
      children: priorities.map((p) {
        final isSelected = _priority == p.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: p.$1 != 'URGENT' ? 8 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _priority = p.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? p.$3.withValues(alpha: 0.12) : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? p.$3 : AppColors.border, width: isSelected ? 1.5 : 1),
                ),
                child: Column(
                  children: [
                    Icon(p.$4, color: p.$3, size: 18),
                    const SizedBox(height: 2),
                    Text(p.$2, style: TextStyle(fontSize: 11, color: isSelected ? p.$3 : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _datePicker({required DateTime? value, required ValueChanged<DateTime> onPicked, DateTime? firstDate}) {
    final fmt = DateFormat('dd MMM yyyy');
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              value != null ? fmt.format(value) : 'Pick date',
              style: TextStyle(fontSize: 14, color: value != null ? AppColors.textPrimary : AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneePicker() {
    if (_loadingMembers) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _showMemberSelectionSheet,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_rounded, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedAssigneeIds.isEmpty
                        ? 'Tap to select members or staff'
                        : '${_selectedAssigneeIds.length} member(s) selected',
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedAssigneeIds.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        if (_selectedAssigneeIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedAssigneeIds.map((id) {
                final member = _availableMembers.firstWhere((m) => m['id'] == id, orElse: () => {});
                final name = member['name'] ?? 'Unknown';
                return Chip(
                  label: Text(name, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _selectedAssigneeIds.remove(id)),
                  backgroundColor: AppColors.primarySurface,
                  side: const BorderSide(color: AppColors.primaryBorder),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _showMemberSelectionSheet() {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> filtered = List.from(_availableMembers);
    Set<String> selected = Set.from(_selectedAssigneeIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (ctx, scrollCtrl) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        children: [
                          Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text('Select Assignees', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  setState(() => _selectedAssigneeIds = selected.toList());
                                  Navigator.pop(ctx);
                                },
                                child: Text('Done (${selected.length})'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Search members...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              filled: true,
                              fillColor: AppColors.surfaceVariant,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onChanged: (q) {
                               setSheetState(() {
                                filtered = _availableMembers.where((m) {
                                  final name = (m['name'] ?? '').toString().toLowerCase();
                                  final role = (m['role'] ?? '').toString().toLowerCase();
                                  final query = q.toLowerCase();
                                  return name.contains(query) || role.contains(query);
                                }).toList();
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final m = filtered[i];
                          final id = m['id'] as String;
                          final isSelected = selected.contains(id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (v) {
                              setSheetState(() {
                                if (v == true) {
                                  selected.add(id);
                                } else {
                                  selected.remove(id);
                                }
                              });
                            },
                            title: Text(m['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            subtitle: Text(
                              '${m['role'] ?? ''} ${m['phone'] ?? ''}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            secondary: CircleAvatar(
                              radius: 18,
                              backgroundColor: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                              child: Text(
                                ((m['name'] ?? 'U') as String).isNotEmpty ? (m['name'] as String)[0].toUpperCase() : 'U',
                                style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.trailing,
                            activeColor: AppColors.primary,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickAttachment(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Camera'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primaryBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _pickAttachment(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.info,
                side: const BorderSide(color: AppColors.infoBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: const Text('File'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _attachments.asMap().entries.map((entry) {
              final file = entry.value;
              return Chip(
                avatar: const Icon(Icons.insert_drive_file_rounded, size: 16),
                label: Text(file.name, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() => _attachments.removeAt(entry.key)),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _pickAttachment(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 80);
      if (file != null) setState(() => _attachments.add(file));
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage(imageQuality: 80);
      if (files.isNotEmpty) setState(() => _attachments.addAll(files));
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select start and end dates')));
      return;
    }
    if (_selectedAssigneeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one assignee')));
      return;
    }

    setState(() => _isSubmitting = true);

    final ok = await ref.read(tasksProvider.notifier).createTask(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category!,
      subCategory: _subCategory,
      priority: _priority,
      startDate: _startDate!,
      endDate: _endDate!,
      assigneeIds: _selectedAssigneeIds,
      attachments: _attachments.isNotEmpty ? _attachments : null,
    );

    setState(() => _isSubmitting = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created successfully'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(tasksProvider).error ?? 'Failed to create task'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
