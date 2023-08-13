import 'package:flutter/material.dart';
import 'package:ntodotxt/constants/todo.dart';

class GenericChip extends StatelessWidget {
  final String label;
  final bool selected;
  final void Function(bool)? onSelected;
  final Color? color;

  const GenericChip({
    required this.label,
    this.selected = false,
    this.onSelected,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      backgroundColor: Colors.black12,
      disabledColor: Colors.black12,
      selectedColor: color ?? defaultChipColor,
      side: const BorderSide(
        style: BorderStyle.none,
        color: Color(0xfff1f1f1),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      // @todo: Set colore for all states.
      labelStyle: const TextStyle(color: Colors.black),
      onSelected:
          onSelected != null ? (bool selected) => onSelected!(selected) : null,
    );
  }
}

class GenericChipGroup extends StatelessWidget {
  final List<Widget> children;

  const GenericChipGroup({
    required this.children,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4.0, // gap between adjacent chips
      runSpacing: 4.0, // gap between lines
      children: children,
    );
  }
}

class InlineChipReadOnly extends StatelessWidget {
  final String label;
  final Color? color;

  const InlineChipReadOnly({
    required this.label,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: color ?? defaultChipColor,
      ),
      child: Text(label),
    );
  }
}
