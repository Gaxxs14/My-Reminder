import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../reminders/presentation/reminders_provider.dart';
import '../../habits/presentation/habits_provider.dart';
import '../../notes/presentation/notes_provider.dart';
import '../../workspaces/presentation/workspaces_provider.dart';

class GlobalSearchSheet extends ConsumerStatefulWidget {
  const GlobalSearchSheet({super.key});

  @override
  ConsumerState<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends ConsumerState<GlobalSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reminders = ref.watch(remindersProvider);
    final habits = ref.watch(habitsProvider);
    final notes = ref.watch(notesProvider);
    final workspaces = ref.watch(workspacesProvider);

    final matchingReminders = _query.isEmpty
        ? []
        : reminders.where((r) => r.title.toLowerCase().contains(_query.toLowerCase())).toList();
    final matchingHabits = _query.isEmpty
        ? []
        : habits.where((h) => h.name.toLowerCase().contains(_query.toLowerCase())).toList();
    final matchingNotes = _query.isEmpty
        ? []
        : notes.where((n) => n.title.toLowerCase().contains(_query.toLowerCase()) || n.content.toLowerCase().contains(_query.toLowerCase())).toList();
    final matchingWorkspaces = _query.isEmpty
        ? []
        : workspaces.where((w) => w.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
            decoration: InputDecoration(
              hintText: 'Buscar tareas, hábitos, notas, equipos...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryDark),
              filled: true,
              fillColor: isDark ? AppTheme.surfaceDarkElevated : Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (val) {
              setState(() => _query = val);
            },
          ),
          const SizedBox(height: 16),

          // Results List
          Expanded(
            child: _query.isEmpty
                ? const Center(
                    child: Text('Escribe para buscar en todo el sistema', style: TextStyle(color: Colors.grey)),
                  )
                : ListView(
                    children: [
                      if (matchingReminders.isNotEmpty) ...[
                        const Text('TAREAS & COMPROMISOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                        const SizedBox(height: 8),
                        ...matchingReminders.map((r) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.check_circle_outline, color: AppTheme.primaryDark),
                              title: Text(r.title, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                              subtitle: Text(r.category),
                            )),
                        const Divider(height: 16),
                      ],
                      if (matchingHabits.isNotEmpty) ...[
                        const Text('HÁBITOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
                        const SizedBox(height: 8),
                        ...matchingHabits.map((h) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.spa, color: AppTheme.accentTeal),
                              title: Text(h.name, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                              subtitle: Text('Racha: ${h.streak} días'),
                            )),
                        const Divider(height: 16),
                      ],
                      if (matchingNotes.isNotEmpty) ...[
                        const Text('NOTAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                        const SizedBox(height: 8),
                        ...matchingNotes.map((n) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.article, color: Colors.purpleAccent),
                              title: Text(n.title, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                              subtitle: Text(n.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                            )),
                        const Divider(height: 16),
                      ],
                      if (matchingWorkspaces.isNotEmpty) ...[
                        const Text('EQUIPOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                        const SizedBox(height: 8),
                        ...matchingWorkspaces.map((w) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.groups, color: Colors.orange),
                              title: Text(w.name, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                            )),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
