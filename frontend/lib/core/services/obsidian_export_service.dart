import 'dart:io';

import 'package:path/path.dart' as p;

import '../../features/habits/data/habit_model.dart';
import '../../features/habits/data/local_habit_repository.dart';
import '../../features/notes/data/local_note_repository.dart';
import '../../features/notes/data/note_model.dart';
import '../../features/reminders/data/local_reminder_repository.dart';
import '../../features/reminders/data/reminder_model.dart';

class ObsidianExportResult {
  final int notesExported;
  final int remindersExported;
  final int habitsExported;
  final String exportPath;

  ObsidianExportResult({
    required this.notesExported,
    required this.remindersExported,
    required this.habitsExported,
    required this.exportPath,
  });
}

class ObsidianExportService {
  final LocalNoteRepository _noteRepository;
  final LocalReminderRepository _reminderRepository;
  final LocalHabitRepository _habitRepository;

  static const String notesFolderName = 'Notas';

  static const List<String> _ownedFiles = [
    'Recordatorios.md',
    'Hábitos.md',
    notesFolderName,
  ];

  ObsidianExportService({
    required LocalNoteRepository noteRepository,
    required LocalReminderRepository reminderRepository,
    required LocalHabitRepository habitRepository,
  }) : _noteRepository = noteRepository,
       _reminderRepository = reminderRepository,
       _habitRepository = habitRepository;

  Future<ObsidianExportResult> exportToVault(String vaultRootPath) async {
    final vaultRoot = Directory(vaultRootPath);
    if (!vaultRoot.existsSync()) {
      throw StateError('La carpeta del vault no existe: $vaultRootPath');
    }

    // Limpiar SOLO lo que la app genera (respeta .obsidian, Bienvenido.md y demás).
    for (final name in _ownedFiles) {
      final path = p.join(vaultRoot.path, name);
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.notFound) continue;
      if (type == FileSystemEntityType.directory) {
        Directory(path).deleteSync(recursive: true);
      } else {
        File(path).deleteSync();
      }
    }

    final notesDir = Directory(p.join(vaultRoot.path, notesFolderName));
    notesDir.createSync(recursive: true);

    var notesCount = 0;
    final notes = await _noteRepository.getNotes();
    for (final note in notes) {
      final fileName =
          '${_safeFileName(_formatDate(note.createdAt))}-${_safeFileName(note.title)}.md';
      File(p.join(notesDir.path, fileName)).writeAsStringSync(
        _noteToMarkdown(note),
        flush: true,
      );
      notesCount++;
    }

    final reminders = await _reminderRepository.getReminders();
    File(p.join(vaultRoot.path, 'Recordatorios.md')).writeAsStringSync(
      _remindersToMarkdown(reminders),
      flush: true,
    );

    final habits = await _habitRepository.getHabits();
    File(p.join(vaultRoot.path, 'Hábitos.md')).writeAsStringSync(
      _habitsToMarkdown(habits),
      flush: true,
    );

    return ObsidianExportResult(
      notesExported: notesCount,
      remindersExported: reminders.length,
      habitsExported: habits.length,
      exportPath: vaultRoot.path,
    );
  }

  String _noteToMarkdown(NoteModel note) {
    return '---\n'
        'title: "${_escapeYaml(note.title)}"\n'
        'created: ${note.createdAt.toIso8601String()}\n'
        'source: My-Reminder\n'
        '---\n\n'
        '${note.content.trim()}\n';
  }

  String _remindersToMarkdown(List<ReminderModel> reminders) {
    final buffer = StringBuffer()
      ..writeln('# Recordatorios de My-Reminder')
      ..writeln()
      ..writeln('_Exportado desde My-Reminder el ${_formatDate(DateTime.now())}_')
      ..writeln();

    final pending = reminders.where((r) => r.status != 'completed').toList();
    final completed = reminders.where((r) => r.status == 'completed').toList();

    if (pending.isNotEmpty) {
      buffer
        ..writeln('## Pendientes')
        ..writeln();
      for (final reminder in pending) {
        _writeTask(buffer, reminder, checked: false);
      }
      buffer.writeln();
    }

    if (completed.isNotEmpty) {
      buffer
        ..writeln('## Completados')
        ..writeln();
      for (final reminder in completed) {
        _writeTask(buffer, reminder, checked: true);
      }
    }

    if (reminders.isEmpty) {
      buffer.writeln('_No hay recordatorios._');
    }

    return buffer.toString();
  }

  void _writeTask(StringBuffer buffer, ReminderModel reminder, {required bool checked}) {
    final box = checked ? '[x]' : '[ ]';
    final category = reminder.category.trim().isEmpty
        ? 'General'
        : reminder.category.trim();
    final priority = switch (reminder.priority) {
      'alta' => '🔴',
      'baja' => '🟢',
      _ => '🟡',
    };

    buffer
      ..write('- $box $priority ${reminder.title}')
      ..write(' 📅 ${_formatDate(reminder.dueDate)}')
      ..writeln(' 🕐 ${_formatTime(reminder.dueDate)} 🏷 $category');

    for (final subtask in reminder.subtasks) {
      buffer.writeln('  - [ ] $subtask');
    }
    if (reminder.description != null && reminder.description!.trim().isNotEmpty) {
      buffer.writeln('  > ${reminder.description!.trim()}');
    }
  }

  String _habitsToMarkdown(List<HabitModel> habits) {
    final buffer = StringBuffer()
      ..writeln('# Hábitos de My-Reminder')
      ..writeln()
      ..writeln('_Exportado desde My-Reminder el ${_formatDate(DateTime.now())}_')
      ..writeln();

    if (habits.isEmpty) {
      buffer.writeln('_No hay hábitos registrados._');
      return buffer.toString();
    }

    final daily = habits.where((h) => h.frequency == 'daily').toList();
    final weekly = habits.where((h) => h.frequency != 'daily').toList();

    if (daily.isNotEmpty) {
      buffer
        ..writeln('## Diarios')
        ..writeln();
      for (final habit in daily) {
        buffer.writeln('- [ ] ${habit.name} — racha: ${habit.streak} ${habit.streak == 1 ? 'día' : 'días'}');
      }
      buffer.writeln();
    }

    if (weekly.isNotEmpty) {
      buffer
        ..writeln('## Semanales')
        ..writeln();
      for (final habit in weekly) {
        buffer.writeln('- [ ] ${habit.name} — racha: ${habit.streak} ${habit.streak == 1 ? 'semana' : 'semanas'}');
      }
    }

    return buffer.toString();
  }

  String _escapeYaml(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

  String _safeFileName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final name = cleaned.isEmpty ? 'sin-titulo' : cleaned;
    return name.length > 60 ? name.substring(0, 60) : name;
  }

  String _formatDate(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}';
  }

  String _formatTime(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dateTime.hour)}:${two(dateTime.minute)}';
  }
}
