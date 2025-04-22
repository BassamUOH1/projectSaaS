import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // لاستخدام DateFormat ومنتقي التاريخ
import 'package:saas_project_web/APIdatabase.dart'; // تأكد من صحة المسار

void main() {
  runApp(const MyApp());
}
//   This is UI and API is a functions for backend AWS Lambda I use Go Language for that.
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager Pro',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: false,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        cardTheme: CardTheme(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        ),
      ),
      home: const TaskManagerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final String dueDate;
  bool completed;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    this.completed = false,
  });
}

class TaskManagerPage extends StatefulWidget {
  const TaskManagerPage({Key? key}) : super(key: key);

  @override
  _TaskManagerPageState createState() => _TaskManagerPageState();
}

class _TaskManagerPageState extends State<TaskManagerPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  DateTime? _selectedDueDate;
String State_Completed ="No Completed";
  List<Task> _tasks = [];
  bool _isLoading = false;
bool _isCompleted =false;
  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDueDate) {
      setState(() {
        _selectedDueDate = picked;
        _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final items = await getall();
      setState(() {
        _tasks = items.map<Task>((item) {
          final id = item['id']?.toString() ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';
          final title = item['ID']?.toString() ?? 'بدون عنوان';
          final description = item['Name']?.toString() ?? '';
          final dueDate = item['Pass']?.toString() ?? '';
          final status = item['Data_1']?.toString() ?? 'Not Completed';
          final bool isCompleted = status.trim().toLowerCase() == 'completed';

          return Task(
            id: id,
            title: title,
            description: description,
            dueDate: dueDate,
            completed: isCompleted,
          );
        }).toList();
        _tasks.sort((a, b) {
          if (a.completed != b.completed) return a.completed ? 1 : -1;
          return a.title.compareTo(b.title);
        });
      });
    } catch (e) {
      _showSnackBar('خطأ في تحميل المهام: \$e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addTask() async {
    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();
    final due = _dueDateController.text.trim();

    if (title.isEmpty || due.isEmpty) {
      _showSnackBar('Please enter the title and due date', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await creatTableBigData('SaaS', title, desc, due, State_Completed, '-', '-', '-');
      _showSnackBar('Creat we create a new Task (:');
      _titleController.clear();
      _descriptionController.clear();
      _dueDateController.clear();
      _selectedDueDate = null;
      _loadTasks();
    } catch (e) {
      _showSnackBar('فشل إضافة المهمة: \$e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTask(String id) async {

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(' Sure for Delet?'),
        content: const Text('Are you sure ??  \n (;'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delet'),
            onPressed: ()async{
              await deleteItem("SaaS", id);
              Navigator.of(ctx).pop(true);},
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await deleteItem('SaaS', id);
      _showSnackBar('Done for Deleted');
      _loadTasks();
    } catch (e) {
      _showSnackBar('فشل الحذف: \$e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleComplete(Task task) async {
    final newStatus = !task.completed;
    final statusText = newStatus ? 'Completed' : 'Not Completed';

    setState(() {
      task.completed = newStatus;
      _tasks.sort((a, b) {
        if (a.completed != b.completed) return a.completed ? 1 : -1;
        return a.title.compareTo(b.title);
      });
    });

    setState(() => _isLoading = true);
    try {
      await creatTableBigData('SaaS', task.id, task.description, task.dueDate, statusText, '-', '-', '-');
      _showSnackBar('تم تحديث  ');
    } catch (e) {
      _showSnackBar('فشل تحديث : \$e', isError: true);
      setState(() {
        task.completed = !newStatus;
        _tasks.sort((a, b) {
          if (a.completed != b.completed) return a.completed ? 1 : -1;
          return a.title.compareTo(b.title);
        });
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadTasks,
            tooltip: 'Update',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Form(
              key: _formKey,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Add New Task',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title*',
                          hintText: 'Enter task title',
                          prefixIcon: Icon(Icons.title),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'Enter task description',
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dueDateController,
                        decoration: const InputDecoration(
                          labelText: 'Due Date*',
                          hintText: 'Select the due date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () => _selectDueDate(context),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Radio<bool>(
                            value: false,
                            groupValue: _isCompleted,
                            onChanged: (bool? value) {
                              setState(() { _isCompleted = value!;
                              State_Completed ="No Completed";
                              });
                            },
                          ),
                          const Text('Not Completed'),
                          const SizedBox(width: 20),
                          Radio<bool>(
                            value: true,
                            groupValue: _isCompleted,
                            onChanged: (bool? value) {
                              setState(() { _isCompleted = value!;
                              State_Completed ="Completed";
                              });
                            },
                          ),
                          const Text('Completed'),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_task),
                        label: const Text("Add Task"),
                        onPressed: _isLoading ? null : _addTask,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          Expanded(
            child: _tasks.isEmpty && !_isLoading
                ? Center(
              child: Text(
                'لا توجد مهام حالياً.\nقم بإضافة مهمة جديدة!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            )
                : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (ctx, i) {
                final task = _tasks[i];
                return Card(
                  color: task.completed ? Colors.grey[300] : Colors.white,
                  child: ListTile(
                    leading: Checkbox(
                      value: task.completed,
                      onChanged: (_) => _toggleComplete(task),
                      activeColor: Colors.indigo,
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: task.completed ? TextDecoration.lineThrough : null,
                        color: task.completed ? Colors.grey[700] : Colors.black87,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (task.description.isNotEmpty)
                          Text('Description: ${task.description}'),
                        Text('Due Date: ${task.dueDate}'),
                        Text('Status: ${task.completed ? "Completed" : "Incomplete"}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteTask(task.title),
                      color: Colors.redAccent,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
