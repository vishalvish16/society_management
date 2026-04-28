import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../providers/tasks_provider.dart';
import '../models/task_models.dart';
import 'task_form_sheet.dart';
import 'task_detail_screen.dart';
import '../../../shared/widgets/show_app_sheet.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _filterCategory;
  String? _filterPriority;
  final List<String> _tabs = const ['all', 'active', 'on_hold', 'completed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TaskModel> _filterTasks(List<TaskModel> tasks, String tab) {
    List<TaskModel> filtered;
    switch (tab) {
      case 'active':
        filtered = tasks.where((t) => t.status == 'OPEN' || t.status == 'IN_PROGRESS').toList();
        break;
      case 'on_hold':
        filtered = tasks.where((t) => t.status == 'ON_HOLD').toList();
        break;
      case 'completed':
        filtered = tasks.where((t) => t.status == 'COMPLETED').toList();
        break;
      case 'all':
      default:
        filtered = tasks;
    }
    if (_filterCategory != null) {
      filtered = filtered.where((t) => t.category == _filterCategory).toList();
    }
    if (_filterPriority != null) {
      filtered = filtered.where((t) => t.priority == _filterPriority).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasksProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final roleUpper = user == null ? null : user.role.toUpperCase();
    final isAdmin = ['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'MANAGER'].contains(roleUpper);
    final name = (user?.name ?? '').trim();
    final avatarLetter = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
              child: Text(
                avatarLetter,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderCard(state),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTabContent(state),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateTask(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Task'),
            )
          : null,
    );
  }

  Widget _buildHeaderCard(TasksState state) {
    final tasks = state.tasks;
    final active = tasks.where((t) => t.status == 'OPEN' || t.status == 'IN_PROGRESS').length;
    final overdue = tasks.where((t) => t.isOverdue).length;
    final completed = tasks.where((t) => t.status == 'COMPLETED').length;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.task_alt_rounded, color: AppColors.primary, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Tasks',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _statInline('Active', active, AppColors.primary),
                  _statInline('Overdue', overdue, AppColors.danger),
                  _statInline('Done', completed, AppColors.success),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _filterDropdown(
                      label: 'Category',
                      value: _filterCategory,
                      items: state.categories.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.label)))
                          .toList(),
                      onChanged: (v) => setState(() => _filterCategory = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _filterDropdown(
                      label: 'Priority',
                      value: _filterPriority,
                      items: const [
                        DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                        DropdownMenuItem(value: 'HIGH', child: Text('High')),
                        DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                        DropdownMenuItem(value: 'LOW', child: Text('Low')),
                      ],
                      onChanged: (v) => setState(() => _filterPriority = v),
                    ),
                  ),
                  if (_filterCategory != null || _filterPriority != null) ...[
                    const SizedBox(width: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() {
                        _filterCategory = null;
                        _filterPriority = null;
                      }),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _buildTabBar(inCard: true),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _statInline(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _filterDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          items: items,
          onChanged: onChanged,
          isDense: true,
          isExpanded: true,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar({bool inCard = false}) {
    return Container(
      margin: inCard ? EdgeInsets.zero : const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Active'),
          Tab(text: 'On Hold'),
          Tab(text: 'Done'),
        ],
      ),
    );
  }

  Widget _buildTabContent(TasksState state) {
    return TabBarView(
      controller: _tabController,
      children: _tabs.map((tab) {
        final filtered = _filterTasks(state.tasks, tab);
        return RefreshIndicator(
          onRefresh: () => ref.read(tasksProvider.notifier).loadTasks(),
          child: filtered.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 80),
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.task_outlined, size: 56, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text('No tasks found', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _TaskCard(
                    task: filtered[i],
                    categories: state.categories,
                    onTap: () => _openTaskDetail(filtered[i]),
                  ),
                ),
        );
      }).toList(),
    );
  }

  void _openCreateTask() async {
    final created = await showAppSheet<bool>(
      context: context,
      builder: (_) => const TaskFormSheet(),
    );
    if (created == true) {
      ref.read(tasksProvider.notifier).loadTasks();
    }
  }

  void _openTaskDetail(TaskModel task) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
    );
    if (changed == true) {
      ref.read(tasksProvider.notifier).loadTasks();
    }
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final Map<String, TaskCategory> categories;
  final VoidCallback onTap;

  const _TaskCard({required this.task, required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM');
    final categoryLabel = categories[task.category]?.label ?? task.category;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.isOverdue ? AppColors.dangerBorder : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _priorityDot(task.priority),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _statusBadge(task.status),
                ],
              ),
              if (task.description != null && task.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    task.description!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _infoChip(Icons.category_rounded, categoryLabel, AppColors.info, AppColors.infoSurface),
                  if (task.subCategory != null)
                    _infoChip(Icons.subdirectory_arrow_right_rounded, task.subCategory!, AppColors.teal, AppColors.tealSurface),
                  _infoChip(
                    Icons.calendar_today_rounded,
                    '${dateFmt.format(task.startDate)} - ${dateFmt.format(task.endDate)}',
                    task.isOverdue ? AppColors.danger : AppColors.textSecondary,
                    task.isOverdue ? AppColors.dangerSurface : AppColors.surfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (task.assignees.isNotEmpty) ...[
                    _buildAssigneeAvatars(task.assignees),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.assignees.map((a) => a.userName).join(', '),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (task.attachments.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_file_rounded, size: 14, color: AppColors.textMuted),
                        Text('${task.attachments.length}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(width: 8),
                      ],
                    ),
                  if (task.commentCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 2),
                        Text('${task.commentCount}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssigneeAvatars(List<TaskAssignee> assignees) {
    final show = assignees.take(3).toList();
    final extra = assignees.length - 3;
    return SizedBox(
      width: show.length * 20.0 + (extra > 0 ? 20 : 0),
      height: 26,
      child: Stack(
        children: [
          for (int i = 0; i < show.length; i++)
            Positioned(
              left: i * 16.0,
              child: CircleAvatar(
                radius: 13,
                backgroundColor: _avatarColor(i),
                child: Text(
                  show[i].userName.isNotEmpty ? show[i].userName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: show.length * 16.0,
              child: CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.textMuted,
                child: Text('+$extra', style: const TextStyle(fontSize: 9, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Color _avatarColor(int i) {
    const colors = [AppColors.primary, AppColors.success, AppColors.info, AppColors.warning];
    return colors[i % colors.length];
  }

  Widget _priorityDot(String priority) {
    final color = switch (priority) {
      'URGENT' => AppColors.danger,
      'HIGH' => AppColors.warning,
      'MEDIUM' => AppColors.primary,
      _ => AppColors.textMuted,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _statusBadge(String status) {
    final (Color color, Color bg, String label) = switch (status) {
      'OPEN' => (AppColors.primary, AppColors.primarySurface, 'Open'),
      'IN_PROGRESS' => (AppColors.warning, AppColors.warningSurface, 'In Progress'),
      'ON_HOLD' => (AppColors.info, AppColors.infoSurface, 'On Hold'),
      'COMPLETED' => (AppColors.success, AppColors.successSurface, 'Completed'),
      'CANCELLED' => (AppColors.danger, AppColors.dangerSurface, 'Cancelled'),
      _ => (AppColors.textMuted, AppColors.surfaceVariant, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
