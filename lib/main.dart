import 'package:flutter/material.dart';
import 'database.dart';
import 'task.dart';

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

class TaskListScreen extends StatelessWidget {
  final AppDatabase database;

  const TaskListScreen({Key? key, required this.database}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lista de Tareas'),
      ),
      body: FutureBuilder<List<Task>>(
        future: database.taskDao.findAllTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No hay tareas'));
          } else {
            final tasks = snapshot.data!;
            return ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return ListTile(
                  title: Text(task.name),
                  trailing: Checkbox(
                    value: task.isCompleted,
                    onChanged: (bool? value) async {
                      final updatedTask = Task(task.id, task.name, value ?? false);
                      await database.taskDao.updateTask(updatedTask);
                      (context as Element).reassemble();
                    },
                  ),
                  onLongPress: () async {
                    await database.taskDao.deleteTask(task);
                    (context as Element).reassemble();
                  },
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newTask = Task(DateTime.now().millisecondsSinceEpoch, 'Nueva Tarea', false);
          await database.taskDao.insertTask(newTask);
          (context as Element).reassemble();
        },
        child: Icon(Icons.add),
      ),
    );
  }
}