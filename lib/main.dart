import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'To-Do App',
      theme: ThemeData(primarySwatch: Colors.purple),
      home: TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late Database _database;
  List<Map<String, dynamic>> _todoItems = [];
  List<Map<String, dynamic>> _filteredTodoItems = [];
  final _todoController = TextEditingController();
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _openDatabase().then((database) {
      _database = database;
      _loadTodoItems();
    });
  }

  Future<Database> _openDatabase() async {
    final String dbPath = await getDatabasesPath();
    final String path = join(dbPath, 'todo.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE todo_items(
            id INTEGER PRIMARY KEY,
            title TEXT,
            is_done INTEGER
          )
        ''');
      },
    );
  }

  Future<void> _loadTodoItems() async {
    final List<Map<String, dynamic>> todoItems =
        await _database.query('todo_items');
    setState(() {
      _todoItems = todoItems;
      _filterTodoItems();
    });
  }

  Future<void> _addTodoItem(String title) async {
    await _database.insert(
      'todo_items',
      {'title': title, 'is_done': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _loadTodoItems();
  }

  Future<void> _updateTodoItem(int id, String title) async {
    await _database.update(
      'todo_items',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
    _loadTodoItems();
  }

  Future<void> _toggleTodoItem(int id, bool isDone) async {
    await _database.update(
      'todo_items',
      {'is_done': isDone ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _loadTodoItems();
  }

  Future<void> _deleteTodoItem(int id) async {
    await _database.delete(
      'todo_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    _loadTodoItems();
  }

  void _filterTodoItems() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredTodoItems = _todoItems.reversed.toList();
      });
    } else {
      setState(() {
        _filteredTodoItems = _todoItems
            .where((item) => item['title']
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList();
      });
    }
  }

  void _showEditDialog(int id, String currentTitle) {
    showDialog(
      context: this.context,
      builder: (BuildContext dialogContext) {
        String newTitle = currentTitle;
        return AlertDialog(
          title: Text('Edit Todo'),
          content: TextField(
            controller: TextEditingController(text: currentTitle),
            onChanged: (value) {
              newTitle = value;
            },
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                _updateTodoItem(id, newTitle);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(int id) {
    showDialog(
      context: this.context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Delete Todo'),
          content: Text('Are you sure, Do you want to delete this Todo ?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                _deleteTodoItem(id);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: Text('To-Do Items')),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(7.0),
            margin: const EdgeInsets.all(7.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterTodoItems();
                });
              },
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(42))),
                hintText: 'Search Your Todo',
              ),
            ),
          ),
          RichText(
            text: TextSpan(
                text: 'To-Do Items ',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.purple)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTodoItems.length,
              itemBuilder: (BuildContext context, int index) {
                final todoItem = _filteredTodoItems[index];
                return ListTile(
                  title: Text(
                    todoItem['title'],
                  ),
                  leading: Checkbox(
                    value: todoItem['is_done'] == 1,
                    onChanged: (bool? value) {
                      _toggleTodoItem(todoItem['id'], value ?? false);
                    },
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                        ),
                        onPressed: () {
                          _showEditDialog(todoItem['id'], todoItem['title']);
                        },
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete, color: Color(0xffc41810)),
                        onPressed: () {
                          _showDeleteConfirmationDialog(todoItem['id']);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              children: [
                Expanded(
                    child: Container(
                  margin:
                      const EdgeInsets.only(bottom: 20, right: 20, left: 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.grey,
                        offset: Offset(0.0, 0.0),
                        blurRadius: 10.0,
                        spreadRadius: 0,
                      ),
                    ],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _todoController,
                    decoration: const InputDecoration(
                      hintText: 'Add Your Todo',
                      border: InputBorder.none,
                    ),
                  ),
                )),
                Container(
                  margin: const EdgeInsets.only(bottom: 20, right: 20),
                  child: ElevatedButton(
                    onPressed: () {
                      _addTodoItem(_todoController.text);
                      _todoController.text = "";
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        minimumSize: const Size(60, 60),
                        elevation: 10),
                    child: const Text(
                      "+",
                      style: TextStyle(fontSize: 40),
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
