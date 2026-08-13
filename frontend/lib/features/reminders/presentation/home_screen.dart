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
import '../../profile/presentation/profile_screen.dart';
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
  int _currentIndex = 0;
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Todas';
  bool _isSyncing = false;
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Todas', 'color': AppTheme.primaryDark},
    {'name': 'Trabajo', 'color': const Color(0xFF38BDF8)},
    {'name': 'Personal', 'color': const Color(0xFF2DD4BF)},
    {'name': 'Salud', 'color': const Color(0xFFF43F5E)},
  ];

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncServiceProvider).syncReminders();
      await ref.read(remindersProvider.notifier).loadReminders();
      if (mounted) {
        AppToast.show(context, message: '¡Datos sincronizados con la nube!', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Error al sincronizar: $e', type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Card(
                color: AppTheme.surfaceDark,
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GaxxsLoader(showBrandName: false, size: 44),
                      SizedBox(height: 16),
                      Text(
                        'Escaneando imagen con IA...',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final mimeType = pickedFile.name.endsWith('.png') ? 'image/png' : 'image/jpeg';

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/assistant/scan', data: {
        'imageBase64': base64String,
        'mimeType': mimeType,
      });

      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final newReminder = ReminderModel.fromJson(Map<String, dynamic>.from(response.data as Map));
        await ref.read(localReminderRepositoryProvider).insertReminder(newReminder);
        await ref.read(remindersProvider.notifier).loadReminders();

        if (mounted) {
          AppToast.show(context, message: '¡Tarea creada con IA: "${newReminder.title}"!', type: AppToastType.success);
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        AppToast.show(context, message: 'Error procesando OCR: $e', type: AppToastType.error);
      }
    }
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Escáner Inteligente Multimodal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryDark),
                ),
                title: const Text('Tomar Foto con la Cámara'),
                subtitle: const Text('Fotografía una nota, volante o letrero'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndProcessImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.accentTeal),
                ),
                title: const Text('Elegir de la Galería'),
                subtitle: const Text('Selecciona una captura o imagen existente'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndProcessImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String catName) {
    switch (catName) {
      case 'Trabajo':
        return const Color(0xFF38BDF8);
      case 'Personal':
        return const Color(0xFF2DD4BF);
      case 'Salud':
        return const Color(0xFFF43F5E);
      default:
        return AppTheme.primaryDark;
    }
  }

  void _showProfileMenu(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        final usernameAsync = ref.read(usernameProvider);
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.primaryDark.withValues(alpha: 0.2),
                child: Text(
                  usernameAsync.valueOrNull?.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                usernameAsync.valueOrNull ?? 'Usuario',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sesión Activa - Sincronizado en la nube',
                style: TextStyle(fontSize: 12, color: AppTheme.accentTeal),
              ),
              const SizedBox(height: 24),

              ListTile(
                leading: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: AppTheme.primaryDark,
                ),
                title: Text(isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro'),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(appThemeModeProvider.notifier).toggleTheme();
                },
              ),
              ListTile(
                leading: const Icon(Icons.sync_rounded, color: AppTheme.accentTeal),
                title: const Text('Sincronizar Datos Ahora'),
                onTap: () {
                  Navigator.of(context).pop();
                  _syncData();
                },
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(authStateProvider.notifier).logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usernameAsync = ref.watch(usernameProvider);
    final reminders = ref.watch(remindersProvider);

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
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        elevation: 0,
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        indicatorColor: AppTheme.primaryDark.withValues(alpha: 0.18),
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded, color: AppTheme.primaryDark),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.spa_outlined),
            selectedIcon: Icon(Icons.spa_rounded, color: AppTheme.primaryDark),
            label: 'Hábitos',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article_rounded, color: AppTheme.primaryDark),
            label: 'Notas',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded, color: AppTheme.primaryDark),
            label: 'Equipo',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primaryDark),
            label: 'Perfil',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF2DD4BF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryDark.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.black,
                elevation: 0,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => const AddReminderSheet(),
                  );
                },
                child: const Icon(Icons.add_rounded, size: 30),
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 100% RESPONSIVE HEADER ROW
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showProfileMenu(context, isDark),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryDark.withValues(alpha: 0.2),
                    child: Text(
                      usernameAsync.valueOrNull?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      usernameAsync.when(
                        data: (username) => Text(
                          '¡Hola, $username!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                          ),
                        ),
                        loading: () => const Text('Cargando...'),
                        error: (err, stack) => const Text('¡Hola!'),
                      ),
                      Text(
                        'Organiza tus tareas de hoy',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSyncing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryDark),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.sync_rounded, size: 22),
                        onPressed: _syncData,
                        tooltip: 'Sincronizar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined, size: 22),
                      onPressed: _showScanOptions,
                      tooltip: 'Escáner OCR',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    IconButton(
                      icon: const Icon(Icons.mic_none_rounded, size: 22),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const AssistantScreen()),
                        );
                      },
                      tooltip: 'Asistente IA',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 22),
                      onPressed: () => _showProfileMenu(context, isDark),
                      tooltip: 'Menú & Perfil',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. CALENDAR STRIP (Horizontal Date Picker)
            SizedBox(
              height: 74,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 14,
                itemBuilder: (context, index) {
                  final day = DateTime.now().add(Duration(days: index));
                  final isSelected = day.year == _selectedDate.year &&
                      day.month == _selectedDate.month &&
                      day.day == _selectedDate.day;

                  final dayName = DateFormat('EEE', 'es_US').format(day).toUpperCase();
                  final dayNumber = DateFormat('d').format(day);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = day;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryDark
                              : (isDark ? AppTheme.surfaceDark : Colors.white),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryDark
                                : (isDark ? AppTheme.glassBorder : Colors.grey[200]!),
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryDark.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dayName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.black
                                    : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                              ),
                            ),
                            const SizedBox(height: 4),
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
            const SizedBox(height: 16),

            // 3. CATEGORY CHIPS
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat['name'];
                  final catColor = cat['color'] as Color;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: Text(cat['name'] as String),
                      selected: isSelected,
                      selectedColor: catColor,
                      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? catColor : (isDark ? AppTheme.glassBorder : Colors.grey[300]!),
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat['name'] as String;
                          });
                        }
                      },
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Colors.black
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 4. REMINDERS LIST
            Expanded(
              child: filteredReminders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task_alt_rounded,
                            size: 64,
                            color: isDark ? Colors.white12 : Colors.grey[300],
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
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.surfaceDark : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? AppTheme.glassBorder : Colors.grey[200]!,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Transform.scale(
                                scale: 1.1,
                                child: Checkbox(
                                  value: isCompleted,
                                  activeColor: AppTheme.primaryDark,
                                  checkColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  onChanged: (val) {
                                    ref.read(remindersProvider.notifier).toggleReminderStatus(reminder.id);
                                  },
                                ),
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
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: catColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: catColor.withValues(alpha: 0.5), width: 0.8),
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
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: 13,
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
                                      if (reminder.locationName != null) ...[
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.location_on, size: 13, color: AppTheme.accentTeal),
                                            const SizedBox(width: 2),
                                            Text(
                                              reminder.locationName!,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.accentTeal,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (reminder.workspaceId != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryDark.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.5), width: 0.8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.groups, size: 11, color: AppTheme.primaryDark),
                                              const SizedBox(width: 4),
                                              Text(
                                                workspaces.firstWhere(
                                                  (w) => w.id == reminder.workspaceId,
                                                  orElse: () => WorkspaceModel(id: '', name: 'Equipo', ownerId: ''),
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
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
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
