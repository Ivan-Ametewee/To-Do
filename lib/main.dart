import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkTheme = false;

  void toggleTheme() {
    setState(() {
      isDarkTheme = !isDarkTheme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: isDarkTheme ? ThemeData.dark() : ThemeData.light(),
      home: MyHomePage(
        title: 'To Do List',
        toggleTheme: toggleTheme, // Pass toggleTheme as a reference
      ),
    );
  }
}


class MyHomePage extends StatefulWidget {
  final String title;
  final VoidCallback toggleTheme;

  const MyHomePage({super.key, required this.title, required this.toggleTheme});


  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<_CheckboxItem> isCheckedList = []; // List to store checkbox items
  final TextEditingController _controller = TextEditingController();
  Timer? countdownTimer;
  List<_CheckboxItem> deletedTasks = [];
  


  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    // Dispose of the controller
    _controller.dispose();

    // Dispose of any active timers for each task to prevent memory leaks
    for (var item in isCheckedList) {
      item.countdownTimer?.cancel();
    }

    // Cancel any other global timer
    countdownTimer?.cancel();

    super.dispose();
  }

  Future<void> saveTasks(List<_CheckboxItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    // Convert each task to string for saving
    List<String> taskNames = tasks.map((task) => task.taskName).toList();
    await prefs.setStringList('tasks', taskNames);
  }

  Future<List<String>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('tasks') ?? [];
  }

  Future<void> _loadTasks() async {
    final savedTasks = await loadTasks();
    setState(() {
      isCheckedList = savedTasks.map((task) => _CheckboxItem(taskName: task)).toList();
    });
  }

  Future<void> _addTask(String taskName) async {
    setState(() {
      isCheckedList.add(_CheckboxItem(taskName: taskName));
    });
    _controller.clear();
    await saveTasks(isCheckedList); // Save updated tasks
  }

  Future<void> saveDeletedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> deletedTaskNames = deletedTasks.map((task) => task.taskName).toList();
    await prefs.setStringList('deleted_tasks', deletedTaskNames);
  }

  Future<void> loadDeletedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? deletedTaskNames = prefs.getStringList('deleted_tasks');
    if (deletedTaskNames != null) {
      setState(() {
        deletedTasks = deletedTaskNames.map((name) => _CheckboxItem(taskName: name)).toList();
      });
    }
  }

  void startCountdown(_CheckboxItem item, int index) {
    item.checkedTime = DateTime.now();

    // Cancel any existing timer on this specific item to prevent conflicts
    item.countdownTimer?.cancel();

    item.countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});

      // Calculate remaining time
      int remainingTime = 20 - DateTime.now().difference(item.checkedTime!).inSeconds;

      if (remainingTime <= 0) {
        // Remove the item once countdown reaches 0
        setState(() {
          deletedTasks.add(item);
          isCheckedList.removeAt(index);
          saveDeletedTasks();
        });
        timer.cancel();
      } else if (!item.isChecked) {
        // Stop the timer if the item is unchecked
        timer.cancel();
      }
    });
  }


  void _handleAddButtonPressed() {
    if (_controller.text.isNotEmpty) {
      _addTask(_controller.text);
    }
  }

  void _handleRemoveButtonPressed() {
    if (isCheckedList.isNotEmpty) {
      setState(() {
        isCheckedList.removeLast();
      });
    }
  }

  void _showDeletedTasksDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Deleted Tasks"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: deletedTasks.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(deletedTasks[index].taskName),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() {
                        deletedTasks.removeAt(index);
                        saveDeletedTasks();
                      });
                    },
                    child: const Text('Delete Permanently'),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'change_theme') {
                widget.toggleTheme();
              } else if (value == 'show_deleted') {
                _showDeletedTasksDialog();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'change_theme',
                  child: Text('Change Theme'),
                ),
                const PopupMenuItem(
                  value: 'show_deleted',
                  child: Text('Show Deleted Tasks'),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Type the new task here...',
                contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(32.0)),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: isCheckedList.length,
              itemBuilder: (context, index) {
                _CheckboxItem item = isCheckedList[index];
                return CheckboxListTile(
                  value: item.isChecked,
                  onChanged: (value) {
                    setState(() {
                      item.isChecked = value!;
                      if (item.isChecked) {
                        startCountdown(item, index);
                      } else {
                        countdownTimer?.cancel();
                      }
                    });
                  },
                  title: Text(item.taskName),
                  subtitle: item.isChecked
                      ? Text(
                          'Will be removed in ${20 - DateTime.now().difference(item.checkedTime!).inSeconds} seconds',
                        )
                      : null,
                  activeColor: Colors.green,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 20.0,
            right: 20.0,
            child: FloatingActionButton(
              onPressed: _handleAddButtonPressed,
              child: const Icon(Icons.add),
            ),
          ),
          Positioned(
            bottom: 20.0,
            left: 20.0,
            child: FloatingActionButton(
              onPressed: _handleRemoveButtonPressed,
              child: const Icon(Icons.remove),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckboxItem {
  bool isChecked = false;
  DateTime? checkedTime;
  Timer? countdownTimer; // Add an individual timer for each item
  final String taskName;

  _CheckboxItem({required this.taskName/*, this.checkedTime*/});
}
