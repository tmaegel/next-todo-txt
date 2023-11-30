import 'dart:async';
import 'dart:io';

import 'package:ntodotxt/client/webdav_client.dart';
import 'package:ntodotxt/domain/todo/todo_model.dart';
import 'package:ntodotxt/main.dart' show log;
import 'package:rxdart/subjects.dart';

abstract class TodoListApi {
  final File todoFile;

  const TodoListApi({required this.todoFile});

  /// Provides a [Stream] of all todos read from the source.
  Stream<List<Todo>> getTodoList();

  /// Read [todoList] from source.
  Future<void> readFromSource();

  /// Write [todoList] to source.
  Future<void> writeToSource();

  /// Update the state.
  Future<void> update();

  bool existsTodo(Todo todo);

  /// Saves a [todo].
  /// If a [todo] with [id] already exists, it will be replaced.
  /// If the [todo] with [id] already exists it will be updated/merged.
  void saveTodo(Todo todo);

  /// Saves multiple [todos] by [id] at once.
  void saveMultipleTodos(List<Todo> todos);

  /// Deletes the given [todo] by [id].
  void deleteTodo(Todo todo);

  /// Deletes multiple [todos] by [id] at once.
  void deleteMultipleTodos(List<Todo> todos);
}

class LocalTodoListApi extends TodoListApi {
  LocalTodoListApi({required super.todoFile}) {
    // Use synchronize versions here.
    if (todoFile.existsSync() == false) {
      log.fine('File ${todoFile.path} does not exist. Creating.');
      todoFile.createSync();
    } else {
      log.fine('File ${todoFile.path} exists already.');
    }
    updateList(readSync()); // Read synchrone here.
  }

  /// Provides a [Stream] of all todos.
  // A special Streamcontroller that captures the latest item that has been
  // added to the controller, and emits that as the first item to any new listener.
  final controller = BehaviorSubject<List<Todo>>.seeded(const []);

  List<Todo> get _todoList => controller.value;

  void updateList(List<Todo> todoList) {
    log.fine('Update todo list');
    _dispatch(todoList);
  }

  void addToList(Todo value) {
    log.fine('Add todo to todo list');
    List<Todo> todoList = [..._todoList, value];
    _dispatch(todoList);
  }

  void _dispatch(List<Todo> todoList) {
    controller.add(todoList);
    log.finest(
      'Updated todos ${[for (var todo in _todoList) todo.toDebugString()]}',
    );
  }

  void dispose() {
    controller.close();
  }

  Future<List<Todo>> read() async {
    log.info('Async-read todos from file');
    final lines = await todoFile.readAsLines();
    return [for (var t in lines) Todo.fromString(value: t)];
  }

  List<Todo> readSync() {
    log.info('Sync-read todos from file');
    final lines = todoFile.readAsLinesSync();
    return [for (var t in lines) Todo.fromString(value: t)];
  }

  void writeSync(String content) {
    log.info('Sync-write todos to file');
    todoFile.writeAsStringSync(content);
  }

  @override
  Stream<List<Todo>> getTodoList() => controller.asBroadcastStream();

  @override
  Future<void> readFromSource() async => await update();

  @override
  Future<void> writeToSource() async {
    // Using the sync version here.
    // Otherwise it produces multiple MODIFY events.
    writeSync(
      _todoList.join(Platform.lineTerminator),
    );
  }

  /// Only update the state based on the file content.
  /// This function is necessary because the readFromSource
  /// function can change with other inheritances.
  @override
  Future<void> update() async => updateList(await read());

  @override
  bool existsTodo(Todo todo) =>
      _todoList.indexWhere((t) => t.id == todo.id) == -1 ? false : true;

  List<Todo> _save(List<Todo> todoList, Todo todo) {
    int index = todoList.indexWhere((t) => t.id == todo.id);
    if (index == -1) {
      // If not exist save the todo.
      log.info('Create new todo');
      todoList.add(todo.copyWith());
    } else {
      // If exist update todo and merge changes only.
      log.info('Update existing todo');
      todoList[index] = todo.copyMerge(todoList[index]);
    }

    return todoList;
  }

  @override
  void saveTodo(Todo todo) {
    log.info('Save todo ${todo.id}');
    List<Todo> todoList = [..._todoList];
    updateList(_save(todoList, todo));
  }

  @override
  void saveMultipleTodos(List<Todo> todos) {
    log.info('Save todos ${[for (var t in todos) t.id]}');
    List<Todo> todoList = [..._todoList];
    for (var todo in todos) {
      todoList = _save(todoList, todo);
    }
    updateList(todoList);
  }

  List<Todo> _delete(List<Todo> todoList, Todo todo) {
    todoList.removeWhere((t) => t.id == todo.id);
    return todoList;
  }

  @override
  void deleteTodo(Todo todo) {
    log.info('Delete todo ${todo.id}');
    List<Todo> todoList = [..._todoList];
    updateList(_delete(todoList, todo));
  }

  @override
  void deleteMultipleTodos(List<Todo> todos) {
    log.info('Delete todos ${[for (var t in todos) t.id]}');
    List<Todo> todoList = [..._todoList];
    for (var todo in todos) {
      todoList = _delete(todoList, todo);
    }
    updateList(todoList);
  }
}

class WebDAVTodoListApi extends LocalTodoListApi {
  final WebDAVClient client;

  WebDAVTodoListApi._({
    required File todoFile,
    required this.client,
  }) : super(todoFile: todoFile);

  factory WebDAVTodoListApi({
    required File todoFile,
    required String server,
    required String baseUrl,
    required String username,
    required String password,
  }) {
    late WebDAVClient client;
    final RegExp exp =
        RegExp(r"(?<schema>^(http|https)):\/\/(?<host>\w+):(?<port>\d+)$");
    final RegExpMatch? match = exp.firstMatch(server);
    if (match != null) {
      String schema = match.namedGroup('schema')!;
      String host = match.namedGroup('host')!;
      int port = int.parse(match.namedGroup('port')!);
      client = WebDAVClient(
        schema: schema,
        host: host,
        port: port,
        baseUrl: baseUrl,
        username: username,
        password: password,
      );
    } else {
      throw const FormatException('Invalid server foramt.');
    }

    return WebDAVTodoListApi._(
      todoFile: todoFile,
      client: client,
    );
  }

  @override
  Future<void> readFromSource() async {
    // Write downloaded file content directly to the file.
    final String content = await downloadFromSource();
    writeSync(content);
    await update();
  }

  @override
  Future<void> writeToSource() async {
    // Read and update file/state from remote source manually before write the changes.
    // Otherwise it is possible that some states are lost in the ListView.
    // @todo: The problem still exists in edit/create mode.
    // await readFromSource();
    // await update();
    // Using the sync version here.
    // Otherwise it produces multiple MODIFY events.
    writeSync(
      _todoList.join(Platform.lineTerminator),
    );
    await uploadToSource();
  }

  Future<String> downloadFromSource() async {
    log.info('Download todos from server');
    return await client.download();
  }

  Future<void> uploadToSource() async {
    log.info('Upload todos to server');
    await client.upload(
      content: _todoList.join(Platform.lineTerminator),
    );
  }
}
