import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'reminders_provider.dart';
import 'add_reminder_sheet.dart';
import '../../../core/widgets/app_toast.dart';
import '../../assistant/presentation/assistant_screen.dart';
import '../../habits/presentation/habits_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Todas';
  bool _isSyncing = false;
  int _currentIndex = 0;

  final List<String> _categories = ['Todas', 'Personal', 'Trabajo', 'Salud', 'General'];

  @override
  void initState() {
    super.initState();
    // Auto-sync on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncData(showToast: false);
    });
  }

  Future<void> _syncData({bool showToast = true}) async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(remindersProvider.notifier).syncWithCloud();
      if (mounted && showToast) {
        AppToast.show(context, message: '¡Datos sincronizados con la nube!', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted && showToast) {
        AppToast.show(context, message: 'Error de sincronización: $e', type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // Map category names to their colors
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Personal':
        return const Color(0xFF0D9488);
      case 'Trabajo':
        return const Color(0xFF38BDF8);
      case 'Salud':
        return const Color(0xFFEF4444);
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usernameAsync = ref.watch(usernameProvider);
    final reminders = ref.watch(remindersProvider);

    // Filter reminders by selected date and selected category
    final filteredReminders = reminders.where((r) {
      final isSameDay = r.dueDate.year == _selectedDate.year &&
          r.dueDate.month == _selectedDate.month &&
          r.dueDate.day == _selectedDate.day;

      final matchesCategory = _selectedCategory == 'Todas' || r.category == _selectedCategory;

      return isSameDay && matchesCategory;
    }).toList();

    final List<Widget> screens = [
      _buildRemindersBody(context, filteredReminders, isDark, usernameAsync),
      const HabitsScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppTheme.primaryDark,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.spa_outlined),
            activeIcon: Icon(Icons.spa),
            label: 'Hábitos',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => const AddReminderSheet(),
                );
              },
              child: const Icon(Icons.add, size: 28),
            )
          : null,
    );
  }

  Widget _buildRemindersBody(
    BuildContext context,
    List<dynamic> filteredReminders,
    bool isDark,
    AsyncValue<String> usernameAsync,
  ) {
    return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER ROW (Hola user + toggle theme + logout)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      usernameAsync.when(
                        data: (username) => Text(
                          '¡Hola, $username!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                          ),
                        ),
                        loading: () => const Text('Cargando...'),
                        error: (err, stack) => const Text('¡Hola!'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Organiza tus compromisos de hoy',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _isSyncing
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.sync_rounded),
                              onPressed: _syncData,
                            ),
                      IconButton(
                        icon: const Icon(Icons.mic_none_rounded),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const AssistantScreen()),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                        onPressed: () => ref.read(appThemeModeProvider.notifier).toggleTheme(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded),
                        onPressed: () async {
                          await ref.read(authStateProvider.notifier).logout();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. CALENDAR STRIP (Horizontal selector for next 7 days)
              Text(
                'Calendario',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    final day = DateTime.now().add(Duration(days: index));
                    final isSelected = day.year == _selectedDate.year &&
                        day.month == _selectedDate.month &&
                        day.day == _selectedDate.day;

                    final dayName = DateFormat('EEE', 'es_US').format(day).toUpperCase();
                    final dayNumber = DateFormat('d').format(day);

                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = day;
                          });
                        },
                        child: Container(
                          width: 58,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryDark
                                : (isDark ? AppTheme.surfaceDark : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryDark
                                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                dayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.black
                                      : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dayNumber,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.black
                                      : (isDark ? Colors.white : AppTheme.textPrimaryLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // 3. CATEGORY CHIPS
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final catName = _categories[index];
                    final isSelected = _selectedCategory == catName;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(catName),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategory = catName;
                            });
                          }
                        },
                        selectedColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // 4. LIST OF REMINDERS
              Expanded(
                child: filteredReminders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.task_alt_outlined,
                              size: 64,
                              color: isDark ? Colors.white24 : Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No tienes compromisos agendados',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Usa el botón "+" para programar uno nuevo.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white30 : Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredReminders.length,
                        itemBuilder: (context, index) {
                          final reminder = filteredReminders[index];
                          final isCompleted = reminder.status == 'completed';
                          final Color catColor = _getCategoryColor(reminder.category);

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
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                leading: Checkbox(
                                  value: isCompleted,
                                  activeColor: AppTheme.primaryDark,
                                  onChanged: (val) {
                                    ref.read(remindersProvider.notifier).toggleReminderStatus(reminder.id);
                                  },
                                ),
                                title: Text(
                                  reminder.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                    color: isCompleted
                                        ? Colors.grey
                                        : (isDark ? Colors.white : AppTheme.textPrimaryLight),
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (reminder.description != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        reminder.description!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isCompleted
                                              ? Colors.grey[600]
                                              : (isDark ? Colors.white70 : Colors.black54),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        // Category Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: catColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: catColor, width: 0.8),
                                          ),
                                          child: Text(
                                            reminder.category,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: catColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Time tag
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color: isDark ? Colors.white54 : Colors.black45,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('hh:mm a').format(reminder.dueDate),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white54 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () {
                                    ref.read(remindersProvider.notifier).deleteReminder(reminder.id);
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
      );
  }
}
