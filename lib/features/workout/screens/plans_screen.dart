import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/feedback.dart';
import '../models.dart';
import '../workout_providers.dart';

/// Create, rename, duplicate, delete and activate weekly plans.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  void _bump(WidgetRef ref) => ref.read(workoutRevisionProvider.notifier).bump();

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showTextInputDialog(context, title: 'New plan', label: 'Plan name', confirm: 'Create');
    if (name == null) return;
    final repo = ref.read(planRepositoryProvider);
    final id = await repo.createPlan(name);
    await repo.setActive(id);
    _bump(ref);
    if (context.mounted) {
      showSnack(context, '"$name" is now your active plan. Tap a day to add exercises.');
      context.go('/workout');
    }
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, WorkoutPlan plan, String action) async {
    final repo = ref.read(planRepositoryProvider);
    switch (action) {
      case 'activate':
        await repo.setActive(plan.id);
        _bump(ref);
        if (context.mounted) showSnack(context, '"${plan.name}" is now active.');
      case 'rename':
        final name = await showTextInputDialog(context, title: 'Rename plan', initial: plan.name);
        if (name == null) return;
        await repo.renamePlan(plan.id, name);
        _bump(ref);
      case 'duplicate':
        await repo.duplicatePlan(plan.id);
        _bump(ref);
        if (context.mounted) showSnack(context, 'Copy created.');
      case 'delete':
        final ok = await showConfirmDialog(
          context,
          title: 'Delete "${plan.name}"?',
          message: 'The plan is removed. Workouts you already logged stay in your history.',
          confirm: 'Delete',
          destructive: true,
        );
        if (!ok) return;
        await repo.deletePlan(plan.id);
        _bump(ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Workout plans')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New plan'),
      ),
      body: AsyncView(
        value: plans,
        builder: (plans) {
          if (plans.isEmpty) {
            return EmptyState(
              icon: Icons.event_note,
              title: 'No plans yet',
              message: 'Create a plan and choose which days you train.',
              action: 'Create plan',
              onAction: () => _create(context, ref),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text('Your active plan drives the dashboard, the week view and workout reminders.', style: t.bodySmall),
              const SizedBox(height: 12),
              for (final plan in plans) ...[
                AppCard(
                  highlighted: plan.isActive,
                  onTap: plan.isActive ? () => context.go('/workout') : () => _onMenu(context, ref, plan, 'activate'),
                  padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                  child: Row(
                    children: [
                      Icon(
                        plan.isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: plan.isActive ? p.accentText : p.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(plan.name, style: t.titleSmall, overflow: TextOverflow.ellipsis),
                                ),
                                if (plan.isSample) ...[const SizedBox(width: 6), Badge2('Sample', color: p.warning)],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(plan.isActive ? 'Active' : 'Tap to make active', style: t.bodySmall),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (a) => _onMenu(context, ref, plan, a),
                        itemBuilder: (_) => [
                          if (!plan.isActive) const PopupMenuItem(value: 'activate', child: Text('Make active')),
                          const PopupMenuItem(value: 'rename', child: Text('Rename')),
                          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}
