import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../habits/presentation/habits_provider.dart';
import '../reminders_provider.dart';

class ProductivityStatsWidget extends ConsumerWidget {
  const ProductivityStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reminders = ref.watch(remindersProvider);
    final habits = ref.watch(habitsProvider);

    final now = DateTime.now();
    final todayReminders = reminders.where((r) {
      final d = r.dueDate;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();

    final completedTodayReminders = todayReminders.where((r) => r.status == 'completed').length;
    final totalTodayReminders = todayReminders.length;

    final completedTodayHabits = habits.where((h) {
      if (h.lastCompleted == null) return false;
      final d = h.lastCompleted!;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
    final totalHabits = habits.length;

    int totalScore = 0;
    for (final h in habits) {
      totalScore += h.points;
    }

    final double completionRate = (totalTodayReminders + totalHabits) > 0
        ? ((completedTodayReminders + completedTodayHabits) / (totalTodayReminders + totalHabits))
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDarkElevated : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentIndigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights_rounded, color: AppTheme.accentIndigo, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tu Rendimiento Hoy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$totalScore XP',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Barra de Progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completionRate,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentIndigo),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric(
                label: 'Tareas Listas',
                value: '$completedTodayReminders/$totalTodayReminders',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF10B981),
              ),
              _buildMiniMetric(
                label: 'Hábitos Cumplidos',
                value: '$completedTodayHabits/$totalHabits',
                icon: Icons.local_fire_department_rounded,
                color: Colors.deepOrangeAccent,
              ),
              _buildMiniMetric(
                label: 'Efectividad',
                value: '${(completionRate * 100).toInt()}%',
                icon: Icons.trending_up_rounded,
                color: AppTheme.accentIndigo,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}
