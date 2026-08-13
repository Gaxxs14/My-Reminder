import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/reminder_model.dart';
import 'reminders_provider.dart';

class EditReminderSheet extends ConsumerStatefulWidget {
  final ReminderModel reminder;
  const EditReminderSheet({super.key, required this.reminder});

  @override
  ConsumerState<EditReminderSheet> createState() => _EditReminderSheetState();
}

class _EditReminderSheetState extends ConsumerState<EditReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _costController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _selectedCategory;
  late String _selectedPriority;
  late bool _isAlarm;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.reminder.title);
    _descController = TextEditingController(text: widget.reminder.description ?? '');
    _costController = TextEditingController(
        text: widget.reminder.estimatedCost != null ? widget.reminder.estimatedCost.toString() : '');
    _selectedDate = widget.reminder.dueDate;
    _selectedTime = TimeOfDay.fromDateTime(widget.reminder.dueDate);
    _selectedCategory = widget.reminder.category;
    _selectedPriority = widget.reminder.priority;
    _isAlarm = widget.reminder.isAlarm;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final updated = widget.reminder.copyWith(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      category: _selectedCategory,
      dueDate: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ),
      priority: _selectedPriority,
      estimatedCost: double.tryParse(_costController.text.trim()),
      isAlarm: _isAlarm,
      isSynced: false,
    );

    ref.read(remindersProvider.notifier).updateReminder(updated);
    AppToast.show(context, message: '¡Recordatorio actualizado!', type: AppToastType.success);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                'Editar Recordatorio',
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
                prefixIcon: Icons.title,
                validator: (val) => val == null || val.trim().isEmpty ? 'El título es requerido' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _descController,
                labelText: 'Descripción / Notas',
                prefixIcon: Icons.description_outlined,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _costController,
                labelText: 'Costo Estimado (\$) (Opcional)',
                prefixIcon: Icons.attach_money_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 20),

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
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
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
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (picked != null) setState(() => _selectedTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SwitchListTile(
                title: const Text('Modo Alarma Inteligente'),
                value: _isAlarm,
                activeTrackColor: Colors.redAccent,
                onChanged: (val) => setState(() => _isAlarm = val),
              ),
              const SizedBox(height: 20),

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
                      onPressed: _save,
                      child: const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.bold)),
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
}
