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
import '../../notes/presentation/notes_screen.dart';
import '../../workspaces/presentation/workspaces_screen.dart';
import '../../workspaces/presentation/workspaces_provider.dart';
import '../../workspaces/data/workspace_model.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/gaxxs_loader.dart';
import '../data/reminder_model.dart';

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

  Future<void> _scanImageOcr(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);

    if (pickedFile == null) return;
    if (!mounted) return;

    // Show AI loading modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GaxxsLoader(showBrandName: false, size: 48),
                SizedBox(height: 16),
                Text(
                  'Gemini analizando imagen...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Extrayendo datos de la tarea...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final mimeType = pickedFile.name.endsWith('.png') ? 'image/png' : 'image/jpeg';

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/assistant/scan', data: {
        'imageBase64': base64String,
        'mimeType': mimeType,
      });

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final newReminder = ReminderModel.fromJson(Map<String, dynamic>.from(response.data as Map));
        
        // Save locally immediately
        await ref.read(localReminderRepositoryProvider).insertReminder(newReminder);
        
        // Refresh reminders provider state
        await ref.read(remindersProvider.notifier).loadReminders();

        if (mounted) {
          AppToast.show(context, message: '¡Tarea creada con IA: "${newReminder.title}"!', type: AppToastType.success);
        }
      } else {
        throw Exception('Servidor respondió con código ${response.statusCode}');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        AppToast.show(context, message: 'Error procesando OCR: $e', type: AppToastType.error);
      }
    }
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Escanear con Inteligencia Artificial',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppTheme.primaryDark),
                  title: const Text('Tomar Foto con la Cámara'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _scanImageOcr(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: AppTheme.primaryDark),
                  title: const Text('Elegir desde la Galería'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _scanImageOcr(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
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
      const NotesScreen(),
      const WorkspacesScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppTheme.primaryDark,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
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
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            activeIcon: Icon(Icons.article),
            label: 'Notas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'Compartido',
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
                        icon: const Icon(Icons.camera_alt_outlined),
                        onPressed: _showScanOptions,
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
                          final workspaces = ref.watch(workspacesProvider);

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
                                        if (reminder.workspaceId != null) ...[
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryDark.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppTheme.primaryDark, width: 0.8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.groups, size: 10, color: AppTheme.primaryDark),
                                                const SizedBox(width: 4),
                                                Text(
                                                  workspaces.firstWhere(
                                                    (w) => w.id == reminder.workspaceId,
                                                    orElse: () => WorkspaceModel(id: '', name: 'Colaborativo', ownerId: ''),
                                                  ).name,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppTheme.primaryDark,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
