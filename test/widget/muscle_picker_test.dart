import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/core/theme/app_palette.dart';
import 'package:myfit_tracker/core/theme/app_theme.dart';
import 'package:myfit_tracker/features/exercises/muscle_picker.dart';
import 'package:myfit_tracker/features/exercises/muscles.dart';

void main() {
  testWidgets('tapping a muscle cycles main → also works → not worked', (tester) async {
    var targets = <Muscle>{};
    var assists = <Muscle>{};
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(AppPalette.dark, Brightness.dark),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: MusclePicker(
                targets: targets,
                assists: assists,
                onChanged: (t, a) => setState(() {
                  targets = t;
                  assists = a;
                }),
              ),
            ),
          ),
        ),
      ),
    );

    Future<void> tapMuscle(String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tapMuscle('Lats');
    expect(targets, {Muscle.lats});
    expect(assists, isEmpty);

    await tapMuscle('Lats');
    expect(targets, isEmpty);
    expect(assists, {Muscle.lats});

    await tapMuscle('Lats');
    expect(targets, isEmpty);
    expect(assists, isEmpty);

    await tapMuscle('Biceps');
    await tapMuscle('Upper back');
    expect(targets, {Muscle.biceps, Muscle.upperBack});
  });
}
