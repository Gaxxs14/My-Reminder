import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/gaxxs_loader.dart';
import '../data/note_model.dart';
import 'notes_provider.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _useAiSearch = false;
  bool _isSyncing = false;
  bool _isSearching = false;
  List<SemanticMatch>? _searchResults;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _syncNotes() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(notesProvider.notifier).syncWithCloud();
      if (mounted) {
        AppToast.show(context, message: '¡Notas sincronizadas con la nube!', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Error de sincronización: $e', type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await ref.read(notesProvider.notifier).searchSemantically(query.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _showAddNoteDialog({NoteModel? noteToEdit}) {
    if (noteToEdit != null) {
      _titleController.text = noteToEdit.title;
      _contentController.text = noteToEdit.content;
    }
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            noteToEdit != null ? 'Editar Nota' : 'Nueva Nota',
            style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: _titleController,
                labelText: 'Título de la Nota',
                hintText: 'ej. Ideas de Proyecto, Lista de Compras',
                prefixIcon: Icons.title_rounded,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _contentController,
                labelText: 'Contenido',
                hintText: 'Escribe los detalles aquí...',
                prefixIcon: Icons.notes_rounded,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _titleController.clear();
                _contentController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                final title = _titleController.text.trim();
                final content = _contentController.text.trim();
                if (title.isNotEmpty && content.isNotEmpty) {
                  if (noteToEdit != null) {
                    final updated = noteToEdit.copyWith(title: title, content: content, isSynced: false);
                    ref.read(notesProvider.notifier).updateNote(updated);
                    AppToast.show(context, message: '¡Nota actualizada!', type: AppToastType.success);
                  } else {
                    ref.read(notesProvider.notifier).addNote(title, content);
                    AppToast.show(context, message: '¡Nota guardada!', type: AppToastType.success);
                  }
                  _titleController.clear();
                  _contentController.clear();
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allNotes = ref.watch(notesProvider);
    final notifier = ref.read(notesProvider.notifier);

    final List<SemanticMatch> displayedMatches = _searchResults ??
        allNotes
            .map((n) => SemanticMatch(note: n, relevanceReason: ''))
            .toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 90.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notas Semánticas',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Encuentra tus ideas por concepto usando IA',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  _isSyncing
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryDark),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.sync_rounded),
                          onPressed: _syncNotes,
                        ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. SEARCH & AI SWITCH BAR
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _useAiSearch ? AppTheme.accentTeal : (isDark ? AppTheme.glassBorder : Colors.grey[200]!),
                    width: _useAiSearch ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _useAiSearch ? Icons.auto_awesome_rounded : Icons.search_rounded,
                      color: _useAiSearch ? AppTheme.accentTeal : (isDark ? Colors.white54 : Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _useAiSearch ? 'Buscar por idea o concepto (IA)...' : 'Buscar en notas...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) {
                          if (!_useAiSearch) {
                            _performSearch(val);
                          }
                        },
                        onSubmitted: (query) {
                          _performSearch(query);
                        },
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'IA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _useAiSearch ? AppTheme.accentTeal : (isDark ? Colors.white38 : Colors.grey),
                          ),
                        ),
                        Switch(
                          value: _useAiSearch,
                          activeTrackColor: AppTheme.accentTeal,
                          onChanged: (val) {
                            setState(() {
                              _useAiSearch = val;
                            });
                            if (_searchController.text.isNotEmpty) {
                              _performSearch(_searchController.text);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. NOTES CONTENT AREA
              Expanded(
                child: _isSearching
                    ? const Center(child: GaxxsLoader(showBrandName: false, size: 44))
                    : displayedMatches.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.article_outlined,
                                  size: 64,
                                  color: isDark ? Colors.white12 : Colors.grey[300],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No hay notas encontradas',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white54 : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Agrega tus notas o intenta con otro término.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white30 : Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: displayedMatches.length,
                            itemBuilder: (context, index) {
                              final match = displayedMatches[index];
                              final note = match.note;
                              final hasReason = match.relevanceReason.isNotEmpty;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: hasReason
                                          ? AppTheme.accentTeal
                                          : (isDark ? AppTheme.glassBorder : Colors.grey[200]!),
                                      width: hasReason ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              note.title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                            onPressed: () {
                                              notifier.deleteNote(note.id);
                                              AppToast.show(context, message: 'Nota eliminada', type: AppToastType.warning);
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        note.content,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                        ),
                                      ),
                                      if (hasReason) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentTeal.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.accentTeal),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  match.relevanceReason,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.accentTeal,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72.0),
        child: FloatingActionButton(
          backgroundColor: AppTheme.primaryDark,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onPressed: _showAddNoteDialog,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }
}
