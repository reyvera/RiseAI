import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/task_card.dart';
import '../services/task_service.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;

  const TaskCard({
    Key? key,
    required this.task,
    this.onTap,
    this.onToggleComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timeRange = '${DateFormat.jm().format(task.startTime)} - ${DateFormat.jm().format(task.endTime)}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: task.completed ? TextDecoration.lineThrough : null,
            color: task.completed ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description?.isNotEmpty ?? false)
              Text(task.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(timeRange, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        leading: Checkbox(
          value: task.completed,
          onChanged: (_) => onToggleComplete?.call(),
        ),
        onTap: onTap,
        trailing: task.isRepeating
            ? Icon(Icons.repeat, size: 20, color: Theme.of(context).primaryColor)
            : null,
      ),
    );
  }
}
