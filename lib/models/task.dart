class Task {
  final String? id;
  final String userId;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final int priority;
  bool completed;
  final bool isRepeating;
  final String? repeatFrequency; // 'daily', 'weekly'
  final int? repeatInterval;     // e.g., every 2 days

  Task({
    this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.priority,
    required this.completed,
    required this.isRepeating,
    this.repeatFrequency,
    this.repeatInterval,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String?,
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),
      priority: json['priority'],
      completed: json['completed'] ?? false,
      isRepeating: json['isRepeating'] ?? false,
      repeatFrequency: json['repeatFrequency'],
      repeatInterval: json['repeat_interval'] as int?,
    );
  }

  static Task fromGeneratedJson(Map<String, dynamic> json) {
    return Task(
      id: null,
      userId: '', // Or set this to a default/fallback value
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      startTime: DateTime.tryParse(json['start_time'] ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(json['end_time'] ?? '') ?? DateTime.now().add(Duration(hours: 1)),
      priority: json['priority'] ?? 3,
      completed: false,
      isRepeating: false,
      repeatFrequency: null,
      repeatInterval: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'priority': priority,
      'completed': completed,
      'isRepeating': isRepeating,
      'repeatFrequency': repeatFrequency,
      'repeat_interval': repeatInterval,
    };
  }
}
