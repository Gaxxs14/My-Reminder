import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/gaxxs_loader.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;
  bool _biometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final hasToken = await ref.read(secureStorageProvider).getToken();
    final canAuth = await ref.read(biometricProvider).canAuthenticate();
    
    if (hasToken != null && canAuth) {
      setState(() {
        _biometricsAvailable = true;
      });
      final savedUsername = await ref.read(secureStorageProvider).getUsername();
      if (savedUsername != null) {
        _userController.text = savedUsername;
      }
      
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _authenticateWithBiometrics();
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() => _isLoading = true);
    final success = await ref.read(authStateProvider.notifier).loginWithBiometrics();
    setState(() => _isLoading = false);

    if (success && mounted) {
      AppToast.show(context, message: '¡Desbloqueado con biometría!', type: AppToastType.success);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final result = await ref.read(authStateProvider.notifier).loginWithPassword(
            username: _userController.text.trim(),
            password: _passController.text,
          );

      if (mounted) {
        if (result.success) {
          AppToast.show(context, message: '¡Bienvenido de nuevo!', type: AppToastType.success);
        } else {
          AppToast.show(
            context,
            message: result.errorMessage ?? 'Usuario o contraseña incorrectos.',
            type: AppToastType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Error de conexión: $e', type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Subtle Ambient Background Glow Gradients
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryDark.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryDark.withValues(alpha: 0.12),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentTeal.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentTeal.withValues(alpha: 0.1),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Glow Brand Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surfaceDark,
                          border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryDark.withValues(alpha: 0.25),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const GaxxsIconMark(size: 56),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'My-Reminder',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tu agenda inteligente & asistente personal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Glass Card Form Container
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.surfaceDark.withValues(alpha: 0.85) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? AppTheme.glassBorder : Colors.grey[200]!,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            AppTextField(
                              controller: _userController,
                              labelText: 'Nombre de Usuario',
                              hintText: 'ej. pedro_gomez',
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (val) => val == null || val.trim().isEmpty
                                  ? 'Ingresa tu usuario'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: _passController,
                              labelText: 'Contraseña',
                              isPassword: true,
                              prefixIcon: Icons.lock_outline_rounded,
                              validator: (val) => val == null || val.isEmpty
                                  ? 'Ingresa tu contraseña'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      if (_isLoading)
                        const GaxxsLoader(showBrandName: false, size: 48)
                      else ...[
                        // Gradient Main Action Button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF38BDF8), Color(0xFF2DD4BF)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryDark.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: _login,
                            child: const Text(
                              'Iniciar Sesión',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),

                        if (_biometricsAvailable) ...[
                          const SizedBox(height: 20),
                          // Biometric Trigger Button with Halo Effect
                          GestureDetector(
                            onTap: _authenticateWithBiometrics,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primaryDark.withValues(alpha: 0.12),
                                border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.4), width: 1.5),
                              ),
                              child: const Icon(
                                Icons.fingerprint_rounded,
                                size: 36,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 28),

                      // Navigation Toggle Link
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 14, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                            children: const [
                              TextSpan(text: '¿No tienes cuenta? '),
                              TextSpan(
                                text: 'Regístrate aquí',
                                style: TextStyle(
                                  color: AppTheme.primaryDark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
