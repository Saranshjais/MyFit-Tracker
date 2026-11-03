import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/widgets/cards.dart';

IconData foodCategoryIcon(String category) => switch (category) {
  'Roti & Breads' => Icons.bakery_dining,
  'Rice & Grains' => Icons.rice_bowl,
  'Breakfast Dishes' => Icons.breakfast_dining,
  'Dal & Legumes' => Icons.soup_kitchen,
  'Paneer & Soy' => Icons.view_module_rounded,
  'Dairy' => Icons.local_drink,
  'Vegetables & Salad' => Icons.eco,
  'Fruits' => Icons.spa,
  'Nuts & Seeds' => Icons.grain,
  'Oils & Fats' => Icons.opacity,
  'Beverages' => Icons.coffee,
  'Supplements' => Icons.science,
  _ => Icons.restaurant,
};

IconData mealCategoryIcon(String category) => switch (category.toLowerCase()) {
  'breakfast' => Icons.free_breakfast,
  'lunch' => Icons.lunch_dining,
  'evening snack' => Icons.cookie,
  'dinner' => Icons.dinner_dining,
  _ => Icons.restaurant,
};

class FoodThumb extends StatelessWidget {
  const FoodThumb({super.key, required this.category, this.size = 44});
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) =>
      IconTile(icon: foodCategoryIcon(category), size: size, color: context.palette.carbs);
}
