import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/global_providers.dart';
import '../data/habit_model.dart';
import '../data/local_habit_repository.dart';

final habitsProvider = StateNotifierProvider<HabitsNotifier, List<HabitModel>>((ref) {
  final repo = ref.watch(localHabitRepositoryProvider);
  return HabitsNotifier(repo, ref);
});

class HabitsNotifier extends StateNotifier<List<HabitModel>> {
  final LocalHabitRepository _repository;
  final Ref _ref;

  HabitsNotifier(this._repository, this._ref) : super([]) {
    loadHabits();
  }

  // Load all habits from local cache
  Future<void> loadHabits() async {
    try {
      final list = await _repository.getHabits();
      state = list;
    } catch (_) {
      state = [];
    }
  }

  // Add a new habit
  Future<void> addHabit(String name, String frequency) async {
    final uuid = const Uuid().v4();
    final newHabit = HabitModel(
      id: uuid,
      name: name,
      frequency: frequency,
      streak: 0,
      points: 0,
      isSynced: false,
    );

    // Save locally
    await _repository.insertHabit(newHabit);
    state = [...state, newHabit];

    // Attempt to sync immediately with backend
    _syncImmediately(newHabit);
  }

  // Mark habit as completed for today
  Future<Map<String, dynamic>> completeHabit(String id) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      
      // Call backend to apply gamification logic (points, streaks)
      final response = await apiClient.post('/api/habits/$id/complete');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(response.data as Map);
        final habitJson = Map<String, dynamic>.from(data['habit'] as Map);
        final int pointsEarned = data['pointsEarned'] as int? ?? 0;
        final String message = data['message'] as String? ?? '';

        final updatedHabit = HabitModel.fromJson(habitJson);

        // Update local SQLite cache
        await _repository.updateHabit(updatedHabit);

        // Update local state
        state = [
          for (final h in state)
            if (h.id == id) updatedHabit else h
        ];

        return {
          'success': true,
          'pointsEarned': pointsEarned,
          'message': message,
          'streak': updatedHabit.streak
        };
      }
      return {'success': false, 'message': 'Error de respuesta del servidor.'};
    } catch (e) {
      // Fallback offline complete (simplified)
      final localHabit = state.firstWhere((h) => h.id == id);
      final today = DateTime.now();
      
      if (localHabit.lastCompleted?.day == today.day &&
          localHabit.lastCompleted?.month == today.month &&
          localHabit.lastCompleted?.year == today.year) {
        return {'success': false, 'message': 'Ya completaste este hábito hoy (modo local).'};
      }

      int newStreak = 1;
      if (localHabit.lastCompleted != null) {
        final diff = today.difference(localHabit.lastCompleted!).inDays;
        if (diff == 1) {
          newStreak = localHabit.streak + 1;
        }
      }

      final updatedLocal = localHabit.copyWith(
        streak: newStreak,
        lastCompleted: today,
        points: localHabit.points + 10,
        isSynced: false,
      );

      await _repository.updateHabit(updatedLocal);
      state = [
        for (final h in state)
          if (h.id == id) updatedLocal else h
      ];

      return {
        'success': true,
        'pointsEarned': 10,
        'message': '¡Completado localmente! (Se sincronizará en la nube)',
        'streak': newStreak
      };
    }
  }

  // Delete habit
  Future<void> deleteHabit(String id) async {
    try {
      await _repository.deleteHabit(id);
      state = state.where((h) => h.id != id).toList();

      final apiClient = _ref.read(apiClientProvider);
      await apiClient.delete('/api/habits/$id');
    } catch (_) {
      // Ignore network failures for deletion, keep SQLite updated
    }
  }

  // Bidirectional cloud sync
  Future<void> syncWithCloud() async {
    try {
      final unsynced = await _repository.getUnsyncedHabits();
      final body = unsynced.map((h) => h.toJson()).toList();

      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.post('/api/habits/sync', data: body);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        final serverList = data.map((json) {
          return HabitModel.fromJson(Map<String, dynamic>.from(json as Map));
        }).toList();

        await _repository.clearAndReplace(serverList);
        state = serverList;
      }
    } catch (_) {
      rethrow;
    }
  }

  // Trigger immediate push for a new habit
  Future<void> _syncImmediately(HabitModel habit) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.post('/api/habits', data: habit.toJson());
      if (response.statusCode == 200) {
        final updated = habit.copyWith(isSynced: true);
        await _repository.updateHabit(updated);
        
        state = [
          for (final h in state)
            if (h.id == habit.id) updated else h
        ];
      }
    } catch (_) {
      // Fails silently, will sync on next manual/auto sync cycle
    }
  }

  // Get total user points (sum of all habit points)
  int get totalPoints {
    return state.fold(0, (sum, habit) => sum + habit.points);
  }

  // Get dynamic level text and levels calculation
  Map<String, dynamic> get levelDetails {
    final pts = totalPoints;
    
    // Level is totalPoints / 100 + 1
    final level = (pts / 100).floor() + 1;
    final xpInCurrentLevel = pts % 100;
    
    String levelName = 'Iniciado';
    if (level >= 10) {
      levelName = 'Productividad Suprema 👑';
    } else if (level >= 7) {
      levelName = 'Máster de Hábitos 🌟';
    } else if (level >= 5) {
      levelName = 'Ejecutor Enfocado 🔥';
    } else if (level >= 3) {
      levelName = 'Organizador Pro ⚡';
    } else if (level >= 2) {
      levelName = 'Principiante Activo 🏃';
    }

    return {
      'level': level,
      'xp': xpInCurrentLevel,
      'levelName': levelName,
      'progress': xpInCurrentLevel / 100.0
    };
  }

  Future<void> addPoints(int pts) async {
    if (state.isNotEmpty) {
      final firstHabit = state.first;
      final updated = firstHabit.copyWith(points: firstHabit.points + pts);
      await _repository.updateHabit(updated);
      state = [
        updated,
        ...state.sublist(1),
      ];
    }
  }
}
