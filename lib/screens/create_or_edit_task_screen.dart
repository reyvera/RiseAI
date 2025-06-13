// screens/create_or_edit_task_screen.dart
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../widgets/task_form.dart';

class CreateOrEditTaskScreen extends StatelessWidget {
  const CreateOrEditTaskScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Task? task = ModalRoute.of(context)?.settings.arguments as Task?;

    return Scaffold(
      appBar: AppBar(
        title: Text(task != null ? 'Edit Task' : 'New Task'),
      ),
      body: TaskForm(task: task),
    );
  }
}
