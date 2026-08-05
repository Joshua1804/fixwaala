import 'package:flutter/material.dart';

import '../../core/theme/app_radii.dart';
import '../../core/theme/app_colors.dart';

/// A [DataTable] wrapped for the admin module: bordered card, horizontal
/// scroll so wide tables degrade gracefully instead of overflowing on
/// narrower browser windows, and full-width columns.
class AdminTableCard extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const AdminTableCard({super.key, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(columns: columns, rows: rows),
            ),
          );
        },
      ),
    );
  }
}
