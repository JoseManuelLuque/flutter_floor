import 'package:floor/floor.dart';

@entity
class Task {
  @primaryKey
  final int id;
  final String name;
  final String description;

  Task(this.id, this.name, this.description);
}