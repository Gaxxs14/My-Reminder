import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart'; 
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/reminder_model.dart';
import 'reminders_provider.dart';
import '../../workspaces/presentation/workspaces_provider.dart';

class AddReminderSheet extends ConsumerStatefulWidget {
  const AddReminderSheet({super.key});

  @override
  ConsumerState<AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<AddReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _costController = TextEditingController();

  // Location fields
  bool _useLocation = false;
  bool _isAlarm = false;
  String _selectedPriority = 'media';
  final _locationNameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _radiusController = TextEditingController(text: '150');
  String? _selectedWorkspaceId;

  DateTime _selectedDate = DateTime.now().add(const Duration(minutes: 10));
  TimeOfDay _selectedTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 10)));
  String _selectedCategory = 'Personal';

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Personal', 'color': const Color(0xFF0D9488), 'icon': Icons.person},
    {'name': 'Trabajo', 'color': const Color(0xFF38BDF8), 'icon': Icons.work},
    {'name': 'Salud', 'color': const Color(0xFFEF4444), 'icon': Icons.favorite},
    {'name': 'General', 'color': Colors.blueGrey, 'icon': Icons.label},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _costController.dispose();
    _locationNameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        final request = await Geolocator.requestPermission();
        if (request == LocationPermission.denied || request == LocationPermission.deniedForever) {
          if (mounted) {
            AppToast.show(context, message: 'Permisos de ubicación denegados', type: AppToastType.error);
          }
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) {
        setState(() {
          _latitudeController.text = pos.latitude.toString();
          _longitudeController.text = pos.longitude.toString();
          if (_locationNameController.text.isEmpty) {
            _locationNameController.text = 'Mi Ubicación';
          }
        });
        AppToast.show(context, message: 'Ubicación obtenida correctamente', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Error obteniendo ubicación: $e', type: AppToastType.error);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    if (_selectedDate.isBefore(now)) {
      AppToast.show(
        context,
        message: 'La fecha y hora del recordatorio deben ser en el futuro.',
        type: AppToastType.warning,
      );
      return;
    }

    final String uuid = const Uuid().v4();

    final newReminder = ReminderModel(
      id: uuid,
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      category: _selectedCategory,
      dueDate: _selectedDate,
      status: 'pending',
      isSynced: false,
      latitude: _useLocation ? double.tryParse(_latitudeController.text) : null,
      longitude: _useLocation ? double.tryParse(_longitudeController.text) : null,
      locationName: _useLocation && _locationNameController.text.trim().isNotEmpty
          ? _locationNameController.text.trim()
          : null,
      radiusInMeters: _useLocation ? (double.tryParse(_radiusController.text) ?? 150.0) : null,
      workspaceId: _selectedWorkspaceId,
      priority: _selectedPriority,
      estimatedCost: double.tryParse(_costController.text.trim()),
      isAlarm: _isAlarm,
    );

    ref.read(remindersProvider.notifier).addReminder(newReminder);
    AppToast.show(context, message: '¡Recordatorio agendado!', type: AppToastType.success);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final workspaces = ref.watch(workspacesProvider);

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
        child: Form(
          key: _formKey,
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
                'Nuevo Recordatorio Avanzado',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 20),

              AppTextField(
                controller: _titleController,
                labelText: 'Título del Recordatorio',
                hintText: 'ej. Pagar el internet',
                prefixIcon: Icons.title,
                validator: (val) => val == null || val.trim().isEmpty ? 'El título es requerido' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _descController,
                labelText: 'Descripción / Notas (Opcional)',
                hintText: 'ej. Monto \$25 en la página de Fibra',
                prefixIcon: Icons.description_outlined,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _costController,
                labelText: 'Costo Estimado (\$) (Opcional)',
                hintText: 'ej. 25.00',
                prefixIcon: Icons.attach_money_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 20),

              // Priority Selector
              Text(
                'Nivel de Prioridad (Matriz Eisenhower)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPriorityChip('baja', 'Baja', Colors.blue, isDark),
                  const SizedBox(width: 8),
                  _buildPriorityChip('media', 'Media', Colors.orange, isDark),
                  const SizedBox(width: 8),
                  _buildPriorityChip('alta', 'Alta (Urgente)', Colors.redAccent, isDark),
                ],
              ),
              const SizedBox(height: 20),

              // Date and Time Selectors
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.calendar_month),
                      label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                      onPressed: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.access_time),
                      label: Text(_selectedTime.format(context)),
                      onPressed: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SwitchListTile(
                title: const Text('Modo Alarma Inteligente'),
                subtitle: const Text('Sonar con alarma fuerte para eventos críticos'),
                value: _isAlarm,
                activeTrackColor: Colors.redAccent,
                onChanged: (val) => setState(() => _isAlarm = val),
              ),

              // Category Selector
              const SizedBox(height: 12),
              Text(
                'Categoría',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat['name'];
                    final Color catColor = cat['color'] as Color;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat['name'] as String),
                        avatar: Icon(
                          cat['icon'] as IconData,
                          size: 16,
                          color: isSelected ? Colors.black : catColor,
                        ),
                        selected: isSelected,
                        selectedColor: catColor,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategory = cat['name'] as String;
                            });
                          }
                        },
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (workspaces.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Asignar a Espacio Colaborativo (Opcional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedWorkspaceId,
                  decoration: InputDecoration(
                    labelText: 'Espacio Compartido',
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Ninguno (Tarea Personal)')),
                    ...workspaces.map((ws) => DropdownMenuItem(value: ws.id, child: Text(ws.name))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedWorkspaceId = val;
                    });
                  },
                ),
              ],
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Alarma Geográfica (GPS)'),
                subtitle: const Text('Fijar un aviso cuando estés cerca'),
                value: _useLocation,
                activeTrackColor: AppTheme.primaryDark,
                onChanged: (val) {
                  setState(() {
                    _useLocation = val;
                  });
                },
              ),
              if (_useLocation) ...[
                const SizedBox(height: 12),
                AppTextField(
                  controller: _locationNameController,
                  labelText: 'Nombre del Lugar',
                  hintText: 'ej. Supermercado, Oficina, Casa',
                  prefixIcon: Icons.place_outlined,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _latitudeController,
                        labelText: 'Latitud',
                        hintText: 'ej. 19.4326',
                        prefixIcon: Icons.map,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _longitudeController,
                        labelText: 'Longitud',
                        hintText: 'ej. -99.1332',
                        prefixIcon: Icons.map,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _radiusController,
                        labelText: 'Radio (metros)',
                        hintText: '150',
                        prefixIcon: Icons.circle_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.my_location),
                      label: const Text('Mi GPS'),
                      onPressed: _getCurrentLocation,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 28),

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
                        elevation: 0,
                      ),
                      onPressed: _save,
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
      ),
    );
  }

  Widget _buildPriorityChip(String value, String label, Color color, bool isDark) {
    final isSelected = _selectedPriority == value;
    return FilterChip(
      showCheckmark: false,
      selected: isSelected,
      label: Text(label),
      selectedColor: color.withValues(alpha: 0.25),
      backgroundColor: isDark ? AppTheme.surfaceDarkElevated : Colors.grey[200],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? color : Colors.transparent),
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? color : (isDark ? Colors.white70 : Colors.black87),
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedPriority = value);
      },
    );
  }
}
