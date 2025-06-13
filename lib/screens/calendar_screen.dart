import 'package:flutter/material.dart';
import 'package:focustime/widgets/task_card.dart';
import 'package:intl/intl.dart';
import '../services/task_service.dart';
import '../models/task.dart';
import '../services/task_notifier.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalendarScreen extends StatefulWidget {
  CalendarScreen({Key? key}) : super(key: key);

  @override
  CalendarScreenState createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  Map<DateTime, List<Task>> _groupedTasks = {};
  List<Task> _selectedTasks = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _viewMode = 'month'; // options: 'day', 'week', 'month'
  // String _calendarMode = 'day'; // Options: 'day', 'week', 'month'

  // List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();  

    print('CalendarScreen initState called'); 

    // Wait for user to be ready
    _checkAuthThenLoadTasks();  

    // Optionally refresh when notified
    TaskNotifier.instance.addListener(_loadTasks);
  } 

  Future<void> _checkAuthThenLoadTasks() async {
    print('Waiting for user to sign in...');
    await Future.delayed(Duration(milliseconds: 500)); // Small wait in case of delay
    final user = Supabase.instance.client.auth.currentUser; 

    if (user != null) {
      print('User ready: ${user.id}');
      _loadTasks();
    } else {
      print('User still null. Listening for auth change...');
      Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        final newUser = Supabase.instance.client.auth.currentUser;
        if (newUser != null) {
          print('Auth state changed: ${newUser.id}');
          _loadTasks();
        }
      });
    }
  }

  @override
  void dispose() {
    TaskNotifier.instance.removeListener(_loadTasks);
    super.dispose();
  }

