import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../reminders/presentation/reminders_provider.dart';
import '../../reminders/data/reminder_model.dart';

class KanbanScreen extends ConsumerWidget {
  const KanbanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reminders = ref.watch(remindersProvider);

    final pendingReminders = reminders.where((r) => r.status == 'pending').toList();
    final completedReminders = reminders.where((r) => r.status == 'completed').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tablero Kanban', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKanbanColumn('Por Hacer', pendingReminders, AppTheme.primaryDark, isDark, ref),
              const SizedBox(width: 16),
              _buildKanbanColumn('Completadas', completedReminders, AppTheme.accentTeal, isDark, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(
    String title,
    List<ReminderModel> list,
    Color accentColor,
    bool isDark,
    WidgetRef ref,
  ) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.glassBorder : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${list.length}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      'Sin tareas en esta columna',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final r = list[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.surfaceDarkElevated : Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: r.priority == 'alta'
                                ? Colors.redAccent
                                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[300]!),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (r.description != null && r.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                r.description!,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    r.category,
                                    style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    r.status == 'completed'
                                        ? Icons.undo_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 18,
                                    color: accentColor,
                                  ),
                                  onPressed: () {
                                    ref.read(remindersProvider.notifier).toggleReminderStatus(r.id);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
