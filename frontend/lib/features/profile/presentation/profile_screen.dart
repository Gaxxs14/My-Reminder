import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/app_toast.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _selectedAvatar = '👤';
  String? _profileImagePath;
  bool _biometricsEnabled = false;
  bool _isSyncing = false;
  final ImagePicker _imagePicker = ImagePicker();

  final List<String> _avatarOptions = [
    '👤', '🧑‍💻', '🦁', '⚡', '💎', '👑', '🚀', '🦊', '🦸', '🔥', '🎯', '🌟'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final storage = ref.read(secureStorageProvider);
    final avatar = await storage.read('user_avatar') ?? '👤';
    final imagePath = await storage.read('user_photo_path');
    final token = await storage.getToken();
    final bioPref = await storage.read('biometrics_enabled');

    setState(() {
      _selectedAvatar = avatar;
      _profileImagePath = (imagePath != null && File(imagePath).existsSync()) ? imagePath : null;
      _biometricsEnabled = bioPref != null ? (bioPref == 'true') : (token != null);
    });
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      await ref.read(secureStorageProvider).write('user_photo_path', picked.path);
      setState(() => _profileImagePath = picked.path);
      if (mounted) {
        AppToast.show(context, message: '¡Foto de perfil actualizada!', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Error al seleccionar foto: $e', type: AppToastType.error);
      }
    }
  }

  void _showImagePickerOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Foto de Perfil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryDark),
              title: const Text('Tomar Foto con Cámara'),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfileImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppTheme.accentTeal),
              title: const Text('Elegir de Galería'),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfileImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAvatar(String emoji) async {
    await ref.read(secureStorageProvider).write('user_avatar', emoji);
    await ref.read(secureStorageProvider).delete('user_photo_path');
    setState(() {
      _selectedAvatar = emoji;
      _profileImagePath = null;
    });
    if (mounted) {
      AppToast.show(context, message: '¡Avatar de emoji seleccionado!', type: AppToastType.success);
    }
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncServiceProvider).syncReminders();
      if (mounted) {
        AppToast.show(context, message: '¡Sincronizado con la nube Render!', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Error de sincronización: $e', type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 10),
              Text('Eliminar Cuenta', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar tu usuario completamente?\n\nEsta acción borrará de forma permanente todas tus tareas, hábitos, notas y datos de la nube.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                try {
                  final apiClient = ref.read(apiClientProvider);
                  await apiClient.delete('/api/auth/account');
                } catch (_) {
                  // Offline support
                }

                // Clear all local SQLite cached data
                await DbHelper().clearAllData();

                // Clear all secure storage tokens & preferences
                final storage = ref.read(secureStorageProvider);
                await storage.clearAll();

                // Instantly logout and redirect to Login
                await ref.read(authStateProvider.notifier).logout();
                if (mounted) {
                  AppToast.show(context, message: 'Tu cuenta ha sido eliminada permanentemente.', type: AppToastType.warning);
                }
              },
              child: const Text('Sí, Eliminar Cuenta'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. HEADER TITLE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mi Perfil & Ajustes',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: AppTheme.primaryDark,
                    ),
                    onPressed: () {
                      ref.read(appThemeModeProvider.notifier).toggleTheme();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. AVATAR PICKER CARD
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppTheme.surfaceDark : Colors.white,
                        border: Border.all(color: AppTheme.primaryDark, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryDark.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _profileImagePath != null
                            ? Image.file(File(_profileImagePath!), fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  _selectedAvatar,
                                  style: const TextStyle(fontSize: 48),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.black),
                          onPressed: _showImagePickerOptions,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // USERNAME DISPLAY
              Consumer(
                builder: (context, ref, child) {
                  final usernameAsync = ref.watch(usernameProvider);
                  return usernameAsync.when(
                    data: (user) => Text(
                      user,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    loading: () => const Text('Cargando...'),
                    error: (e, s) => const Text('Usuario'),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                'Plan Premium My Reminder',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.accentTeal : AppTheme.accentIndigo,
                ),
              ),
              const SizedBox(height: 24),

              // 3. AVATAR EMOJI SELECTOR STRIP
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Elegir Avatar Emoji',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _avatarOptions.length,
                  itemBuilder: (context, index) {
                    final emoji = _avatarOptions[index];
                    final isSelected = emoji == _selectedAvatar && _profileImagePath == null;

                    return Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: GestureDetector(
                        onTap: () => _updateAvatar(emoji),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppTheme.primaryDark.withValues(alpha: 0.25)
                                : (isDark ? AppTheme.surfaceDark : Colors.white),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryDark : (isDark ? AppTheme.glassBorder : Colors.grey[300]!),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(emoji, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // 4. CONFIGURATION CARDS
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Preferencias & Seguridad',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppTheme.glassBorder : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      title: const Text('Tema de la Aplicación', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(isDark ? 'Modo Oscuro Neón' : 'Modo Claro Cristal'),
                      trailing: Switch(
                        value: isDark,
                        activeTrackColor: AppTheme.primaryDark,
                        onChanged: (val) {
                          ref.read(appThemeModeProvider.notifier).toggleTheme();
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.sync_rounded, color: AppTheme.accentTeal),
                      ),
                      title: const Text('Sincronización Cloud', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Forzar actualización de datos en Render'),
                      trailing: _isSyncing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: _syncData,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentIndigo.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.fingerprint_rounded, color: AppTheme.accentIndigo),
                      ),
                      title: const Text('Autenticación Biométrica', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Desbloqueo rápido con huella/rostro'),
                      value: _biometricsEnabled,
                      activeTrackColor: AppTheme.accentIndigo,
                      onChanged: (val) async {
                        setState(() => _biometricsEnabled = val);
                        await ref.read(secureStorageProvider).write('biometrics_enabled', val ? 'true' : 'false');
                        if (context.mounted) {
                          AppToast.show(
                            context,
                            message: val ? 'Biometría activada en inicio' : 'Biometría desactivada completamente',
                            type: val ? AppToastType.success : AppToastType.warning,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 5. DANGER ZONE: LOGOUT & DELETE ACCOUNT BUTTONS
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orangeAccent,
                    side: const BorderSide(color: Colors.orangeAccent, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: () async {
                    await ref.read(authStateProvider.notifier).logout();
                  },
                ),
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  label: const Text(
                    'Eliminar Cuenta Definitivamente',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: _showDeleteAccountDialog,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
