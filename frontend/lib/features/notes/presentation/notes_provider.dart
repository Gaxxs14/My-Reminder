import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/global_providers.dart';
import '../data/note_model.dart';
import '../data/local_note_repository.dart';

final notesProvider = StateNotifierProvider<NotesNotifier, List<NoteModel>>((ref) {
  final repo = ref.watch(localNoteRepositoryProvider);
  return NotesNotifier(repo, ref);
});

class SemanticMatch {
  final NoteModel note;
  final String relevanceReason;

  SemanticMatch({required this.note, required this.relevanceReason});
}

class NotesNotifier extends StateNotifier<List<NoteModel>> {
  final LocalNoteRepository _repository;
  final Ref _ref;

  NotesNotifier(this._repository, this._ref) : super([]) {
    loadNotes();
  }

  // Load all notes from local cache
  Future<void> loadNotes() async {
    try {
      final list = await _repository.getNotes();
      state = list;
    } catch (_) {
      state = [];
    }
  }

  // Create a new note
  Future<void> addNote(String title, String content) async {
    final uuid = const Uuid().v4();
    final newNote = NoteModel(
      id: uuid,
      title: title,
      content: content,
      isSynced: false,
    );

    await _repository.insertNote(newNote);
    state = [newNote, ...state];

    _syncImmediately(newNote);
  }

  // Update existing note
  Future<void> updateNote(NoteModel note) async {
    final updated = note.copyWith(isSynced: false);
    await _repository.updateNote(updated);

    state = [
      for (final n in state)
        if (n.id == note.id) updated else n
    ];

    _syncImmediately(updated);
  }

  // Delete note
  Future<void> deleteNote(String id) async {
    try {
      await _repository.deleteNote(id);
      state = state.where((n) => n.id != id).toList();

      final apiClient = _ref.read(apiClientProvider);
      await apiClient.delete('/api/notes/$id');
    } catch (_) {
      // Offline support: deletion remains successful in SQLite cache
    }
  }

  // Bidirectional cloud sync
  Future<void> syncWithCloud() async {
    try {
      final unsynced = await _repository.getUnsyncedNotes();
      final body = unsynced.map((n) => n.toJson()).toList();

      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.post('/api/notes/sync', data: body);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        final serverList = data.map((json) {
          return NoteModel.fromJson(Map<String, dynamic>.from(json as Map));
        }).toList();

        await _repository.clearAndReplace(serverList);
        state = serverList;
      }
    } catch (_) {
      rethrow;
    }
  }

  // Search notes semantically using Gemini through the C# backend
  Future<List<SemanticMatch>> searchSemantically(String query) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.get('/api/notes/search', queryParameters: {'query': query});

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        return data.map((item) {
          final mapItem = Map<String, dynamic>.from(item as Map);
          final noteJson = Map<String, dynamic>.from(mapItem['note'] as Map);
          
          return SemanticMatch(
            note: NoteModel.fromJson(noteJson),
            relevanceReason: mapItem['relevanceReason'] as String? ?? '',
          );
        }).toList();
      }
      return [];
    } catch (e) {
      // Fallback: local basic title/content search (without relevance explanation)
      final lowercaseQuery = query.toLowerCase();
      final localMatches = state.where((n) {
        return n.title.toLowerCase().contains(lowercaseQuery) ||
            n.content.toLowerCase().contains(lowercaseQuery);
      }).toList();

      return localMatches.map((n) {
        return SemanticMatch(
          note: n,
          relevanceReason: 'Búsqueda local coincidente por texto.',
        );
      }).toList();
    }
  }

  // Trigger immediate push for a new/edited note
  Future<void> _syncImmediately(NoteModel note) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.post('/api/notes', data: note.toJson());
      if (response.statusCode == 200) {
        final updated = note.copyWith(isSynced: true);
        await _repository.updateNote(updated);
        
        state = [
          for (final n in state)
            if (n.id == note.id) updated else n
        ];
      }
    } catch (_) {
      // Will sync on next full sync pass
    }
  }
}
