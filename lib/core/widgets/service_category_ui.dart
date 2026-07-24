import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_colors.dart';

/// Single source of truth for how a [ServiceCategory] is displayed
/// (icon, label, and the consistent sage icon-container treatment used
/// across the category grid, ticket cards, and job cards).
class ServiceCategoryUi {
  ServiceCategoryUi._();

  static IconData icon(ServiceCategory category) => switch (category) {
    ServiceCategory.plumber => Icons.plumbing,
    ServiceCategory.electrician => Icons.electrical_services,
    ServiceCategory.carpenter => Icons.chair_alt,
    ServiceCategory.unknown => Icons.handyman_rounded,
  };

  static String label(ServiceCategory category) => switch (category) {
    ServiceCategory.plumber => 'Plumbing',
    ServiceCategory.electrician => 'Electrical',
    ServiceCategory.carpenter => 'Carpentry',
    ServiceCategory.unknown => 'Other',
  };

  static Color iconBg({bool selected = false}) =>
      selected ? AppColors.categoryIconSelectedBg : AppColors.categoryIconBg;

  static Color iconBorder() => AppColors.categoryIconBorder;

  static Color iconFg({bool selected = false}) =>
      selected ? AppColors.categoryIconSelectedFg : AppColors.categoryIconFg;
}

/// A display-only category tile that has no corresponding [ServiceCategory]
/// enum value. These always behave like [ServiceCategory.unknown] ("Other")
/// functionally — tapping one opens the same generic create-ticket flow as
/// every other category tile. Purely cosmetic, added to match the design
/// brief's 6-category grid (Plumbing/Electrical/Carpentry/Appliance
/// Repair/Cleaning/Other) without expanding the real data model.
typedef CosmeticCategoryTile = ({String label, IconData icon});

const List<CosmeticCategoryTile> kCosmeticOnlyCategoryTiles = [
  (label: 'Appliance Repair', icon: Icons.kitchen_rounded),
  (label: 'Cleaning', icon: Icons.cleaning_services_rounded),
];
