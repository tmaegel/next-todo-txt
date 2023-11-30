import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ntodotxt/data/todo/todo_list_api.dart';
import 'package:ntodotxt/domain/todo/todo_list_repository.dart';
import 'package:ntodotxt/domain/todo/todo_model.dart';
import 'package:ntodotxt/presentation/todo/states/todo_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File file;
  late TodoListRepository repository;
  final Todo todo = Todo(
    priority: 'A',
    creationDate: DateTime(2022, 11, 1),
    description: 'Write some tests',
    projects: const {'project1'},
    contexts: const {'context1'},
    keyValues: const {'foo': 'bar'},
  );

  setUp(() async {
    // Filewatcher does not work with MemoryFileSystem.
    file = File('/tmp/todo.test');
    await file.create();
    await file.writeAsString(todo.toString(), flush: true); // Initial todo.

    final LocalTodoListApi api = LocalTodoListApi(todoFile: file);
    repository = TodoListRepository(api: api);
  });

  group('Initial', () {
    test('initial state', () {
      final TodoListBloc todoListBloc = TodoListBloc(
        repository: repository,
      );
      expect(todoListBloc.state is TodoListInitial, true);
      expect(todoListBloc.state.filter, TodoListFilter.all);
      expect(todoListBloc.state.order, TodoListOrder.ascending);
      expect(todoListBloc.state.group, TodoListGroupBy.upcoming);
      expect(todoListBloc.state.todoList, []);
    });
  });

  group('TodoListSubscriptionRequested', () {
    test('initial state when TodoListSubscriptionRequested() is called',
        () async {
      final TodoListBloc bloc = TodoListBloc(repository: repository);
      bloc.add(const TodoListSubscriptionRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          TodoListSuccess(todoList: [todo]),
        ]),
      );
    });
  });

  group('TodoListTodoCompletionToggled', () {
    test(
        'state with updated completion state when TodoListTodoCompletionToggled(<todo>, <completion>) is called',
        () async {
      final TodoListBloc bloc = TodoListBloc(repository: repository);
      bloc
        ..add(const TodoListSubscriptionRequested())
        ..add(TodoListTodoCompletionToggled(todo: todo, completion: true));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          // Initial & TodoListSubscriptionRequested
          TodoListSuccess(todoList: [todo]),
          // TodoListTodoCompletionToggled start
          TodoListLoading(todoList: [todo]),
          // saveTodo() within TodoListTodoCompletionToggled
          TodoListSuccess(todoList: [todo]),
          // TodoListTodoCompletionToggled finished
          TodoListSuccess(
            todoList: [todo.copyWith(completion: true)],
          ),
        ]),
      );
    });
    test(
        'state with updated completion state when TodoListTodoCompletionToggled(<todo>, <completion>) is called (not exists)',
        () async {
      final TodoListBloc bloc = TodoListBloc(repository: repository);
      Todo todo2 =
          Todo(description: 'Write more tests'); // Generate new uuid (id)
      bloc
        ..add(const TodoListSubscriptionRequested())
        ..add(TodoListTodoCompletionToggled(todo: todo2, completion: true));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          // Initial & TodoListSubscriptionRequested
          TodoListSuccess(todoList: [todo]),
          // TodoListTodoCompletionToggled start
          TodoListLoading(todoList: [todo]),
          // saveTodo() within TodoListTodoCompletionToggled
          TodoListSuccess(todoList: [todo]),
          // TodoListTodoCompletionToggled finished
          TodoListSuccess(
            todoList: [todo, todo2.copyWith(completion: true)],
          ),
        ]),
      );
    });
  });

  group('TodoListTodoSelectedToggled', () {
    test(
        'state with updated selected state when TodoListTodoSelectedToggled(<todo>) is called',
        () async {
      final TodoListBloc bloc = TodoListBloc(repository: repository);
      bloc
        ..add(const TodoListSubscriptionRequested())
        ..add(
            TodoListTodoSelectedToggled(todo: todo.copyWith(), selected: true));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          TodoListSuccess(todoList: [todo]),
          TodoListSuccess(todoList: [todo.copyWith(selected: true)]),
        ]),
      );
    });
    test(
        'state with updated selected state when TodoListTodoSelectedToggled(<todo>) is called (not exists)',
        () async {
      final TodoListBloc bloc = TodoListBloc(repository: repository);
      Todo todo2 =
          Todo(description: 'Write more tests'); // Generate new uuid (id)
      bloc
        ..add(const TodoListSubscriptionRequested())
        ..add(TodoListTodoSelectedToggled(todo: todo2, selected: true));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          TodoListSuccess(todoList: [todo]),
          TodoListSuccess(todoList: [todo, todo2.copyWith(selected: true)]),
        ]),
      );
    });
  });

  group('TodoListSelectedAll', () {
    test(
        'state with updated selected state when TodoListSelectedAll() is called',
        () async {
      final TodoListBloc bloc = TodoListBloc(repository: repository);
      bloc
        ..add(const TodoListSubscriptionRequested())
        ..add(const TodoListSelectedAll());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          TodoListSuccess(todoList: [todo]),
          TodoListSuccess(todoList: [todo.copyWith(selected: true)]),
        ]),
      );
    });
  });

  group('TodoListUnselectedAll', () {
    test(
        'state with updated selected state when TodoListUnselectedAll() is called',
        () async {
      final TodoListBloc bloc = TodoListBloc(repository: repository);
      bloc
        ..add(const TodoListSubscriptionRequested())
        ..add(const TodoListSelectedAll())
        ..add(const TodoListUnselectedAll());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          TodoListSuccess(todoList: [todo]),
          TodoListSuccess(todoList: [todo.copyWith(selected: true)]),
          TodoListSuccess(todoList: [todo.copyWith(selected: false)]),
        ]),
      );
    });
  });

  group('TodoListOrderChanged', () {
    test(
        'state with updated order property when TodoListOrderChanged(<order>) is called',
        () async {
      final TodoListBloc bloc = TodoListBloc(repository: repository);
      bloc
        ..add(const TodoListSubscriptionRequested())
        ..add(const TodoListOrderChanged(order: TodoListOrder.descending));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          TodoListSuccess(order: TodoListOrder.ascending, todoList: [todo]),
          TodoListSuccess(order: TodoListOrder.descending, todoList: [todo]),
        ]),
      );
    });
  });

  group('TodoListFilterChanged', () {
    test(
        'state with updated filter property when TodoListFilterChanged(<filter>) is called',
        () async {
      final TodoListBloc bloc = TodoListBloc(repository: repository);
      bloc
        ..add(const TodoListSubscriptionRequested())
        ..add(
            const TodoListFilterChanged(filter: TodoListFilter.completedOnly));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          TodoListSuccess(filter: TodoListFilter.all, todoList: [todo]),
          TodoListSuccess(
              filter: TodoListFilter.completedOnly, todoList: [todo]),
        ]),
      );
    });
  });

  group('TodoListGroupByChanged', () {
    test(
        'state with updated group property when TodoListGroupByChanged(<group>) is called',
        () async {
      final TodoListBloc bloc = TodoListBloc(repository: repository);
      bloc
        ..add(const TodoListSubscriptionRequested())
        ..add(const TodoListGroupByChanged(group: TodoListGroupBy.context));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          TodoListSuccess(group: TodoListGroupBy.upcoming, todoList: [todo]),
          TodoListSuccess(group: TodoListGroupBy.context, todoList: [todo]),
        ]),
      );
    });
  });
}
