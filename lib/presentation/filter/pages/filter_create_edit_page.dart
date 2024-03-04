import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ntodotxt/common_widgets/app_bar.dart';
import 'package:ntodotxt/common_widgets/chip.dart';
import 'package:ntodotxt/common_widgets/confirm_dialog.dart';
import 'package:ntodotxt/common_widgets/contexts_dialog.dart';
import 'package:ntodotxt/common_widgets/filter_dialog.dart';
import 'package:ntodotxt/common_widgets/group_by_dialog.dart';
import 'package:ntodotxt/common_widgets/order_dialog.dart';
import 'package:ntodotxt/common_widgets/priorities_dialog.dart';
import 'package:ntodotxt/common_widgets/projects_dialog.dart';
import 'package:ntodotxt/constants/app.dart';
import 'package:ntodotxt/domain/filter/filter_model.dart' show Filter;
import 'package:ntodotxt/domain/filter/filter_repository.dart';
import 'package:ntodotxt/domain/settings/setting_repository.dart';
import 'package:ntodotxt/domain/todo/todo_model.dart' show Priority;
import 'package:ntodotxt/misc.dart' show SnackBarHandler;
import 'package:ntodotxt/presentation/filter/states/filter_cubit.dart';
import 'package:ntodotxt/presentation/filter/states/filter_state.dart';

class FilterCreateEditPage extends StatelessWidget {
  final Filter? initFilter;
  final Set<String> projects;
  final Set<String> contexts;

  const FilterCreateEditPage({
    this.initFilter,
    this.projects = const {},
    this.contexts = const {},
    super.key,
  });

  bool get createMode => initFilter == null;

  @override
  Widget build(BuildContext context) {
    final bool narrowView =
        MediaQuery.of(context).size.width < maxScreenWidthCompact;
    bool keyboardIsOpen = MediaQuery.of(context).viewInsets.bottom != 0;

    return BlocProvider(
      create: (BuildContext context) => FilterCubit(
        settingRepository: context.read<SettingRepository>(),
        filterRepository: context.read<FilterRepository>(),
        filter: initFilter,
      ),
      child: BlocListener<FilterCubit, FilterState>(
        listener: (BuildContext context, FilterState state) {
          if (state is FilterError) {
            SnackBarHandler.error(context, state.message);
          }
        },
        child: GestureDetector(
          onTap: () {
            FocusScopeNode currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus) {
              currentFocus.unfocus();
            }
          },
          child: Scaffold(
            appBar: MainAppBar(
              title: createMode ? 'Create' : 'Edit',
              toolbar: Row(
                children: <Widget>[
                  if (!createMode) const DeleteFilterIconButton(),
                  if (!narrowView) SaveFilterIconButton(initFilter: initFilter),
                ],
              ),
            ),
            body: ListView(
              children: [
                const FilterNameTextField(),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ListTile(
                    title: Text(
                      'General',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                const FilterOrderItem(),
                const FilterFilterItem(),
                const FilterGroupItem(),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ListTile(
                    title: Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                const FilterPrioritiesItem(),
                FilterProjectTagsItem(availableTags: projects),
                FilterContextTagsItem(availableTags: contexts),
                const SizedBox(height: 16),
              ],
            ),
            floatingActionButton: keyboardIsOpen || !narrowView
                ? null
                : SaveFilterFABButton(initFilter: initFilter),
          ),
        ),
      ),
    );
  }
}

class FilterNameTextField extends StatefulWidget {
  const FilterNameTextField({super.key});

  @override
  State<FilterNameTextField> createState() => _FilterNameTextFieldState();
}

class _FilterNameTextFieldState extends State<FilterNameTextField> {
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
    return BlocBuilder<FilterCubit, FilterState>(
      builder: (BuildContext context, FilterState state) {
        _controller.text = state.filter.name;
        return TextFormField(
          key: _textFormKey,
          controller: _controller,
          minLines: 1,
          maxLines: 1,
          enableInteractiveSelection: true,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          keyboardType: TextInputType.text,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\n')),
          ],
          style: Theme.of(context).textTheme.titleMedium,
          decoration: const InputDecoration(
            hintText: 'Filter name',
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
          ),
          onChanged: (String value) =>
              context.read<FilterCubit>().updateName(value),
        );
      },
    );
  }
}

class DeleteFilterIconButton extends StatelessWidget {
  const DeleteFilterIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterCubit, FilterState>(
      builder: (BuildContext context, FilterState state) {
        return IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete),
          onPressed: () async {
            final bool confirm = await ConfirmationDialog.dialog(
              context: context,
              title: 'Delete filter',
              message: 'Do you want to delete the filter?',
              actionLabel: 'Delete',
            );
            if (context.mounted && confirm) {
              await context.read<FilterCubit>().delete(state.filter);
              if (context.mounted) {
                SnackBarHandler.info(context, 'Filter deleted');
                context.pop();
              }
            }
          },
        );
      },
    );
  }
}

class SaveFilterIconButton extends StatelessWidget {
  final Filter? initFilter;

  const SaveFilterIconButton({
    required this.initFilter,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterCubit, FilterState>(
      builder: (BuildContext context, FilterState state) {
        return Visibility(
          visible: initFilter != state.filter && state.filter.name.isNotEmpty,
          child: IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save),
            onPressed: () async {
              if (initFilter == null) {
                await context.read<FilterCubit>().create(state.filter);
              } else {
                await context.read<FilterCubit>().update(state.filter);
              }
              if (context.mounted) {
                SnackBarHandler.info(context, 'Filter saved');
                context.pop();
              }
            },
          ),
        );
      },
    );
  }
}

