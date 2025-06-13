import 'package:flutter/material.dart';

class TaskNotifier extends ValueNotifier<void> {
  static final TaskNotifier instance = TaskNotifier._internal();

  TaskNotifier._internal() : super(null);

  void notify() {
    notifyListeners();
  }
}
