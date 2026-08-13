import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/sync_service.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/notification_service.dart';
import '../data/local_reminder_repository.dart';
import '../data/reminder_model.dart';

final remindersProvider = StateNotifierProvider<RemindersNotifier, List<ReminderModel>>((ref) {
  final repo = ref.watch(localReminderRepositoryProvider);
  final notifierService = ref.watch(notificationServiceProvider);
  final syncService = ref.watch(syncServiceProvider);
  return RemindersNotifier(repo, notifierService, syncService);
});

class RemindersNotifier extends StateNotifier<List<ReminderModel>> {
  final LocalReminderRepository _repository;
  final NotificationService _notificationService;
  final SyncService _syncService;

  RemindersNotifier(this._repository, this._notificationService, this._syncService) : super([]) {
    loadReminders();
  }

  // Load all reminders from local DB
  Future<void> loadReminders() async {
    try {
      final list = await _repository.getReminders();
      state = list;
    } catch (_) {
      state = [];
    }
  }

  // Add a new reminder
  Future<void> addReminder(ReminderModel reminder) async {
    await _repository.insertReminder(reminder);
    
    // Schedule exact physical device alarm
    await _notificationService.scheduleNotification(
      id: reminder.id,
      title: reminder.title,
      body: reminder.description ?? 'Tienes un compromiso pendiente ahora.',
      scheduledTime: reminder.dueDate,
    );

    state = [...state, reminder]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  // Toggle completed status
  Future<void> toggleReminderStatus(String id) async {
    state = [
      for (final r in state)
        if (r.id == id)
          r.copyWith(
            status: r.status == 'completed' ? 'pending' : 'completed',
            isSynced: false, // Mark for sync again
          )
        else
          r
    ];

    final updated = state.firstWhere((r) => r.id == id);
    await _repository.updateReminder(updated);

    // If completed, cancel notification. If pending, reschedule if in the future
    if (updated.status == 'completed') {
      await _notificationService.cancelNotification(id);
    } else {
      await _notificationService.scheduleNotification(
        id: updated.id,
        title: updated.title,
        body: updated.description ?? 'Tienes un compromiso pendiente ahora.',
        scheduledTime: updated.dueDate,
      );
    }
  }

  // Delete a reminder
  Future<void> deleteReminder(String id) async {
    await _repository.deleteReminder(id);
    await _notificationService.cancelNotification(id);
    state = state.where((r) => r.id != id).toList();
  }

  // Update an existing reminder
  Future<void> updateReminder(ReminderModel updated) async {
    await _repository.updateReminder(updated);
    await _notificationService.scheduleNotification(
      id: updated.id,
      title: updated.title,
      body: updated.description ?? 'Tienes un compromiso pendiente ahora.',
      scheduledTime: updated.dueDate,
    );
    state = [
      for (final r in state)
        if (r.id == updated.id) updated else r
    ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  // Sync state with cloud database
  Future<void> syncWithCloud() async {
    try {
      final consolidated = await _syncService.syncReminders();
      state = consolidated..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    } catch (e) {
      rethrow;
    }
  }

  // Inject synced server reminders manually if needed
  void setReminders(List<ReminderModel> newList) {
    state = newList..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }
}
