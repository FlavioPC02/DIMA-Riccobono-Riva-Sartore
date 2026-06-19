import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:hike_core/hike_core.dart';

class AddActivityPage extends StatefulWidget {
  final Activity activity;

  const AddActivityPage({super.key, required this.activity});

  @override
  State<AddActivityPage> createState() => _AddActivityPageState();
}

class _AddActivityPageState extends State<AddActivityPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  
  final _nameFocus = FocusNode();

  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.activity.date;
    _nameFocus.addListener(() {
      if (_nameFocus.hasFocus && _nameController.text.isEmpty) {
        _nameController.text = 'Hike to ${widget.activity.name}';
        _nameController.selection = TextSelection.fromPosition(
          TextPosition(offset: _nameController.text.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
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
      trailId: widget.activity.trailId,
      trailPath: widget.activity.trailPath,
      distanceKm: widget.activity.distanceKm,
      durationMinutes: widget.activity.durationMinutes,
      xpEarned: 0,
      notes: [],
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        centerTitle: true,
        title: const Text(
          'New Planned Hike',
        ),
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
              focusNode: _nameFocus,
              decoration: InputDecoration(
                labelText: 'Name',
                floatingLabelBehavior: FloatingLabelBehavior.always,
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
                    initialValue: '${widget.activity.distanceKm.toStringAsFixed(1)} km',
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Distance',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: widget.activity.durationMinutes.toMinuteDurationLabel(),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.activity.difficulty.label,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Difficulty',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'save_button',
        onPressed: _saving ? null : _save,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        icon: _saving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
              )
            : const Icon(Icons.save),
        label: Text(
          _saving ? 'Saving...' : 'Save',
          style: const TextStyle(fontWeight: FontWeight.bold),
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
