import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/task_notifier.dart';

class CreateTaskScreen extends StatefulWidget {
  final Task? task;

  const CreateTaskScreen({Key? key, this.task}) : super(key: key);

  @override
  _CreateTaskScreenState createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _startTime;
  late DateTime _endTime;
  late DateTime _selectedDate;

  bool _isRepeating = false;
  String? _repeatFrequency;

  int _priority = 1;
  int _repeatInterval = 1;

  @override
  void initState() {
    super.initState();

    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(text: task?.description ?? '');
    _startTime = task?.startTime ?? DateTime.now();
    _endTime = task?.endTime ?? DateTime.now().add(Duration(hours: 1));
    _selectedDate = task?.startTime ?? DateTime.now();
    _priority = task?.priority ?? 1;
    _isRepeating = task?.isRepeating ?? false;
    _repeatFrequency = task?.repeatFrequency;
    _repeatInterval = task?.repeatInterval ?? 1;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = await TaskService.instance.userId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User not logged in')));
      return;
    }

    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    final updatedTask = Task(
      id: widget.task?.id,
      userId: uid,
      title: _titleController.text,
      description: _descriptionController.text,
      startTime: startDateTime,
      endTime: endDateTime,
      priority: _priority,
      isRepeating: _isRepeating,
      repeatFrequency: _isRepeating ? _repeatFrequency : null,
      completed: widget.task?.completed ?? false,
      repeatInterval: _isRepeating ? _repeatInterval : null,
    );

    try {
      if (widget.task == null) {
        await TaskService.instance.createTask(updatedTask);
      } else {
        await TaskService.instance.updateTask(updatedTask);
      }
      TaskNotifier.instance.notify();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save task: $e')));
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startTime : _endTime),
    );
    if (picked != null) {
      setState(() {
        final base = DateTime.now();
        final updated = DateTime(base.year, base.month, base.day, picked.hour, picked.minute);
        if (isStart) {
          _startTime = updated;
          if (_endTime.isBefore(_startTime)) {
            _endTime = _startTime.add(Duration(hours: 1));
          }
        } else {
          _endTime = updated;
        }
      });
    }
  }

  String _formatTime(DateTime dt) {
    return DateFormat.jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(widget.task == null ? 'Create Task' : 'Edit Task'),
      actions: [
        IconButton(
          icon: Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () async {
            final hasChanges = _titleController.text.isNotEmpty || _descriptionController.text.isNotEmpty;
            if (hasChanges) {
              final shouldDiscard = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Discard changes?'),
                  content: Text('You have unsaved changes. Are you sure you want to cancel?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep Editing')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Discard')),
                  ],
                ),
              );
              if (shouldDiscard ?? false) {
                Navigator.pop(context);
              }
            } else {
              Navigator.pop(context);
            }
          },
        ),
        if (widget.task != null)
        IconButton(
          icon: Icon(Icons.delete),
          tooltip: 'Delete',
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Delete Task?'),
                content: Text('Are you sure you want to permanently delete this task?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete')),
                ],
              ),
            );
            if (confirm == true) {
              await TaskService.instance.deleteTask(widget.task!.id!);
              TaskNotifier.instance.notify();
              Navigator.pop(context);
            }
          },
        ),
      ],
    ),
    body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Task Title'),
                validator: (value) => value == null || value.isEmpty ? 'Title required' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: Text('Start: ${_formatTime(_startTime)}'),
                      trailing: Icon(Icons.access_time),
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ListTile(
                      title: Text('End: ${_formatTime(_endTime)}'),
                      trailing: Icon(Icons.access_time),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                  Expanded( // ✅ wrap in Expanded
                    child: ListTile(
                      title: Text('Date: ${DateFormat.yMMMMd().format(_selectedDate)}'),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now().subtract(Duration(days: 365)),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _priority,
                items: List.generate(5, (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text('Priority ${i + 1}'),
                )),
                onChanged: (val) => setState(() => _priority = val ?? 1),
                decoration: InputDecoration(labelText: 'Priority'),
              ),
              SizedBox(height: 24),
              SwitchListTile(
                title: Text('Repeat Task'),
                value: _isRepeating,
                onChanged: (value) {
                  setState(() {
                    _isRepeating = value;
                    if (!value) _repeatFrequency = null;
                  });
                },
              ),
              if (_isRepeating) ...[
                DropdownButtonFormField<String>(
                  value: _repeatFrequency,
                  decoration: InputDecoration(labelText: 'Repeat Frequency'),
                  items: ['daily', 'weekly'].map((freq) => DropdownMenuItem(
                    value: freq,
                    child: Text('${freq[0].toUpperCase()}${freq.substring(1)}'),
                  )).toList(),
                  onChanged: (value) => setState(() => _repeatFrequency = value),
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Repeat Every N ${_repeatFrequency == 'weekly' ? 'Weeks' : 'Days'}'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() => _repeatInterval = int.tryParse(value) ?? 1);
                  },
                ),
              ],
              ElevatedButton(
                onPressed: _submit,
                child: Text('Save Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
