import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/feedback.dart';
import 'exercise.dart';
import 'exercise_repository.dart';
import 'exercise_thumb.dart';

/// Searchable, filterable exercise list. Used by the Workout tab (browse)
/// and by the exercise picker.
class ExerciseLibraryView extends ConsumerStatefulWidget {
  const ExerciseLibraryView({super.key, required this.onTap, this.trailingBuilder, this.footer});

  final ValueChanged<Exercise> onTap;
  final Widget Function(Exercise exercise)? trailingBuilder;
  final Widget? footer;

  @override
  ConsumerState<ExerciseLibraryView> createState() => _ExerciseLibraryViewState();
}

class _ExerciseLibraryViewState extends ConsumerState<ExerciseLibraryView> {
  final _search = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final exercises = ref.watch(exercisesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search exercises or muscles…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final m in ['All', ...muscleGroups])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(m),
                    selected: _filter == m,
                    showCheckmark: false,
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, color: _filter == m ? p.onAccent : p.text),
                    onSelected: (_) => setState(() => _filter = m),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView(
            value: exercises,
            onRetry: () => ref.invalidate(exercisesProvider),
            builder: (all) {
              final q = _search.text.trim().toLowerCase();
              final items = all
                  .where((e) => _filter == 'All' || e.muscle == _filter)
                  .where(
                    (e) =>
                        q.isEmpty ||
                        e.name.toLowerCase().contains(q) ||
                        e.equipment.toLowerCase().contains(q) ||
                        e.muscle.toLowerCase().contains(q) ||
                        e.allMuscles.any(
                          (m) =>
                              m.label.toLowerCase().contains(q) ||
                              m.anatomy.toLowerCase().contains(q) ||
                              m.part.label.toLowerCase().contains(q),
                        ),
                  )
                  .toList();
              if (items.isEmpty) {
                return ListView(
                  children: [
                    const EmptyState(
                      icon: Icons.search_off,
                      title: 'No exercises found',
                      message: 'Try another search or add a custom exercise.',
                    ),
                    ?widget.footer,
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: items.length + (widget.footer == null ? 0 : 1),
                itemBuilder: (context, i) {
                  if (i == items.length) return widget.footer!;
                  final e = items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(10),
                      onTap: () => widget.onTap(e),
                      child: Row(
                        children: [
                          ExerciseThumb(exercise: e, size: 52),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        e.name,
                                        style: Theme.of(context).textTheme.titleSmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (e.isCustom) ...[const SizedBox(width: 6), const Badge2('Custom')],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text('${e.equipment} · ${e.muscle}', style: Theme.of(context).textTheme.bodySmall),
                                if (e.targetMuscles.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: e.targetMuscles.map((m) => m.label).join(', '),
                                          style: TextStyle(color: p.accentText, fontWeight: FontWeight.w600),
                                        ),
                                        if (e.assistMuscles.isNotEmpty)
                                          TextSpan(text: ' · ${e.assistMuscles.map((m) => m.label).join(', ')}'),
                                      ],
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          ?widget.trailingBuilder?.call(e),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
