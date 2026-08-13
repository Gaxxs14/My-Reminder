import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';

class MoodTrackerSheet extends ConsumerStatefulWidget {
  const MoodTrackerSheet({super.key});

  @override
  ConsumerState<MoodTrackerSheet> createState() => _MoodTrackerSheetState();
}

class _MoodTrackerSheetState extends ConsumerState<MoodTrackerSheet> {
  String _selectedMood = 'Feliz';
  final _noteController = TextEditingController();

  final List<Map<String, String>> _moods = [
    {'name': 'Motivado', 'emoji': '🚀'},
    {'name': 'Feliz', 'emoji': '🤩'},
    {'name': 'Enfocado', 'emoji': '🧠'},
    {'name': 'Tranquilo', 'emoji': '😌'},
    {'name': 'Cansado', 'emoji': '🥱'},
    {'name': 'Estresado', 'emoji': '😤'},
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _saveMood() {
    AppToast.show(
      context,
      message: '¡Ánimo registrado: $_selectedMood! (+10 XP)',
      type: AppToastType.success,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Text(
            '¿Cómo te sientes hoy?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Registra tu bienestar para relacionarlo con tu rendimiento',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Mood Emoji Chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _moods.map((m) {
              final isSelected = _selectedMood == m['name'];
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedMood = m['name']!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryDark.withValues(alpha: 0.2)
                        : (isDark ? AppTheme.surfaceDarkElevated : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryDark : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(m['emoji']!, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        m['name']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppTheme.primaryDark : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: 'Escribe una breve nota sobre tu día (opcional)...',
              filled: true,
              fillColor: isDark ? AppTheme.surfaceDarkElevated : Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _saveMood,
              child: const Text('Guardar Registro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
