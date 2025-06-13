import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_service.dart';

class TaskForm extends StatefulWidget {
  final Task? task;
  const TaskForm({Key? key, this.task}) : super(key: key);

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _startTime;
  DateTime? _endTime;
  int _priority = 1;
  bool _isRepeating = false;
  String _repeatFrequency = 'daily';
  int _repeatInterval = 1;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      final t = widget.task!;
      _titleController.text = t.title;
      _descController.text = t.description ?? '';
      _startTime = t.startTime;
      _endTime = t.endTime;
      _priority = t.priority;
      _isRepeating = t.isRepeating;
      _repeatFrequency = t.repeatFrequency ?? 'daily';
      _repeatInterval = t.repeatInterval ?? 1;
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(Duration(days: 365)),
      lastDate: now.add(Duration(days: 365)),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );

    if (time == null) return;

    final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startTime = dateTime;
        if (_endTime == null || _endTime!.isBefore(dateTime)) {
          _endTime = dateTime.add(Duration(hours: 1));
        }
      } else {
        _endTime = dateTime;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _startTime == null || _endTime == null) return;

    final task = Task(
      id: widget.task?.id,
      userId: widget.task?.userId ?? '', // assume filled in on service layer
      title: _titleController.text,
      description: _descController.text,
      priority: _priority,
      startTime: _startTime!,
      endTime: _endTime!,
      completed: widget.task?.completed ?? false,
      isRepeating: _isRepeating,
      repeatFrequency: _isRepeating ? _repeatFrequency : null,
      repeatInterval: _isRepeating ? _repeatInterval : null,
    );

    if (widget.task == null) {
      await TaskService.instance.createTask(task);
    } else {
      await TaskService.instance.updateTask(task);
    }

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(labelText: 'Title'),
            validator: (value) => value == null || value.isEmpty ? 'Enter a title' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descController,
            decoration: InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _pickDateTime(isStart: true),
                  child: Text(_startTime == null
                      ? 'Start Time'
                      : DateFormat('MMM d • h:mm a').format(_startTime!)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _pickDateTime(isStart: false),
                  child: Text(_endTime == null
                      ? 'End Time'
                      : DateFormat('MMM d • h:mm a').format(_endTime!)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _priority,
            decoration: InputDecoration(labelText: 'Priority'),
            items: [1, 2, 3].map((p) {
              return DropdownMenuItem(value: p, child: Text('Priority $p'));
            }).toList(),
            onChanged: (val) => setState(() => _priority = val!),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text('Repeating Task'),
            value: _isRepeating,
            onChanged: (val) => setState(() => _isRepeating = val),
          ),
          if (_isRepeating) ...[
            DropdownButtonFormField<String>(
              value: _repeatFrequency,
              decoration: InputDecoration(labelText: 'Repeat Frequency'),
              items: ['daily', 'weekly'].map((f) {
                return DropdownMenuItem(value: f, child: Text(f.capitalize()));
              }).toList(),
              onChanged: (val) => setState(() => _repeatFrequency = val!),
            ),
            TextFormField(
              initialValue: _repeatInterval.toString(),
              decoration: InputDecoration(labelText: 'Repeat Interval'),
              keyboardType: TextInputType.number,
              onChanged: (val) =>
                  setState(() => _repeatInterval = int.tryParse(val) ?? 1),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _submit,
            icon: Icon(Icons.save),
            label: Text(widget.task == null ? 'Create Task' : 'Update Task'),
          )
        ],
      ),
    );
  }
}

extension on String {
  String capitalize() => this[0].toUpperCase() + substring(1);
}
