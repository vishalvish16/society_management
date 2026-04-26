import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../providers/tasks_provider.dart';
import '../models/task_models.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  TaskModel? _task;
  bool _loading = true;
  final _commentCtrl = TextEditingController();
  bool _sendingComment = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    setState(() => _loading = true);
    final task = await ref.read(tasksProvider.notifier).getTask(widget.taskId);
    setState(() {
      _task = task;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.id;
    final isAdmin = ['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'MANAGER']
        .contains(authState.user?.role?.toUpperCase());

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _changed) {
          // Parent will be notified via the result
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Task Details'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          actions: [
            if (_task != null && (isAdmin || _task!.createdById == userId))
              PopupMenuButton<String>(
                onSelected: (v) => _handleAction(v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'delete', child: Text('Delete Task', style: TextStyle(color: AppColors.danger))),
                ],
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _task == null
                ? const Center(child: Text('Task not found'))
                : RefreshIndicator(
                    onRefresh: _loadTask,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildStatusHeader(),
                        const SizedBox(height: 16),
                        _buildInfoCard(),
                        const SizedBox(height: 16),
                        _buildAssigneesCard(),
                        if (_task!.attachments.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildAttachmentsCard(),
                        ],
                        const SizedBox(height: 16),
                        _buildStatusActions(userId, isAdmin),
                        const SizedBox(height: 16),
                        _buildCommentsSection(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    final task = _task!;
    final fmt = DateFormat('dd MMM yyyy');
    final isOverdue = task.isOverdue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOverdue ? AppColors.dangerBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _priorityIcon(task.priority),
              const SizedBox(width: 10),
              Expanded(
                child: Text(task.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
            ],
          ),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(task.description!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _statusBadge(task.status),
              _infoBadge(Icons.flag_rounded, _priorityLabel(task.priority), _priorityColor(task.priority)),
              if (isOverdue)
                _infoBadge(Icons.warning_rounded, 'Overdue', AppColors.danger),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('Created by ${task.creatorName ?? 'Unknown'}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const Spacer(),
              Text(fmt.format(task.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          if (task.statusNote != null && task.statusNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warningText),
                  const SizedBox(width: 8),
                  Expanded(child: Text(task.statusNote!, style: const TextStyle(fontSize: 13, color: AppColors.warningText))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final task = _task!;
    final fmt = DateFormat('dd MMM yyyy');
    final categories = ref.read(tasksProvider).categories;
    final categoryLabel = categories[task.category]?.label ?? task.category;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _infoRow('Category', categoryLabel, Icons.category_rounded),
          if (task.subCategory != null)
            _infoRow('Sub-Category', task.subCategory!, Icons.subdirectory_arrow_right_rounded),
          _infoRow('Start Date', fmt.format(task.startDate), Icons.play_arrow_rounded),
          _infoRow('End Date', fmt.format(task.endDate), Icons.stop_rounded),
          if (task.completedAt != null)
            _infoRow('Completed', fmt.format(task.completedAt!), Icons.check_circle_rounded),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  Widget _buildAssigneesCard() {
    final assignees = _task!.assignees;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assignees (${assignees.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          ...assignees.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    a.userName.isNotEmpty ? a.userName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.userName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      if (a.userRole != null)
                        Text(a.userRole!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (a.userPhone != null)
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, size: 18, color: AppColors.success),
                    onPressed: () => launchUrl(Uri.parse('tel:${a.userPhone}')),
                    tooltip: a.userPhone,
                  ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard() {
    final attachments = _task!.attachments;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attachments (${attachments.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          ...attachments.map((a) {
            final isImage = a.fileType.startsWith('image/');
            final url = AppConstants.uploadUrlFromPath(a.fileUrl);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  if (url != null) launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
                        size: 22,
                        color: isImage ? AppColors.info : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.fileName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(_formatFileSize(a.fileSize), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusActions(String? userId, bool isAdmin) {
    final task = _task!;
    final isCreator = task.createdById == userId;
    final isAssignee = task.assignees.any((a) => a.userId == userId);
    if (!isCreator && !isAdmin && !isAssignee) return const SizedBox.shrink();
    if (task.status == 'COMPLETED' || task.status == 'CANCELLED') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Update Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (task.status != 'IN_PROGRESS')
                _statusButton('IN_PROGRESS', 'Start', Icons.play_arrow_rounded, AppColors.warning),
              if (task.status != 'ON_HOLD')
                _statusButton('ON_HOLD', 'Hold', Icons.pause_rounded, AppColors.info),
              _statusButton('COMPLETED', 'Complete', Icons.check_circle_rounded, AppColors.success),
              _statusButton('CANCELLED', 'Cancel', Icons.cancel_rounded, AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusButton(String status, String label, IconData icon, Color color) {
    return OutlinedButton.icon(
      onPressed: () => _showStatusUpdateDialog(status),
      icon: Icon(icon, size: 16, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _showStatusUpdateDialog(String status) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update to ${_statusLabel(status)}'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            hintText: 'Add a note (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref.read(tasksProvider.notifier).updateStatus(
                widget.taskId,
                status,
                statusNote: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
              );
              if (ok) {
                _changed = true;
                _loadTask();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    final comments = _task!.comments;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comments (${comments.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),

          // Comment input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendingComment ? null : _sendComment,
                icon: _sendingComment
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (comments.isEmpty)
            const Text('No comments yet', style: TextStyle(fontSize: 13, color: AppColors.textMuted))
          else
            ...comments.map((c) => _commentTile(c)),
        ],
      ),
    );
  }

  Widget _commentTile(TaskComment comment) {
    final fmt = DateFormat('dd MMM, hh:mm a');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: Text(
              comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.userName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text(fmt.format(comment.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(comment.body, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _sendingComment = true);
    final ok = await ref.read(tasksProvider.notifier).addComment(widget.taskId, body);
    if (ok) {
      _commentCtrl.clear();
      _changed = true;
      await _loadTask();
    }
    setState(() => _sendingComment = false);
  }

  void _handleAction(String action) {
    if (action == 'delete') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Task?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await ref.read(tasksProvider.notifier).deleteTask(widget.taskId);
                if (ok && mounted) Navigator.pop(context, true);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  Widget _priorityIcon(String priority) {
    final (color, icon) = switch (priority) {
      'URGENT' => (AppColors.danger, Icons.priority_high_rounded),
      'HIGH' => (AppColors.warning, Icons.arrow_upward_rounded),
      'MEDIUM' => (AppColors.primary, Icons.remove_rounded),
      _ => (AppColors.textMuted, Icons.arrow_downward_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _priorityLabel(String p) => switch (p) {
    'URGENT' => 'Urgent',
    'HIGH' => 'High',
    'MEDIUM' => 'Medium',
    _ => 'Low',
  };

  Color _priorityColor(String p) => switch (p) {
    'URGENT' => AppColors.danger,
    'HIGH' => AppColors.warning,
    'MEDIUM' => AppColors.primary,
    _ => AppColors.textMuted,
  };

  String _statusLabel(String s) => switch (s) {
    'IN_PROGRESS' => 'In Progress',
    'ON_HOLD' => 'On Hold',
    'COMPLETED' => 'Completed',
    'CANCELLED' => 'Cancelled',
    _ => 'Open',
  };

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
