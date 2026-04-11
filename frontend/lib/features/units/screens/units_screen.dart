import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/unit_provider.dart';

class UnitsScreen extends ConsumerWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => ref.read(unitsProvider.notifier).fetchUnits(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Society Units',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                        SizedBox(height: 4),
                        Text('Manage society apartments and occupancy',
                            style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddUnitDialog(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Unit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filter Bar
              // (Future improvement: Search and Filter by Wing)

              // Units List
              unitsAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                error: (err, _) => _ErrorCard(message: err.toString()),
                data: (units) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: units.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(60),
                          child: Center(child: Text('No units found', style: TextStyle(color: AppColors.textMuted))),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                  columns: const [
                                    DataColumn(label: Text('Full Code', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Wing', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Residents', style: TextStyle(fontWeight: FontWeight.w600))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                                  ],
                                  rows: units.map<DataRow>((u) {
                                    final status = u['status'] ?? 'VACANT';
                                    final residents = (u['unitResidents'] as List? ?? []);
                                    final residentNames = residents.map((r) => r['user']['name']).join(', ');

                                    return DataRow(cells: [
                                      DataCell(Text(u['fullCode'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                                      DataCell(Text(u['wing'] ?? '-')),
                                      DataCell(Text(u['unitNumber'] ?? '')),
                                      DataCell(_StatusBadge(status: status)),
                                      DataCell(Text(residentNames.isEmpty ? 'Vacant' : residentNames,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: residentNames.isEmpty ? AppColors.textMuted : AppColors.textMain,
                                          ))),
                                      DataCell(Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18),
                                            onPressed: () {}, // Edit logic
                                            tooltip: 'Edit',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                            onPressed: () => _confirmDelete(context, ref, u['id'], u['fullCode']),
                                            tooltip: 'Delete',
                                          ),
                                        ],
                                      )),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Unit'),
        content: Text('Are you sure you want to delete Unit $name? Only vacant units can be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
            onPressed: () async {
              final success = await ref.read(unitsProvider.notifier).deleteUnit(id);
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit deleted successfully')));
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Failed to delete unit. Is it occupied?')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAddUnitDialog(BuildContext context, WidgetRef ref) {
    // Basic dialog to add unit
    final wingController = TextEditingController();
    final unitController = TextEditingController();
    final floorController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: wingController, decoration: const InputDecoration(labelText: 'Wing (e.g. A, B)')),
            TextField(controller: floorController, decoration: const InputDecoration(labelText: 'Floor Number')),
            TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Unit Number')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            child: const Text('Create'),
            onPressed: () async {
              final success = await ref.read(unitsProvider.notifier).createUnit({
                'wing': wingController.text.trim(),
                'unitNumber': unitController.text.trim(),
                'floor': int.tryParse(floorController.text) ?? 0,
              });
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit created')));
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toUpperCase()) {
      case 'OCCUPIED':
        color = AppColors.secondary;
        break;
      case 'VACANT':
        color = const Color(0xFF3B82F6);
        break;
      case 'RENOVATION':
        color = const Color(0xFFF59E0B);
        break;
      default:
        color = AppColors.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.error.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: AppColors.error))),
          ],
        ),
      ),
    );
  }
}
