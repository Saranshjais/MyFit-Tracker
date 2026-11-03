import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/core/utils/dates.dart';
import 'package:myfit_tracker/features/nutrition/food_log_repository.dart';
import 'package:myfit_tracker/features/nutrition/quick_log/voice_input.dart';

import '../helpers/app_harness.dart';

/// Pretends to be the phone's speech service.
class FakeVoiceInput implements VoiceInput {
  FakeVoiceInput(this.heard);
  final String heard;

  @override
  Future<String?> start({
    required void Function(String words, bool isFinal) onWords,
    required void Function() onStopped,
    required void Function(String message) onError,
    List<String> hints = const [],
  }) async {
    onWords(heard, true);
    onStopped();
    return null;
  }

  @override
  Future<void> stop() async {}
}

/// A phone without speech recognition or with the microphone blocked.
class UnavailableVoiceInput implements VoiceInput {
  @override
  Future<String?> start({
    required void Function(String words, bool isFinal) onWords,
    required void Function() onStopped,
    required void Function(String message) onError,
    List<String> hints = const [],
  }) async => DeviceVoiceInput.unavailableMessage;

  @override
  Future<void> stop() async {}
}

Future<void> openQuickLog(WidgetTester tester) async {
  await tester.tap(find.text('Diet'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Speak or type a meal'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('typing a meal logs every food it understood', (tester) async {
    final db = await pumpApp(tester);
    await openQuickLog(tester);

    await tester.enterText(find.byType(TextField).first, 'lunch: 2 roti, 1 bowl dal and a glass of milk');
    await tester.pumpAndSettle();
    expect(find.text('Roti (whole wheat, no ghee)'), findsOneWidget);
    expect(find.text('Toor dal (cooked, tempered)'), findsOneWidget);
    // 204 + 165 + 145 kcal: the third card may be below the fold.
    expect(find.text('Add 3 foods · 514 kcal'), findsOneWidget);

    await tester.tap(find.text('Add 3 foods · 514 kcal'));
    await tester.pumpAndSettle();
    expect(find.text('Diet / Nutrition'), findsOneWidget);

    await tester.runAsync(() async {
      final logs = await FoodLogRepository(db).forDate(dateKey(today));
      expect(logs.map((l) => l.displayName), [
        'Roti (whole wheat, no ghee)',
        'Toor dal (cooked, tempered)',
        'Milk, toned (3% fat)',
      ]);
      expect(logs.every((l) => l.mealCategory == 'Lunch'), isTrue, reason: '"lunch" in the sentence picks the meal');
    });
  });

  testWidgets('foods that are not found can be removed before adding', (tester) async {
    await pumpApp(tester);
    await openQuickLog(tester);

    await tester.enterText(find.byType(TextField).first, '1 banana and a pizza');
    await tester.pumpAndSettle();
    expect(find.text('Not found: "a pizza"'), findsOneWidget);
    expect(find.text('Add 1 food · 105 kcal'), findsOneWidget);

    final remove = find.byTooltip('Remove').last; // the not-found card is last
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.textContaining('Not found'), findsNothing);
  });

  testWidgets('speaking fills the text and the food list', (tester) async {
    await pumpApp(
      tester,
      overrides: [voiceInputProvider.overrideWithValue(FakeVoiceInput('do roti aur ek katori dahi'))],
    );
    await openQuickLog(tester);

    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();
    expect(find.text('do roti aur ek katori dahi'), findsOneWidget);
    expect(find.text('Roti (whole wheat, no ghee)'), findsOneWidget);
    expect(find.text('Curd (whole milk)'), findsOneWidget);
  });

  testWidgets('without a microphone the screen explains and typing still works', (tester) async {
    await pumpApp(tester, overrides: [voiceInputProvider.overrideWithValue(UnavailableVoiceInput())]);
    await openQuickLog(tester);

    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();
    expect(find.text(DeviceVoiceInput.unavailableMessage), findsOneWidget);
    expect(find.text('Speak'), findsOneWidget, reason: 'not stuck in listening mode');
  });
}
