import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'reminders_provider.dart';
import 'add_reminder_sheet.dart';
import 'edit_reminder_sheet.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/weather_widget.dart';
import '../../assistant/presentation/assistant_screen.dart';
import '../../habits/presentation/habits_screen.dart';
import '../../notes/presentation/notes_screen.dart';
import '../../workspaces/presentation/workspaces_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../pomodoro/presentation/pomodoro_screen.dart';
import '../../analytics/presentation/analytics_screen.dart';
import '../../quests/presentation/quests_screen.dart';
import '../../kanban/presentation/kanban_screen.dart';
import '../../mood/presentation/mood_tracker_sheet.dart';
import '../../search/presentation/global_search_sheet.dart';
import '../../workspaces/presentation/workspaces_provider.dart';
import '../../workspaces/data/workspace_model.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/gaxxs_loader.dart';
import '../../../core/services/permission_service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(permissionServiceProvider).requestInitialPermissions();
    });
  }

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
        AppToast.show(context, message: 'Guardado localmente. Se sincronizará con la nube al reconectar.', type: AppToastType.info);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final hasPerm = await ref.read(permissionServiceProvider).requestCameraPermission();
      if (!hasPerm) {
        if (mounted) {
          AppToast.show(context, message: 'Se requiere permiso de cámara para tomar fotos', type: AppToastType.warning);
        }
        return;
      }
    }
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 60,
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
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        AppToast.show(
          context,
          message: 'No se pudo procesar la imagen por IA. Intenta con una foto más clara o agrega la tarea manualmente.',
          type: AppToastType.warning,
        );
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

  // HIGH-END CATEGORIZED GLASSMORPHISM TOOLS MENU
  void _showToolsMenu(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Herramientas & Opciones',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selecciona una función de la suite de productividad',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600]),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  children: [
                    _buildToolSectionHeader('INTELIGENCIA & BÚSQUEDA', isDark),
                    const SizedBox(height: 10),
                    _buildToolTile(
                      icon: Icons.search_rounded,
                      color: AppTheme.primaryDark,
                      title: 'Búsqueda Global Unificada',
                      subtitle: 'Buscar en tareas, notas, hábitos y equipos',
                      onTap: () {
                        Navigator.of(context).pop();
                        showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => const GlobalSearchSheet());
                      },
                      isDark: isDark,
                    ),
                    _buildToolTile(
                      icon: Icons.mic_rounded,
                      color: AppTheme.accentTeal,
                      title: 'Asistente IA por Voz',
                      subtitle: 'Habla y crea compromisos con IA',
                      onTap: () async {
                        Navigator.of(context).pop();
                        final hasMic = await ref.read(permissionServiceProvider).requestMicrophonePermission();
                        if (hasMic && context.mounted) {
                          Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const AssistantScreen()));
                        } else if (context.mounted) {
                          AppToast.show(context, message: 'Se requiere permiso de micrófono para el asistente de voz', type: AppToastType.warning);
                        }
                      },
                      isDark: isDark,
                    ),
                    _buildToolTile(
                      icon: Icons.camera_alt_outlined,
                      color: Colors.purpleAccent,
                      title: 'Escáner OCR de Fotos',
                      subtitle: 'Extraer tareas de imágenes y notas',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showScanOptions();
                      },
                      isDark: isDark,
                    ),

                    const SizedBox(height: 20),
                    _buildToolSectionHeader('PRODUCTIVIDAD & ENFOQUE', isDark),
                    const SizedBox(height: 10),
                    _buildToolTile(
                      icon: Icons.timer_outlined,
                      color: AppTheme.primaryDark,
                      title: 'Temporizador Pomodoro & Enfoque',
                      subtitle: 'Ciclos de 25 min + música ambiental',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const PomodoroScreen()));
                      },
                      isDark: isDark,
                    ),
                    _buildToolTile(
                      icon: Icons.analytics_outlined,
                      color: AppTheme.accentTeal,
                      title: 'Dashboard & Analítica',
                      subtitle: 'Gráficos de eficiencia y reportes PDF',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const AnalyticsScreen()));
                      },
                      isDark: isDark,
                    ),
                    _buildToolTile(
                      icon: Icons.emoji_events_outlined,
                      color: Colors.amber,
                      title: 'Misiones RPG & Insignias',
                      subtitle: 'Reclama XP y desbloquea medallas',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const QuestsScreen()));
                      },
                      isDark: isDark,
                    ),
                    _buildToolTile(
                      icon: Icons.view_kanban_outlined,
                      color: Colors.blueAccent,
                      title: 'Tablero Kanban',
                      subtitle: 'Organiza por columnas (Por Hacer / Hecho)',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const KanbanScreen()));
                      },
                      isDark: isDark,
                    ),

                    const SizedBox(height: 20),
                    _buildToolSectionHeader('BIENESTAR & CONFIGURACIÓN', isDark),
                    const SizedBox(height: 10),
                    _buildToolTile(
                      icon: Icons.mood_outlined,
                      color: Colors.purpleAccent,
                      title: 'Registro de Ánimo (Mood Tracker)',
                      subtitle: 'Seguimiento emocional diario',
                      onTap: () {
                        Navigator.of(context).pop();
                        showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => const MoodTrackerSheet());
                      },
                      isDark: isDark,
                    ),
                    _buildToolTile(
                      icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: AppTheme.primaryDark,
                      title: isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
                      subtitle: 'Alternar colores de interfaz',
                      onTap: () {
                        Navigator.of(context).pop();
                        ref.read(appThemeModeProvider.notifier).toggleTheme();
                      },
                      isDark: isDark,
                    ),
                    _buildToolTile(
                      icon: Icons.sync_rounded,
                      color: AppTheme.accentTeal,
                      title: 'Sincronizar Nube Ahora',
                      subtitle: 'Guardar cambios en backend Render',
                      onTap: () {
                        Navigator.of(context).pop();
                        _syncData();
                      },
                      isDark: isDark,
                    ),

                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: ListTile(
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
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: AppTheme.primaryDark,
      ),
    );
  }

  Widget _buildToolTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDarkElevated : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
        ),
      ),
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
      _buildRemindersBody(context, filteredReminders, isDark, usernameAsync, reminders),
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
    List<ReminderModel> filteredReminders,
    bool isDark,
    AsyncValue<String> usernameAsync,
    List<ReminderModel> allReminders,
  ) {
    final monthName = DateFormat('MMMM yyyy', 'es_US').format(_selectedDate);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. CLEAN TOP BAR HEADER: Avatar + Name on left, ONE PROMINENT 3-DOTS BUTTON on right!
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showToolsMenu(context, isDark),
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
                const SizedBox(width: 12),
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
                // Prominent Stylish 3-Dots Button
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.more_vert_rounded, color: AppTheme.primaryDark, size: 24),
                    onPressed: () => _showToolsMenu(context, isDark),
                    tooltip: 'Menú de Herramientas y Opciones',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. LIVE GPS WEATHER WIDGET
            const WeatherWidget(),
            const SizedBox(height: 16),

            // 3. OVERHAULED CALENDAR DATE STRIP HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: Row(
                    children: [
                      Text(
                        monthName[0].toUpperCase() + monthName.substring(1),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.primaryDark),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark.withValues(alpha: 0.2),
                    foregroundColor: AppTheme.primaryDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.today_rounded, size: 16),
                  label: const Text('Hoy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime.now();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // LUXURY HORIZONTAL CALENDAR STRIP
            SizedBox(
              height: 84,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 21,
                itemBuilder: (context, index) {
                  final day = DateTime.now().subtract(const Duration(days: 2)).add(Duration(days: index));
                  final isSelected = day.year == _selectedDate.year &&
                      day.month == _selectedDate.month &&
                      day.day == _selectedDate.day;

                  final dayName = DateFormat('EEE', 'es_US').format(day).toUpperCase();
                  final dayNumber = DateFormat('d').format(day);

                  // Check if any reminder is scheduled for this day
                  final hasTasksOnDay = allReminders.any((r) =>
                      r.dueDate.year == day.year &&
                      r.dueDate.month == day.month &&
                      r.dueDate.day == day.day);

                  return Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = day;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 62,
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [Color(0xFF38BDF8), Color(0xFF2DD4BF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isSelected
                              ? null
                              : (isDark ? AppTheme.surfaceDark : Colors.white),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark ? AppTheme.glassBorder : Colors.grey[200]!),
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryDark.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.black.withValues(alpha: 0.15)
                                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                dayName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.black
                                      : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              dayNumber,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.black
                                    : (isDark ? Colors.white : AppTheme.textPrimaryLight),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Glowing Dot Indicator for tasks
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasTasksOnDay
                                    ? (isSelected ? Colors.black : AppTheme.accentTeal)
                                    : Colors.transparent,
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

            // 4. CATEGORY CHIPS
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

            // 5. REMINDERS LIST WITH FULL EDIT & DELETE CRUD OPTIONS
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
                                color: reminder.priority == 'alta'
                                    ? Colors.redAccent
                                    : (isDark ? AppTheme.glassBorder : Colors.grey[200]!),
                                width: reminder.priority == 'alta' ? 1.5 : 1,
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
                                      if (reminder.estimatedCost != null) ...[
                                        Text(
                                          '\$${reminder.estimatedCost!.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryDark,
                                          ),
                                        ),
                                      ],
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
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (ctx) => EditReminderSheet(reminder: reminder),
                                    );
                                  } else if (val == 'delete') {
                                    ref.read(remindersProvider.notifier).deleteReminder(reminder.id);
                                    AppToast.show(context, message: 'Recordatorio eliminado', type: AppToastType.warning);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryDark),
                                        SizedBox(width: 8),
                                        Text('Editar'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                        SizedBox(width: 8),
                                        Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                                      ],
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
          ],
        ),
      ),
    );
  }
}
