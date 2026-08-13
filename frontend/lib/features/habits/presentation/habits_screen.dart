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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Crear Hábito',
                style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: _habitController,
                    labelText: 'Nombre del Hábito',
                    hintText: 'ej. Meditar, Leer 15 min',
                    prefixIcon: Icons.bolt,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFrequency,
                    decoration: InputDecoration(
                      labelText: 'Frecuencia',
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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
                        'Mi Productividad',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Completa hábitos cotidianos para subir de nivel',
                        style: TextStyle(
                          fontSize: 14,
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

              // 2. GAMIFICATION CARD (Level & XP Tracker)
              Card(
                elevation: isDark ? 0 : 3,
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
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
                          Icon(
                            Icons.emoji_events,
                            size: 40,
                            color: Colors.amber[600],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: levelDetails['progress'] as double,
                          minHeight: 12,
                          backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryDark),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Mis Hábitos',
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
                              Icons.spa_outlined,
                              size: 64,
                              color: isDark ? Colors.white24 : Colors.grey[300],
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
                          
                          // Check if completed today
                          final isCompletedToday = habit.lastCompleted != null &&
                              habit.lastCompleted!.day == today.day &&
                              habit.lastCompleted!.month == today.month &&
                              habit.lastCompleted!.year == today.year;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Card(
                              elevation: isDark ? 0 : 2,
                              color: isDark ? AppTheme.surfaceDark : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.grey[200]!,
                                ),
                              ),
                              child: ListTile(
                                leading: IconButton(
                                  icon: Icon(
                                    isCompletedToday
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isCompletedToday
                                        ? Colors.teal
                                        : (isDark ? Colors.white54 : Colors.black45),
                                    size: 28,
                                  ),
                                  onPressed: () async {
                                    if (isCompletedToday) {
                                      AppToast.show(context, message: '¡Ya marcaste este hábito hoy!', type: AppToastType.warning);
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
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryDark.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
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
                                    const SizedBox(width: 12),
                                    if (habit.streak > 0) ...[
                                      const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Racha: ${habit.streak} d',
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
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _showAddHabitDialog,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
