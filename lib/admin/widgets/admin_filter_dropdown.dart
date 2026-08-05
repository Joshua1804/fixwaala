import 'package:flutter/material.dart';

/// A labeled dropdown filter, generic over the option type. `null` is always
/// a valid selection representing "all" / no filter.
class AdminFilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> options;
  final String Function(T) labelBuilder;
  /// Null disables the dropdown entirely — used when a filter only makes
  /// sense in combination with another one that hasn't been picked yet.
  final ValueChanged<T?>? onChanged;
  final double width;

  const AdminFilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
    this.width = 180,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T?>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        isExpanded: true,
        items: [
          DropdownMenuItem<T?>(value: null, child: const Text('All')),
          ...options.map(
            (o) => DropdownMenuItem<T?>(value: o, child: Text(labelBuilder(o))),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
