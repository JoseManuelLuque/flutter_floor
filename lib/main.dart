import 'package:flutter/material.dart';
import 'database/database.dart';
import 'screens/task_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await $FloorAppDatabase
      .databaseBuilder('app_database.db')
      .build();
  runApp(MainApp(database: database));
}

class MainApp extends StatelessWidget {
  final AppDatabase database;

  const MainApp({Key? key, required this.database}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TaskListScreen(database: database),
    );
  }
}