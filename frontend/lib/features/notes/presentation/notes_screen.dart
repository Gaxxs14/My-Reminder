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

  bool _isAiSearch = false;
  bool _isSyncing = false;
  bool _isSearching = false;
  List<SemanticMatch> _searchResults = [];

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

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await ref.read(notesProvider.notifier).searchSemantically(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Error buscando notas: $e', type: AppToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _showNoteEditor({NoteModel? note}) {
    if (note != null) {
      _titleController.text = note.title;
      _contentController.text = note.content;
    } else {
      _titleController.clear();
      _contentController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
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
                  note == null ? 'Nueva Nota' : 'Editar Nota',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _titleController,
                  labelText: 'Título',
                  hintText: 'ej. Clave de la oficina',
                  prefixIcon: Icons.title,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contentController,
                  maxLines: 8,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Contenido',
                    hintText: 'Escribe tu nota aquí...',
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryDark,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          final title = _titleController.text.trim();
                          final content = _contentController.text.trim();

                          if (title.isEmpty || content.isEmpty) {
                            AppToast.show(context, message: 'El título y contenido son obligatorios', type: AppToastType.warning);
                            return;
                          }

                          if (note == null) {
                            ref.read(notesProvider.notifier).addNote(title, content);
                            AppToast.show(context, message: 'Nota guardada', type: AppToastType.success);
                          } else {
                            final updated = note.copyWith(title: title, content: content);
                            ref.read(notesProvider.notifier).updateNote(updated);
                            AppToast.show(context, message: 'Nota actualizada', type: AppToastType.success);
                          }

                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Guardar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notes = ref.watch(notesProvider);

    final showSearchResults = _searchController.text.trim().isNotEmpty;
    final displayedItems = showSearchResults ? _searchResults : notes.map((n) => SemanticMatch(note: n, relevanceReason: '')).toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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
                        'Notas Inteligentes',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bloc de notas con búsqueda semántica IA',
                        style: TextStyle(
                          fontSize: 14,
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
              const SizedBox(height: 20),

              // 2. SEARCH BAR WITH IA SWITCH
              Card(
                elevation: 0,
                color: isDark ? AppTheme.surfaceDark : Colors.grey[100],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                          decoration: const InputDecoration(
                            hintText: 'Buscar notas...',
                            border: InputBorder.none,
                            icon: Icon(Icons.search),
                          ),
                          onChanged: (val) {
                            if (val.trim().isEmpty) {
                              setState(() {
                                _searchResults = [];
                              });
                            }
                          },
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                      // AI Toggle Button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isAiSearch = !_isAiSearch;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isAiSearch
                                ? AppTheme.primaryDark.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isAiSearch ? AppTheme.primaryDark : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: _isAiSearch ? AppTheme.primaryDark : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Búsqueda IA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _isAiSearch ? AppTheme.primaryDark : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _performSearch,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. NOTES LIST
              Expanded(
                child: _isSearching
                    ? const Center(child: GaxxsLoader(showBrandName: false, size: 48))
                    : displayedItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.article_outlined,
                                  size: 64,
                                  color: isDark ? Colors.white24 : Colors.grey[300],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  showSearchResults ? 'No se encontraron resultados' : 'No tienes notas guardadas',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white54 : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: displayedItems.length,
                            itemBuilder: (context, index) {
                              final match = displayedItems[index];
                              final note = match.note;
                              final hasReason = match.relevanceReason.isNotEmpty && _isAiSearch && showSearchResults;

                              return GestureDetector(
                                onTap: () => _showNoteEditor(note: note),
                                child: Card(
                                  elevation: isDark ? 0 : 2,
                                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: hasReason
                                          ? AppTheme.primaryDark
                                          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!),
                                      width: hasReason ? 1.8 : 1.0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                note.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                              onPressed: () {
                                                ref.read(notesProvider.notifier).deleteNote(note.id);
                                                AppToast.show(context, message: 'Nota eliminada', type: AppToastType.warning);
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Expanded(
                                          child: Text(
                                            note.content,
                                            maxLines: hasReason ? 2 : 5,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark ? Colors.white70 : Colors.black54,
                                            ),
                                          ),
                                        ),
                                        if (hasReason) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryDark.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              match.relevanceReason,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.primaryDark,
                                                fontWeight: FontWeight.w600,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
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
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showNoteEditor(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
