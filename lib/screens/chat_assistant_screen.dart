import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'create_task_screen.dart';
import '../services/task_service.dart';
import '../models/task.dart';

class ChatAssistantScreen extends StatefulWidget {
  @override
  _ChatAssistantScreenState createState() => _ChatAssistantScreenState();
}

class _ChatAssistantScreenState extends State<ChatAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  late final String userId;
  final supabase = Supabase.instance.client;

  bool _isLoading = false;

  List<Map<String, dynamic>> _currentTasks = [];

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    if (user == null) {
      // Handle auth error here
      return;
    }
    userId = user.id;
    _loadInitialTasksMessage();
  }

  Future<void> _loadInitialTasksMessage() async {
    final history = await loadChatHistory();

    setState(() {
      _messages.addAll(history.map((m) => {
        'role': m['role'],
        'content': m['content'],
        'raw_data': m['raw_data'],
      }));
    });

    final tasks = await TaskService.instance.getTasks();
    final today = DateTime.now();

    final todayTasks = tasks.where((task) {
      final isSameDay = task.startTime.day == today.day &&
                        task.startTime.month == today.month &&
                        task.startTime.year == today.year;

      if (isSameDay) return true;

      if (task.isRepeating && task.repeatFrequency != null && task.repeatInterval != null) {
        final daysDifference = today.difference(task.startTime).inDays;

        if (task.repeatFrequency == 'daily') {
          return daysDifference % task.repeatInterval! == 0;
        } else if (task.repeatFrequency == 'weekly') {
          return daysDifference % (7 * task.repeatInterval!) == 0 &&
                 task.startTime.weekday == today.weekday;
        }
      }

      return false;
    }).toList();

    if (todayTasks.isNotEmpty) {
      todayTasks.sort((a, b) => a.startTime.compareTo(b.startTime));

      final display = "Here are your tasks for today:";
      final rawData = jsonEncode(todayTasks.map((t) => t.toJson()).toList());

      setState(() {
        _messages.insert(0, {
          'role': 'assistant',
          'content': display,
          'raw_data': rawData,
        });

        _currentTasks = todayTasks.map((t) => {
          'title': t.title,
          'start_time': t.startTime.toIso8601String(),
          'end_time': t.endTime.toIso8601String(),
        }).toList();
      });
    } else {
      setState(() {
        _messages.insert(0, {
          'role': 'assistant',
          'content': "You have no tasks scheduled for today.",
        });
      });
    }
    _scrollToBottom();
  }

  List<Map<String, dynamic>> formatTasksWithMetadata(List<Task> tasks) {
    return tasks.map((t) => {
      'title': t.title,
      'description': t.description,
      'deadline': t.endTime.toIso8601String(),
      'duration_minutes': t.endTime.difference(t.startTime).inMinutes,
      'priority': t.priority,
      'completed': t.completed,
    }).toList();
  }

  String buildSystemMessage(List<Map<String, dynamic>> taskListJson) {
    return '''
  You are a smart assistant embedded in a scheduling app. Respond to the user's request in the following JSON format:

  {
    "display": "Short summary for UI",
    "data": [
      {
        "title": "Task name",
        "description": "Details here",
        "start_time": "YYYY-MM-DDTHH:mm:ss",
        "end_time": "YYYY-MM-DDTHH:mm:ss",
        "priority": 1-5
      }
    ]
  }

  Always include the `data` array. Never return plain text.

  Here is the user's current task list with metadata including deadlines, durations (in minutes), and priority levels (1 = high, 5 = low):
  ${jsonEncode(taskListJson)}

  Assume the user's day runs from 6:00 AM to 10:00 PM. Suggest new productive tasks in available time gaps of at least 15 minutes. Do not duplicate tasks already listed.
  ''';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> loadChatHistory() async {
    final history = await supabase
      .from('chat_messages')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: true)
      .limit(20);
  
    return history.map<Map<String, dynamic>>((m) => {
      'role': m['role'],
      'content': m['content'],
      'raw_data': m['raw_data'],
    }).toList();
  }

  Future<void> _sendMessage(String userMessage) async {
    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
      _isLoading = true;
    });

    _scrollToBottom();

    await supabase.from('chat_messages').insert({
      'user_id': userId,
      'role': 'user',
      'content': userMessage,
    });

    final tasks = await TaskService.instance.getTasks();
    final taskListJson = formatTasksWithMetadata(tasks);
    
    final history = await loadChatHistory();

    final systemMessage = buildSystemMessage(taskListJson);

    final gptMessages = [
      {
        'role': 'system',
        'content': systemMessage,
      },
      ...history.map((m) => {
        'role': m['role'],
        'content': m['content'],
      }),
      {
        'role': 'user',
        'content': userMessage,
      }
    ];

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': '',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4-turbo',
        'messages': gptMessages,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final reply = data['choices'][0]['message']['content'];

      String display = '';
      dynamic rawTasks;

      try {
        final decoded = jsonDecode(reply);
        display = decoded['display'] ?? reply;
        rawTasks = decoded['data'] ?? [];

        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': display,
            'raw_data': jsonEncode(rawTasks),
          });

          _isLoading = false;
        });
        _scrollToBottom();
      } catch (e) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': reply});
          _isLoading = false;
        });
      }
      await supabase.from('chat_messages').insert({
        'user_id': userId,
        'role': 'assistant',
        'content': display,
        'raw_data': jsonEncode(rawTasks),

      });
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get response from ChatGPT')),
      );
    }

    if (mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Assistant'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (_, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';

                return Column(
                  crossAxisAlignment:
                      isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.indigo[200] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(msg['content'] ?? ''),
                      ),
                    ),

                    if (!isUser && msg.containsKey('raw_data')) ...[
                      for (final task in jsonDecode(msg['raw_data'] ?? '[]'))
                        Builder(builder: (_) {
                          final isAlreadyInList = _currentTasks.any((t) =>
                            t['title'] == task['title'] &&
                            t['start_time'] == task['start_time'] &&
                            t['end_time'] == task['end_time']
                          );

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4),
                            child: isAlreadyInList
                                ? Container(
                                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      task['title'],
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    icon: Icon(Icons.task_alt),
                                    label: Text(task['title']),
                                    onPressed: () {
                                      final safeTask = Task.fromGeneratedJson(task);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CreateTaskScreen(task: safeTask),
                                        ),
                                      );
                                    },
                                  ),
                          );
                        }),
                    ],
                  ],
                );
              },
            ),
          ),
          if (_isLoading) CircularProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(hintText: 'Ask me something...'),
                    onChanged: (text) => setState(() {}),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _isLoading || _controller.text.trim().isEmpty
                      ? null
                      : () => _sendMessage(_controller.text.trim()),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
