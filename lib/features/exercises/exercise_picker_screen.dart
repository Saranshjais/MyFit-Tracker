import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'exercise.dart';
import 'exercise_library_view.dart';
import 'exercise_repository.dart';

/// Returns the chosen [Exercise] through `context.pop`.
class ExercisePickerScreen extends ConsumerWidget {
  const ExercisePickerScreen({super.key, this.title = 'Choose exercise'});
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ExerciseLibraryView(
        onTap: (e) => context.pop<Exercise>(e),
        trailingBuilder: (_) => const Icon(Icons.add_circle_outline),
        footer: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: OutlinedButton.icon(
            onPressed: () async {
              final id = await context.push<int>('/workout/exercise/new');
              if (id == null) return;
              final created = await ref.read(exerciseRepositoryProvider).byId(id);
              if (created != null && context.mounted) context.pop<Exercise>(created);
            },
            icon: const Icon(Icons.add),
            label: const Text('Create a custom exercise'),
          ),
        ),
      ),
    );
  }
}
