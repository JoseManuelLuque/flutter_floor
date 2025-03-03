import 'package:floor/floor.dart';

@entity
class Task {
  @primaryKey
  final int id;
  final String name;
  final bool isCompleted;

  Task(this.id, this.name, this.isCompleted);
}