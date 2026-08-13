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
      
      // Auto-trigger biometrics on open for convenience
      Future.delayed(const Duration(milliseconds: 300), () {
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const GaxxsIconMark(size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'My-Reminder',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu agenda y asistente personal de voz',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 36),
                  
                  // Card Container for fields
                  Card(
                    elevation: isDark ? 0 : 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          AppTextField(
                            controller: _userController,
                            labelText: 'Nombre de Usuario',
                            hintText: 'ej. juan_perez',
                            prefixIcon: Icons.person_outline,
                            validator: (val) => val == null || val.trim().isEmpty
                                ? 'Ingresa tu usuario'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _passController,
                            labelText: 'Contraseña',
                            isPassword: true,
                            prefixIcon: Icons.lock_outline,
                            validator: (val) => val == null || val.isEmpty
                                ? 'Ingresa tu contraseña'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_isLoading)
                    const GaxxsLoader(showBrandName: false, size: 48)
                  else ...[
                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryDark,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _login,
                        child: const Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    if (_biometricsAvailable) ...[
                      const SizedBox(height: 16),
                      // Biometric trigger option
                      IconButton(
                        icon: Icon(
                          Icons.fingerprint,
                          size: 40,
                          color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                        ),
                        onPressed: _authenticateWithBiometrics,
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  
                  // Toggle view
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: Text(
                      '¿No tienes cuenta? Regístrate aquí',
                      style: TextStyle(
                        color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
