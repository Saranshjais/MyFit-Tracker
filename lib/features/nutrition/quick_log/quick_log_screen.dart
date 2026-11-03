import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../food_visuals.dart';
import '../nutrition_models.dart';
import '../nutrition_providers.dart';
import '../screens/food_sheets.dart';
import 'meal_text_parser.dart';
import 'voice_input.dart';

/// Every food, including custom ones, for matching spoken words.
final allFoodsProvider = FutureProvider.autoDispose<List<FoodItem>>((ref) {
  ref.watch(nutritionRevisionProvider);
  return ref.watch(foodRepositoryProvider).search(limit: 5000);
});

/// Log a whole meal by speaking or typing it, e.g. "2 roti, 1 bowl dal and a
/// glass of milk". The sentence is matched against the local food list and
/// shown for review before anything is saved.
class QuickLogScreen extends ConsumerStatefulWidget {
  const QuickLogScreen({super.key, this.date, this.category});
  final String? date;
  final String? category;

  @override
  ConsumerState<QuickLogScreen> createState() => _QuickLogScreenState();
}

class _QuickLogScreenState extends ConsumerState<QuickLogScreen> {
  final _text = TextEditingController();
  bool _listening = false;
  String _textBeforeListening = '';
  String? _voiceError;
  String? _meal;
  bool _saving = false;

  /// Changes the user made, by phrase. A null value means removed.
  final Map<String, ParsedFood?> _overrides = {};

  @override
  void dispose() {
    if (_listening) ref.read(voiceInputProvider).stop();
    _text.dispose();
    super.dispose();
  }

  String get _date => widget.date ?? dateKey(ref.read(todayProvider));