class SaveFilterFABButton extends StatelessWidget {
  final Filter? initFilter;

  const SaveFilterFABButton({
    required this.initFilter,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterCubit, FilterState>(
      builder: (BuildContext context, FilterState state) {
        return Visibility(
          visible: initFilter != state.filter && state.filter.name.isNotEmpty,
          child: FloatingActionButton(
            tooltip: 'Save',
            child: const Icon(Icons.save),
            onPressed: () async {
              if (initFilter == null) {
                await context.read<FilterCubit>().create(state.filter);
              } else {
                await context.read<FilterCubit>().update(state.filter);
              }
              if (context.mounted) {
                SnackBarHandler.info(context, 'Filter saved');
                context.pop();
              }
            },
          ),
        );
      },
    );
  }
}

class FilterOrderItem extends StatelessWidget {
  const FilterOrderItem({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterCubit, FilterState>(
      buildWhen: (FilterState previousState, FilterState state) {
        return previousState.filter.order != state.filter.order;
      },
      builder: (BuildContext context, FilterState state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ListTile(
            leading: const Icon(Icons.sort),
            title: const Text('Order'),
            subtitle: GenericChipGroup(
              children: [
                BasicChip(label: state.filter.order.name),
              ],
            ),
            onTap: () async {
              await FilterStateOrderDialog.dialog(
                context: context,
                cubit: BlocProvider.of<FilterCubit>(context),
              );
            },
          ),
        );
      },
    );
  }
}

class FilterFilterItem extends StatelessWidget {
  const FilterFilterItem({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterCubit, FilterState>(
      buildWhen: (FilterState previousState, FilterState state) {
        return previousState.filter.filter != state.filter.filter;
      },
      builder: (BuildContext context, FilterState state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ListTile(
            leading: const Icon(Icons.filter_list),
            title: const Text('Filter'),
            subtitle: GenericChipGroup(
              children: [
                BasicChip(label: state.filter.filter.name),
              ],
            ),
            onTap: () async {
              await FilterStateFilterDialog.dialog(
                context: context,
                cubit: BlocProvider.of<FilterCubit>(context),
              );
            },
          ),
        );
      },
    );
  }
}

class FilterGroupItem extends StatelessWidget {
  const FilterGroupItem({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterCubit, FilterState>(
      buildWhen: (FilterState previousState, FilterState state) {
        return previousState.filter.group != state.filter.group;
      },
      builder: (BuildContext context, FilterState state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ListTile(
            leading: const Icon(Icons.workspaces_outlined),
            title: const Text('Group by'),
            subtitle: GenericChipGroup(
              children: [
                BasicChip(
                  label: state.filter.group.name,
                ),
              ],
            ),
            onTap: () async {
              await FilterStateGroupDialog.dialog(
                context: context,
                cubit: BlocProvider.of<FilterCubit>(context),
              );
            },
          ),
        );
      },
    );
  }
}

class FilterPrioritiesItem extends StatelessWidget {
  const FilterPrioritiesItem({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterCubit, FilterState>(
      buildWhen: (FilterState previousState, FilterState state) {
        return previousState.filter.priorities != state.filter.priorities;
      },
      builder: (BuildContext context, FilterState state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Priorities'),
            subtitle: state.filter.priorities.isEmpty
                ? const Text('-')
                : GenericChipGroup(
                    children: [
                      for (var t in state.filter.priorities)
                        BasicChip(label: t.name),
                    ],
                  ),
            onTap: () async {
              await FilterPriorityTagDialog.dialog(
                context: context,
                cubit: BlocProvider.of<FilterCubit>(context),
                availableTags: Priority.values.toSet(),
              );
            },
          ),
        );
      },
    );
  }
}

class FilterProjectTagsItem extends StatelessWidget {
  final Set<String> availableTags;

  const FilterProjectTagsItem({
    this.availableTags = const {},
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterCubit, FilterState>(
      buildWhen: (FilterState previousState, FilterState state) {
        return previousState.filter.projects != state.filter.projects;
      },
      builder: (BuildContext context, FilterState state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ListTile(
            leading: const Icon(Icons.rocket_launch_outlined),
            title: const Text('Projects'),
            subtitle: state.filter.projects.isEmpty
                ? const Text('-')
                : GenericChipGroup(
                    children: [
                      for (var t in state.filter.projects) BasicChip(label: t),
                    ],
                  ),
            onTap: () async {
              await FilterProjectTagDialog.dialog(
                context: context,
                cubit: BlocProvider.of<FilterCubit>(context),
                availableTags: availableTags,
              );
            },
          ),
        );
      },
    );
  }
}

class FilterContextTagsItem extends StatelessWidget {
  final Set<String> availableTags;

  const FilterContextTagsItem({
    this.availableTags = const {},
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterCubit, FilterState>(
      buildWhen: (FilterState previousState, FilterState state) {
        return previousState.filter.contexts != state.filter.contexts;
      },
      builder: (BuildContext context, FilterState state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ListTile(
            leading: const Icon(Icons.join_inner),
            title: const Text('Contexts'),
            subtitle: state.filter.contexts.isEmpty
                ? const Text('-')
                : GenericChipGroup(
                    children: [
                      for (var t in state.filter.contexts) BasicChip(label: t),
                    ],
                  ),
            onTap: () async {
              await FilterContextTagDialog.dialog(
                context: context,
                cubit: BlocProvider.of<FilterCubit>(context),
                availableTags: availableTags,
              );
            },
          ),
        );
      },
    );
  }
}
