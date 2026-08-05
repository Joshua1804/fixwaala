import 'dart:async';

import 'package:flutter/material.dart';

/// A search box that debounces its callback so a fast typist doesn't fire a
/// query per keystroke.
class AdminSearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final double width;

  const AdminSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search…',
    this.width = 280,
  });

  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _controller.clear();
                  _onChanged('');
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
