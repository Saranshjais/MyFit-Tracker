import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/feedback.dart';
import '../nutrition_providers.dart';
import 'add_food_screen.dart';

/// Browse and correct the food database.
class FoodDatabaseScreen extends ConsumerStatefulWidget {
  const FoodDatabaseScreen({super.key});

  @override
  ConsumerState<FoodDatabaseScreen> createState() => _FoodDatabaseScreenState();
}

class _FoodDatabaseScreenState extends ConsumerState<FoodDatabaseScreen> {
  final _search = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final categories = ref.watch(foodCategoriesProvider).value ?? const <String>[];
    final foods = ref.watch(foodSearchProvider((query: _search.text, category: _category)));
    return Scaffold(
      appBar: AppBar(title: const Text('Food database')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/diet/foods/new'),
        icon: const Icon(Icons.add),
        label: const Text('Custom food'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Search foods', prefixIcon: Icon(Icons.search)),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final c in [null, ...categories])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c ?? 'All'),
                      selected: _category == c,
                      showCheckmark: false,
                      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: _category == c ? p.onAccent : p.text),
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              '"Reference" values come from USDA FoodData Central; "Estimate" values are typical recipes or labels. '
              'Tap a food to see its source or correct it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: AsyncView(
              value: foods,
              builder: (foods) => foods.isEmpty
                  ? const EmptyState(icon: Icons.search_off, title: 'No foods found')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: foods.length,
                      itemBuilder: (context, i) => FoodRow(
                        food: foods[i],
                        showSource: true,
                        onTap: () => context.push('/diet/foods/${foods[i].id}'),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
