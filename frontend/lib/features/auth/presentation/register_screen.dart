import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/gaxxs_loader.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final success = await ref.read(authStateProvider.notifier).register(
            username: _userController.text.trim(),
            password: _passController.text,
          );

      if (mounted) {
        if (success) {
          AppToast.show(context, message: '¡Cuenta creada con éxito!', type: AppToastType.success);
          // Pop screens back to root which will redirect to Home automatically due to Riverpod state
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          AppToast.show(
            context,
            message: 'El usuario ya existe o hubo un error.',
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const GaxxsIconMark(size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Crear Cuenta',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Únete a My-Reminder y sincroniza tus notas en la nube',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Fields container
                  Card(
                    elevation: isDark ? 0 : 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          AppTextField(
                            controller: _userController,
                            labelText: 'Nombre de Usuario',
                            hintText: 'ej. pedro_gomez',
                            prefixIcon: Icons.person_outline,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'El usuario es requerido';
                              if (val.trim().length < 3) return 'Debe tener al menos 3 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _passController,
                            labelText: 'Contraseña',
                            isPassword: true,
                            prefixIcon: Icons.lock_outline,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'La contraseña es requerida';
                              if (val.length < 6) return 'Debe tener al menos 6 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _confirmPassController,
                            labelText: 'Confirmar Contraseña',
                            isPassword: true,
                            prefixIcon: Icons.lock_clock_outlined,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Confirma tu contraseña';
                              if (val != _passController.text) return 'Las contraseñas no coinciden';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (_isLoading)
                    const GaxxsLoader(showBrandName: false, size: 48)
                  else
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
                        onPressed: _register,
                        child: const Text(
                          'Registrarse',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  // Toggle view link
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      '¿Ya tienes cuenta? Inicia sesión aquí',
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