Future<void> _loadTasks() async {
  print('Running _loadTasks...');
  final tasks = await TaskService.instance.getTasks();
  print('Tasks fetched: ${tasks.length}');
  final grouped = <DateTime, List<Task>>{};

  for (final task in tasks) {
    final day = DateTime(task.startTime.year, task.startTime.month, task.startTime.day);
    final baseTime = DateTime(day.year, day.month, day.day, task.startTime.hour, task.startTime.minute);
    grouped[day] = [...(grouped[day] ?? []), task];

    if (task.isRepeating && task.repeatFrequency != null) {
      final interval = task.repeatInterval ?? 1; // default to 1 if null

      for (int i = 1; i <= 30; i++) {
        final repeatOffset = (task.repeatFrequency == 'daily')
            ? Duration(days: i * interval)
            : (task.repeatFrequency == 'weekly')
                ? Duration(days: 7 * i * interval)
                : null;

        if (repeatOffset == null) continue;

        final repeatDay = day.add(repeatOffset);
        final repeatedTask = Task(
          id: '${task.id}_$i',
          userId: task.userId,
          title: task.title,
          description: task.description,
          priority: task.priority,
          startTime: baseTime.add(repeatOffset),
          endTime: task.endTime.add(repeatOffset),
          completed: false,
          isRepeating: true,
          repeatFrequency: task.repeatFrequency,
          repeatInterval: interval,
        );

        grouped[DateTime(repeatDay.year, repeatDay.month, repeatDay.day)] =
            [...(grouped[repeatDay] ?? []), repeatedTask];
      }
    }
  }

  final todayKey = DateTime.now();
  final today = DateTime(todayKey.year, todayKey.month, todayKey.day);

  setState(() {
    _groupedTasks = grouped;
    _selectedDay ??= today;
    _focusedDay = _selectedDay!;
    _selectedTasks = _groupedTasks[DateTime(
      _selectedDay!.year, _selectedDay!.month, _selectedDay!.day
    )] ?? [];
  });

  print('Tasks loaded: ${_groupedTasks.length}');
  print('Tasks for today: ${_groupedTasks[today]?.length ?? 0}');
}

  Widget _buildListView() {
    return ListView.builder(
      itemCount: _selectedTasks.length,
      itemBuilder: (context, index) {
        final task = _selectedTasks[index];
        final isCompleted = task.completed;
  
        return TaskCard(
          task: task,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/create',
              arguments: task,
            );
          },
          onToggleComplete: () async {
            await TaskService.instance.updateTaskCompletion(
              taskId: task.id!,
              completed: !task.completed,
            );
            await _loadTasks();
          },
        );
      },
    );
  }

  Widget _buildTimeBlockView() {
    final startHour = 6;
    final endHour = 22;

    return ListView.builder(
      itemCount: endHour - startHour,
      itemBuilder: (context, index) {
        final hour = startHour + index;
        final timeSlot = DateTime(
          _focusedDay.year, _focusedDay.month, _focusedDay.day, hour,
        );

        final tasksAtHour = _selectedTasks.where((task) {
          final startHour = task.startTime.hour;
          final endHour = task.endTime.hour;

          // Show if start and end are the same, and match this hour exactly
          if (startHour == endHour) {
            return hour == startHour;
          }

          // Otherwise, task spans multiple hours
          return hour >= startHour && hour < endHour;
        }).toList();

        final isNow = DateTime.now().hour == hour &&
          DateTime.now().day == _focusedDay.day &&
          DateTime.now().month == _focusedDay.month &&
          DateTime.now().year == _focusedDay.year;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isNow ? Colors.blue.shade100 : Colors.grey.shade200,
              child: Text(
                '${DateFormat.jm().format(timeSlot)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isNow ? Colors.blue.shade900 : Colors.black,
                ),
              ),
            ),
            if (tasksAtHour.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Text(
                  '—',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ...tasksAtHour.map((task) => TaskCard(
              task: task,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/create',
                  arguments: task,
                );
              },
              onToggleComplete: () async {
                await TaskService.instance.updateTaskCompletion(
                  taskId: task.id!,
                  completed: !task.completed,
                );
                await _loadTasks();
              },
            )),
          ],
        );
      },
    );
  }

  Widget _buildDayView() {
    return _viewMode == 'list' ? _buildListView() : _buildTimeBlockView();
  }

  Widget _buildWeekView() {
    final startOfWeek = _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
    final weekDates = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: weekDates.map((day) {
          final tasks = _groupedTasks[DateTime(day.year, day.month, day.day)] ?? [];

          return Container(
            width: 160, // ✅ Fixed width to prevent layout errors
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat.E().format(day), style: TextStyle(fontWeight: FontWeight.bold)),
                Text(DateFormat.MMMd().format(day)),
                const SizedBox(height: 8),
                if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No tasks', style: TextStyle(color: Colors.grey)),
                  ),
                ...tasks.map((task) => CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      value: task.completed,
                      onChanged: (val) async {
                        await TaskService.instance.updateTaskCompletion(
                          taskId: task.id!,
                          completed: val!,
                        );
                        await _loadTasks(); // refresh UI
                      },
                      title: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 12,
                          decoration: task.completed ? TextDecoration.lineThrough : null,
                          color: task.completed ? Colors.grey : null,
                        ),
                      ),
                    )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeBlockViewForSelectedDay() {
    if (_selectedDay == null) {
      return Center(child: Text("Select a day to view tasks"));
    }

    final selectedDate = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final tasks = _groupedTasks[selectedDate] ?? [];

    const startHour = 6;
    const endHour = 22;
    
    return ListView.builder(
      itemCount: endHour - startHour,
      itemBuilder: (context, index) {
        final hour = startHour + index;
        final timeSlot = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, hour);

        final tasksAtHour = tasks.where((task) {
          final startHour = task.startTime.hour;
          final endHour = task.endTime.hour;

          if (startHour == endHour) {
            return hour == startHour;
          }
          return hour >= startHour && hour < endHour;
        }).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      DateFormat.jm().format(timeSlot),
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                    ),
                  ),
                  if (tasksAtHour.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      child: Text('—', style: TextStyle(color: Colors.grey)),
                    ),
                  ...tasksAtHour.map((task) => TaskCard(
                    task: task,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/create',
                        arguments: task,
                      );
                    },
                    onToggleComplete: () async {
                      await TaskService.instance.updateTaskCompletion(
                        taskId: task.id!,
                        completed: !task.completed,
                      );
                      await _loadTasks();
                    },
                  )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthView() {
    return Column(
      children: [
        TableCalendar<Task>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            final key = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
            print('Day selected: $key has ${_groupedTasks[key]?.length ?? 0} task(s)');
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
              _selectedTasks = _groupedTasks[DateTime(selectedDay.year, selectedDay.month, selectedDay.day)] ?? [];
            });
          },
          eventLoader: (day) {
            final key = DateTime(day.year, day.month, day.day);
            return _groupedTasks[key] ?? [];
          },
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
            markerDecoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildTimeBlockViewForSelectedDay(),
        ),
      ],
    );
  }

  Widget _buildCalendarView() {
    switch (_viewMode) {
      case 'day':
        return _buildDayView();
      case 'week':
        return _buildWeekView();
      case 'month':
      default:
        return _buildMonthView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _viewMode == 'day'
                      ? 'Today\'s Schedule'
                      : _viewMode == 'week'
                          ? 'This Week'
                          : 'This Month',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                ToggleButtons(
                  borderRadius: BorderRadius.circular(8),
                  isSelected: ['day', 'week', 'month'].map((v) => _viewMode == v).toList(),
                  onPressed: (index) {
                    setState(() {
                      _viewMode = ['day', 'week', 'month'][index];
                    });
                  },
                  children: const [
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Day')),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Week')),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Month')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildCalendarView()), // 🔁 Shows day/week/month view
          ],
        ),
      ),
    );
  }
}