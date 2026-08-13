import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import 'workspaces_provider.dart';
import '../data/workspace_model.dart';

class WorkspacesScreen extends ConsumerStatefulWidget {
  const WorkspacesScreen({super.key});

  @override
  ConsumerState<WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends ConsumerState<WorkspacesScreen> {
  final _nameController = TextEditingController();
  final _inviteController = TextEditingController();
  bool _isSyncing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _syncWorkspaces() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(workspacesProvider.notifier).syncWithCloud();
      if (mounted) {
        AppToast.show(context, message: '¡Espacios y tareas compartidas sincronizadas!', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Error de sincronización: $e', type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Nuevo Espacio Colaborativo',
            style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight, fontWeight: FontWeight.bold),
          ),
          content: AppTextField(
            controller: _nameController,
            labelText: 'Nombre del Espacio',
            hintText: 'ej. Finanzas del Hogar, Trabajo de Grado',
            prefixIcon: Icons.group_work_outlined,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _nameController.clear();
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
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isNotEmpty) {
                  await ref.read(workspacesProvider.notifier).createWorkspace(name);
                  _nameController.clear();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    AppToast.show(context, message: '¡Espacio colaborativo creado!', type: AppToastType.success);
                  }
                }
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  void _showWorkspaceDetails(WorkspaceModel workspace) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final notifier = ref.read(workspacesProvider.notifier);

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            workspace.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryDark.withValues(alpha: 0.2),
                            foregroundColor: AppTheme.primaryDark,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.sync_rounded, size: 16),
                          label: const Text('Sync', style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            await notifier.syncWorkspaceReminders(workspace.id);
                            if (context.mounted) {
                              AppToast.show(context, message: '¡Tareas del espacio actualizadas!', type: AppToastType.success);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Members List Section
                    Text(
                      'Miembros del Equipo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<WorkspaceMemberModel>>(
                      future: notifier.getMembers(workspace.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final members = snapshot.data ?? [];
                        if (members.isEmpty) {
                          return const Text('Solo tú estás en este espacio.');
                        }
                        return SizedBox(
                          height: 120,
                          child: ListView.builder(
                            itemCount: members.length,
                            itemBuilder: (context, idx) {
                              final member = members[idx];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryDark.withValues(alpha: 0.15),
                                  child: Text(
                                    member.username.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  member.username,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Invite Section
                    Text(
                      'Invitar a Colaborar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _inviteController,
                            labelText: 'Nombre de Usuario',
                            hintText: 'ej. juan123',
                            prefixIcon: Icons.person_add_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryDark,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            final userToInvite = _inviteController.text.trim();
                            if (userToInvite.isEmpty) {
                              AppToast.show(context, message: 'Falta ingresar usuario', type: AppToastType.warning);
                              return;
                            }
                            final res = await notifier.inviteMember(workspace.id, userToInvite);
                            if (context.mounted) {
                              if (res['success'] == true) {
                                AppToast.show(context, message: res['message'] as String, type: AppToastType.success);
                                _inviteController.clear();
                                setModalState(() {});
                              } else {
                                AppToast.show(context, message: res['message'] as String, type: AppToastType.error);
                              }
                            }
                          },
                          child: const Text('Invitar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final workspaces = ref.watch(workspacesProvider);

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
                        'Espacios Compartidos',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Colabora en tiempo real con tu equipo',
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
                          onPressed: _syncWorkspaces,
                        ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. WORKSPACES LIST
              Expanded(
                child: workspaces.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_work_outlined,
                              size: 64,
                              color: isDark ? Colors.white12 : Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '¿Qué tal si creamos un espacio?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Comparte tareas y organizate en equipo.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white30 : Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: workspaces.length,
                        itemBuilder: (context, index) {
                          final ws = workspaces[index];
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
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryDark.withValues(alpha: 0.15),
                                  child: const Icon(Icons.groups_rounded, color: AppTheme.primaryDark),
                                ),
                                title: Text(
                                  ws.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Espacio Compartido',
                                  style: TextStyle(fontSize: 12),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                                onTap: () => _showWorkspaceDetails(ws),
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
          onPressed: _showCreateDialog,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }
}
