import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import 'habits_provider.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  final _habitController = TextEditingController();
  String _selectedFrequency = 'daily';
  bool _isSyncing = false;

  @override
  void dispose() {
    _habitController.dispose();
    super.dispose();
  }

  Future<void> _syncHabits() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(habitsProvider.notifier).syncWithCloud();
      if (mounted) {
        AppToast.show(context, message: '¡Hábitos sincronizados con la nube!', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Error de sincronización: $e', type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showAddHabitDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Crear Hábito',
                style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: _habitController,
                    labelText: 'Nombre del Hábito',
                    hintText: 'ej. Meditar, Leer 15 min',
                    prefixIcon: Icons.bolt_rounded,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFrequency,
                    decoration: InputDecoration(
                      labelText: 'Frecuencia',
                      filled: true,
                      fillColor: isDark ? AppTheme.surfaceDarkElevated : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Diario')),
                      DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          _selectedFrequency = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _habitController.clear();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final name = _habitController.text.trim();
                    if (name.isNotEmpty) {
                      ref.read(habitsProvider.notifier).addHabit(name, _selectedFrequency);
                      _habitController.clear();
                      Navigator.of(context).pop();
                      AppToast.show(context, message: '¡Hábito creado!', type: AppToastType.success);
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habits = ref.watch(habitsProvider);
    final notifier = ref.read(habitsProvider.notifier);
    final levelDetails = notifier.levelDetails;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 90.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hábitos & Gamificación',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Completa hábitos diarios para acumular XP',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  _isSyncing
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryDark),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.sync_rounded),
                          onPressed: _syncHabits,
                        ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. GAMIFICATION CARD (Level & XP Tracker with Glow)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppTheme.glassBorder : Colors.grey[200]!,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryDark.withValues(alpha: isDark ? 0.12 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nivel ${levelDetails['level']}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              levelDetails['levelName'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.amber.withValues(alpha: 0.15),
                          ),
                          child: Icon(
                            Icons.emoji_events_rounded,
                            size: 32,
                            color: Colors.amber[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: levelDetails['progress'] as double,
                        minHeight: 10,
                        backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryDark),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'XP: ${levelDetails['xp']}/100',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                          ),
                        ),
                        Text(
                          'Puntos Totales: ${notifier.totalPoints}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.accentTeal : AppTheme.accentIndigo,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Mis Hábitos Activos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),

              // 3. HABITS LIST
              Expanded(
                child: habits.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 64,
                              color: isDark ? Colors.white12 : Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '¿Qué tal si creamos un nuevo hábito?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Comienza a agendar y a ganar XP hoy.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white30 : Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: habits.length,
                        itemBuilder: (context, index) {
                          final habit = habits[index];
                          final today = DateTime.now();
                          final isCompletedToday = habit.lastCompleted != null &&
                              habit.lastCompleted!.day == today.day &&
                              habit.lastCompleted!.month == today.month &&
                              habit.lastCompleted!.year == today.year;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.surfaceDark : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? AppTheme.glassBorder : Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                leading: IconButton(
                                  icon: Icon(
                                    isCompletedToday
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isCompletedToday
                                        ? AppTheme.accentTeal
                                        : (isDark ? Colors.white38 : Colors.black38),
                                    size: 28,
                                  ),
                                  onPressed: () async {
                                    if (isCompletedToday) {
                                      AppToast.show(context, message: '¡Ya completaste este hábito hoy!', type: AppToastType.warning);
                                      return;
                                    }
                                    final res = await ref.read(habitsProvider.notifier).completeHabit(habit.id);
                                    if (context.mounted && res['success'] == true) {
                                      AppToast.show(
                                        context,
                                        message: '${res['message']} (+${res['pointsEarned']} XP)',
                                        type: AppToastType.success,
                                      );
                                    }
                                  },
                                ),
                                title: Text(
                                  habit.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryDark.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        habit.frequency == 'daily' ? 'Diario' : 'Semanal',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.primaryDark,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (habit.streak > 0) ...[
                                      const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 16),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${habit.streak} d racha',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    ref.read(habitsProvider.notifier).deleteHabit(habit.id);
                                    AppToast.show(context, message: 'Hábito eliminado', type: AppToastType.warning);
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72.0),
        child: FloatingActionButton(
          backgroundColor: AppTheme.primaryDark,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onPressed: _showAddHabitDialog,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }
}
