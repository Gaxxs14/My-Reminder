import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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

  final List<String> _emojiAvatars = [
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

  void _showAvatarPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Personalizar Perfil',
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Cámara', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryDark,
                        side: const BorderSide(color: AppTheme.primaryDark),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickProfileImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Galería', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentTeal,
                        side: const BorderSide(color: AppTheme.accentTeal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickProfileImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              if (_profileImagePath != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                  label: const Text('Quitar foto', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  onPressed: () async {
                    await ref.read(secureStorageProvider).write('user_photo_path', '');
                    setState(() => _profileImagePath = null);
                    if (mounted) Navigator.pop(context);
                    if (mounted) AppToast.show(context, message: 'Foto eliminada', type: AppToastType.warning);
                  },
                ),
              ],
              const Divider(height: 24),
              Text(
                'O elige un Avatar',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _emojiAvatars.map((av) {
                  final isSelected = _selectedAvatar == av && _profileImagePath == null;
                  return GestureDetector(
                    onTap: () async {
                      await ref.read(secureStorageProvider).write('user_avatar', av);
                      await ref.read(secureStorageProvider).write('user_photo_path', '');
                      setState(() {
                        _selectedAvatar = av;
                        _profileImagePath = null;
                      });
                      if (mounted) Navigator.pop(context);
                      if (mounted) AppToast.show(context, message: '¡Avatar actualizado!', type: AppToastType.success);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryDark.withValues(alpha: 0.25) : (isDark ? AppTheme.surfaceDarkElevated : Colors.grey[200]),
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? AppTheme.primaryDark : Colors.transparent, width: 1.5),
                      ),
                      child: Text(av, style: const TextStyle(fontSize: 26)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncServiceProvider).syncReminders();
      if (mounted) {
        AppToast.show(context, message: '¡Datos sincronizados con Render!', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Error de sincronización: $e', type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usernameAsync = ref.watch(usernameProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 90.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Header
              Text(
                'Mi Perfil & Ajustes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gestiona tu cuenta, seguridad y preferencias',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 20),

              // User Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppTheme.glassBorder : Colors.grey[200]!,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryDark.withValues(alpha: isDark ? 0.1 : 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _showAvatarPicker,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: AppTheme.primaryDark.withValues(alpha: 0.2),
                            backgroundImage: _profileImagePath != null
                                ? FileImage(File(_profileImagePath!))
                                : null,
                            child: _profileImagePath == null
                                ? Text(_selectedAvatar, style: const TextStyle(fontSize: 32))
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryDark,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          usernameAsync.when(
                            data: (name) => Text(
                              name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                              ),
                            ),
                            loading: () => const Text('Cargando...'),
                            error: (err, stack) => const Text('Usuario'),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Icon(Icons.cloud_done_rounded, size: 14, color: AppTheme.accentTeal),
                              SizedBox(width: 4),
                              Text(
                                'Conectado a Render Cloud',
                                style: TextStyle(fontSize: 12, color: AppTheme.accentTeal, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _showAvatarPicker,
                            child: const Text(
                              'Toca para cambiar foto o avatar',
                              style: TextStyle(fontSize: 11, color: AppTheme.primaryDark, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Settings Section Header
              Text(
                'Preferencias & Apariencia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),

              // Settings List Card
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppTheme.glassBorder : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Container(
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
                      title: Text(
                        isDark ? 'Modo Claro' : 'Modo Oscuro',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Alternar el esquema de colores de la app'),
                      value: isDark,
                      activeTrackColor: AppTheme.primaryDark,
                      onChanged: (_) {
                        ref.read(appThemeModeProvider.notifier).toggleTheme();
                      },
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
                      title: const Text('Sincronizar con la Nube', style: TextStyle(fontWeight: FontWeight.bold)),
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

              // Danger Zone: Logout Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
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
            ],
          ),
        ),
      ),
    );
  }
}
