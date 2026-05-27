import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class AddActivityPage extends StatefulWidget {
  final Activity activity;

  const AddActivityPage({super.key, required this.activity});

  @override
  State<AddActivityPage> createState() => _AddActivityPageState();
}

class _AddActivityPageState extends State<AddActivityPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.activity.date;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final activity = Activity(
      id: '',
      name: _nameController.text.trim(),
      status: ActivityStatus.planned,
      date: _selectedDate,
      trailName: widget.activity.trailName,
      distanceKm: widget.activity.distanceKm,
      durationMinutes: widget.activity.durationMinutes,
      xpEarned: 0,
      notes: '',
      difficulty: widget.activity.difficulty,
      trackedDistance: 0,
      trackedElevationGap: 0,
      trackedTime: Duration.zero,
    );

    await context.read<ActivityCubit>().addActivity(activity);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        title: const Text('New Planned Hike'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionLabel('Activity'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: widget.activity.name,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.activity.trailName,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Trail',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel('Date'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel('Details'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: widget.activity.distanceKm.toString(),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Distance (km)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: widget.activity.durationMinutes.toString(),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Duration (min)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.activity.difficulty.name,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Difficulty',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
        letterSpacing: 1.1,
      ),
    );
  }
}
