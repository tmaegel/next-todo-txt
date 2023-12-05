import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ntodotxt/common_widgets/chip.dart';
import 'package:ntodotxt/presentation/todo/states/todo_bloc.dart';
import 'package:ntodotxt/presentation/todo/states/todo_event.dart';

class TodoTagDialog extends StatefulWidget {
  final String tagName;
  final Set<String> availableTags;

  const TodoTagDialog({
    required this.tagName,
    this.availableTags = const {},
    super.key,
  });

  void onSubmit(BuildContext context, List<String> values) {}

  @override
  State<TodoTagDialog> createState() => _TodoTagDialogState();
}

class _TodoTagDialogState<T extends TodoTagDialog> extends State<T> {
  // Holds the selected tags before adding to the regular state.
  List<String> selectedTags = [];

  late GlobalKey<FormFieldState> _textFormKey;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _textFormKey = GlobalKey<FormFieldState>();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheet(
      enableDrag: false,
      showDragHandle: false,
      onClosing: () {},
      builder: (BuildContext context) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 16.0,
          ),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: TextFormField(
                key: _textFormKey,
                controller: _controller,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText:
                      'Enter <${widget.tagName}> tags seperated by whitespace ...',
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
              trailing: IconButton.filled(
                icon: const Icon(Icons.done),
                tooltip: 'Add ${widget.tagName} tags',
                onPressed: () {
                  // Remove duplicate whitespaces from input
                  // and split string by whitespaces.
                  final List<String> addedTags = _controller.text
                      .trim()
                      .replaceAllMapped(RegExp(r'\s+'), (match) {
                    return ' ';
                  }).split(' ')
                    ..removeWhere((value) => value.isEmpty);
                  widget.onSubmit(context, [...addedTags, ...selectedTags]);
                  Navigator.pop(context);
                },
              ),
            ),
            if (widget.availableTags.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: GenericChipGroup(
                  children: [
                    for (var t in widget.availableTags)
                      GenericChoiceChip(
                        label: Text(t),
                        selected: selectedTags.contains(t),
                        onSelected: (bool selected) {
                          if (selected) {
                            setState(() {
                              selectedTags.add(t);
                            });
                          } else {
                            setState(() {
                              selectedTags.remove(t);
                            });
                          }
                        },
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class TodoProjectTagDialog extends TodoTagDialog {
  const TodoProjectTagDialog({
    super.tagName = 'project',
    super.availableTags,
    super.key = const Key('addProjectTagDialog'),
  });

  @override
  void onSubmit(BuildContext context, List<String> values) {
    context.read<TodoBloc>().add(TodoProjectsAdded(values));
  }

  @override
  State<TodoProjectTagDialog> createState() => _TodoProjectTagDialogState();
}

class _TodoProjectTagDialogState
    extends _TodoTagDialogState<TodoProjectTagDialog> {}

class TodoContextTagDialog extends TodoTagDialog {
  const TodoContextTagDialog({
    super.tagName = 'context',
    super.availableTags,
    super.key = const Key('addContextTagDialog'),
  });

  @override
  void onSubmit(BuildContext context, List<String> values) {
    context.read<TodoBloc>().add(TodoContextsAdded(values));
  }

  @override
  State<TodoContextTagDialog> createState() => _TodoContextTagDialogState();
}

class _TodoContextTagDialogState
    extends _TodoTagDialogState<TodoContextTagDialog> {}

class TodoKeyValueTagDialog extends TodoTagDialog {
  const TodoKeyValueTagDialog({
    super.tagName = 'key:value',
    super.availableTags,
    super.key = const Key('addKeyValueTagDialog'),
  });

  @override
  void onSubmit(BuildContext context, List<String> values) {
    context.read<TodoBloc>().add(TodoKeyValuesAdded(values));
  }

  @override
  State<TodoKeyValueTagDialog> createState() => _TodoKeyValueTagDialogState();
}

class _TodoKeyValueTagDialogState
    extends _TodoTagDialogState<TodoKeyValueTagDialog> {}