  Future<void> _toggleListening(List<FoodItem> foods) async {
    final voice = ref.read(voiceInputProvider);
    if (_listening) {
      await voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    FocusScope.of(context).unfocus();
    final existing = _text.text.trim();
    _textBeforeListening = existing.isEmpty ? '' : '$existing, ';
    setState(() {
      _voiceError = null;
      _listening = true;
    });
    final problem = await voice.start(
      hints: foods.map((f) => f.name).take(100).toList(),
      onWords: (words, _) {
        if (!mounted) return;
        setState(() {
          _text.text = _textBeforeListening + words;
          _text.selection = TextSelection.collapsed(offset: _text.text.length);
        });
      },
      onStopped: () {
        if (mounted) setState(() => _listening = false);
      },
      onError: (message) {
        if (mounted) setState(() => _voiceError = message);
      },
    );
    if (problem != null && mounted) {
      setState(() {
        _listening = false;
        _voiceError = problem;
      });
    }
  }

  List<ParsedFood> _items(ParseResult result) => [
    for (final item in result.items)
      if (!_overrides.containsKey(item.phrase)) item else if (_overrides[item.phrase] != null) _overrides[item.phrase]!,
  ];

  Future<void> _editAmount(ParsedFood item) async {
    final choice = await showFoodAmountSheet(
      context,
      food: item.food!,
      askCategory: false,
      initial: item.portion,
      confirmLabel: 'Update',
    );
    if (choice == null) return;
    setState(() => _overrides[item.phrase] = _fromPortion(item.phrase, choice.portion));
  }

  Future<void> _chooseFood(ParsedFood item) async {
    final portion = await context.push<FoodPortion>('/diet/pick-food');
    if (portion == null) return;
    setState(() => _overrides[item.phrase] = _fromPortion(item.phrase, portion));
  }

  ParsedFood _fromPortion(String phrase, FoodPortion p) =>
      ParsedFood(phrase: phrase, food: p.food, serving: p.serving, count: p.count);

  Future<void> _addAll(List<ParsedFood> matched, String meal) async {
    setState(() => _saving = true);
    final ok = await runGuarded(context, () async {
      final repo = ref.read(foodLogRepositoryProvider);
      for (final item in matched) {
        await repo.logFood(date: _date, category: meal, portion: item.portion!);
      }
      ref.read(nutritionRevisionProvider.notifier).bump();
    }, success: 'Added ${matched.length} ${matched.length == 1 ? 'food' : 'foods'} to $meal');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final foods = ref.watch(allFoodsProvider).value ?? const <FoodItem>[];
    final categories = ref.watch(mealCategoriesProvider).value ?? const <String>[];
    final result = foods.isEmpty ? ParseResult.empty : MealTextParser(foods).parse(_text.text);
    final items = _items(result);
    final matched = items.where((i) => i.matched).toList();
    final unmatched = items.length - matched.length;
    final meal =
        _meal ??
        (result.mealCategory != null && categories.contains(result.mealCategory)
            ? result.mealCategory!
            : widget.category ?? suggestedMealCategory(DateTime.now(), categories));
    final totals = Nutrients.sum(matched.map((i) => i.portion!.nutrients));

    return Scaffold(
      appBar: AppBar(title: const Text('Speak or type a meal')),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: p.background,
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: FilledButton(
            onPressed: matched.isEmpty || _saving ? null : () => _addAll(matched, meal),
            child: Text(
              matched.isEmpty
                  ? 'Nothing to add yet'
                  : 'Add ${matched.length} ${matched.length == 1 ? 'food' : 'foods'} · ${formatKcal(totals.calories)}',
            ),
          ),
        ),
      ),
      body: ListView(
        padding: pagePadding,
        children: [
          Text(
            'Say or type what you ate, for example "2 roti, 1 bowl dal and a glass of milk". '
            'Hindi words like "do roti aur ek katori dahi" work too.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'e.g. 2 roti, 1 bowl dal, 1 glass milk',
              suffixIcon: _text.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _text.clear();
                        _overrides.clear();
                      }),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _toggleListening(foods),
                  style: _listening
                      ? FilledButton.styleFrom(backgroundColor: p.error, foregroundColor: Colors.white)
                      : null,
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                  label: Text(_listening ? 'Stop listening' : 'Speak'),
                ),
              ),
            ],
          ),
          if (_listening) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.error)),
                const SizedBox(width: 10),
                Text('Listening… speak now', style: t.bodySmall?.copyWith(color: p.text)),
              ],
            ),
          ],
          if (_voiceError != null) ...[
            const SizedBox(height: 8),
            Text(_voiceError!, style: t.bodySmall?.copyWith(color: p.warning)),
          ],
          const SizedBox(height: 16),
          if (categories.isNotEmpty)
            LabeledDropdown<String>(
              label: 'Meal · ${relativeDayLabel(parseDateKey(_date), today)}',
              value: meal,
              items: {...categories, meal}.toList(),
              onChanged: (v) => setState(() => _meal = v),
            ),
          if (items.isNotEmpty) ...[
            SectionTitle(unmatched == 0 ? 'Understood' : 'Understood ($unmatched not found)'),
            for (final item in items) ...[
              item.matched ? _matchedCard(item) : _unmatchedCard(item),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            if (matched.isNotEmpty) NutrientSummary(nutrients: totals, title: 'Total'),
            if (unmatched > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Foods not found are skipped unless you choose one.', style: t.bodySmall),
              ),
          ] else if (_text.text.trim().isNotEmpty && foods.isNotEmpty)
            const EmptyState(
              icon: Icons.hearing,
              title: 'No foods recognised yet',
              message: 'Add an amount and a food name, e.g. "1 bowl rice".',
              compact: true,
            ),
          const SizedBox(height: 16),
          Text(
            'Amounts like "bowl" or "glass" use household sizes, so totals are estimates. '
            "Voice is turned into text by your phone's speech service; typing stays fully on your phone.",
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _matchedCard(ParsedFood item) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final portion = item.portion!;
    return AppCard(
      onTap: () => _editAmount(item),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      child: Row(
        children: [
          FoodThumb(category: item.food!.category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.food!.name, style: t.titleSmall),
                Text(portion.quantityLabel, style: t.bodySmall),
                Text(
                  '${formatKcal(portion.nutrients.calories)} · ${formatGrams(portion.nutrients.protein)} protein',
                  style: t.bodySmall?.copyWith(color: p.text),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text('Heard: "${item.phrase}"', style: t.bodySmall?.copyWith(fontSize: 11.5, color: p.textMuted)),
                    if (!item.confident) Badge2('Check this', color: p.warning),
                    if (item.servingEstimated) Badge2('Estimated size', color: p.warning),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                tooltip: 'Change food',
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => _chooseFood(item),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _overrides[item.phrase] = null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unmatchedCard(ParsedFood item) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          Icon(Icons.help_outline, color: p.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Not found: "${item.phrase}"', style: t.titleSmall),
                Text('Choose the food, or add it as a custom food.', style: t.bodySmall),
              ],
            ),
          ),
          TextButton(onPressed: () => _chooseFood(item), child: const Text('Choose')),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _overrides[item.phrase] = null),
          ),
        ],
      ),
    );
  }
}
