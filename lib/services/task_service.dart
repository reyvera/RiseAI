import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../services/task_notifier.dart';

class TaskService {
  static final TaskService instance = TaskService._internal();
  final SupabaseClient _client = Supabase.instance.client;

  TaskService._internal();

  Future<String?> get userId async {
    final user = _client.auth.currentUser;
    return user?.id;
  }

  Future<List<Task>> getTasks() async {
    final user = _client.auth.currentUser;
    print('Current user: ${user?.id}');
    if (user == null) return [];

    print('Fetching tasks from Supabase...');
    final response = await _client
        .from('tasks')
        .select()
        .order('start_time', ascending: true);

    print('Raw Supabase response: $response');

    final data = response as List;
    final tasks = data.map((taskData) => Task.fromJson(taskData)).toList();
    print('Mapped tasks: ${tasks.length}');
    return tasks;
  }

  Future<void> createTask(Task task) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated.');

    final taskMap = task.toJson()..['user_id'] = user.id;

    final response = await _client
        .from('tasks')
        .insert(taskMap)
        .select()
        .single();

    if (response == null || response.isEmpty) {
      throw Exception('Failed to create task.');
    }

    TaskNotifier.instance.notify();
  }

  Future<void> deleteTask(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }

  Future<void> updateTaskCompletion({required String taskId, required bool completed}) async {
    final response = await _client
        .from('tasks')
        .update({'completed': completed})
        .eq('id', taskId)
        .select();
  
    if (response == null || response.isEmpty) {
      throw Exception('No data returned from update.');
    }
  
    TaskNotifier.instance.notify(); // Make sure this is implemented!
  }

  Future<void> updateTask(Task task) async {
    if (task.id == null) {
      throw Exception('Cannot update a task without an ID');
    }
  
    final updates = {
      'title': task.title,
      'description': task.description,
      'start_time': task.startTime.toIso8601String(),
      'end_time': task.endTime.toIso8601String(),
      'priority': task.priority,
      'completed': task.completed,
      'isRepeating': task.isRepeating,
      'repeatFrequency': task.repeatFrequency,
      'repeatInterval': task.repeatInterval,
    };
  
    final response = await _client
        .from('tasks')
        .update(updates)
        .eq('id', task.id)
        .eq('user_id', task.userId)
        .select()
        .single();
  
    if (response == null || response.isEmpty) {
      throw Exception('Failed to update task: No data returned');
    }
  
    TaskNotifier.instance.notify();
  }
}
