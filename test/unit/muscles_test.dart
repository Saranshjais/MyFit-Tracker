import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/features/exercises/body_map.dart';
import 'package:myfit_tracker/features/exercises/exercise.dart';
import 'package:myfit_tracker/features/exercises/muscles.dart';

void main() {
  test('muscle ids round-trip and unknown ids are ignored', () {
    final list = [Muscle.chest, Muscle.frontDelts, Muscle.triceps];
    expect(Muscle.parse(Muscle.encode(list)), list);
    expect(Muscle.parse('chest, nope ,lats'), [Muscle.chest, Muscle.lats]);
    expect(Muscle.parse(''), isEmpty);
    expect(Muscle.parse(null), isEmpty);
  });

  test('muscle ids are unique and every body part has muscles', () {
    expect(Muscle.values.map((m) => m.id).toSet().length, Muscle.values.length);
    for (final part in BodyPart.values) {
      expect(Muscle.values.any((m) => m.part == part), isTrue, reason: part.label);
    }
  });

  test('every bundled exercise names valid main and supporting muscles', () {
    final exercises = (jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List).cast<Map>();
    for (final e in exercises) {
      final targets = (e['targets'] as List).cast<String>();
      final assists = (e['assists'] as List).cast<String>();
      expect(targets, isNotEmpty, reason: '${e['name']} needs a main muscle');
      for (final id in [...targets, ...assists]) {
        expect(Muscle.byId(id), isNotNull, reason: '${e['name']}: unknown muscle "$id"');
      }
      expect(targets.toSet().intersection(assists.toSet()), isEmpty, reason: '${e['name']} lists a muscle twice');
    }
  });

  test('common exercises target the expected muscles', () {
    final byName = {
      for (final e in (jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List).cast<Map>())
        e['name'] as String: Muscle.parse((e['targets'] as List).join(',')),
    };
    expect(byName['Bench Press'], contains(Muscle.chest));
    expect(byName['Incline Dumbbell Press'], contains(Muscle.chestUpper));
    expect(byName['Lat Pulldown'], contains(Muscle.lats));
    expect(byName['Lateral Raise'], contains(Muscle.sideDelts));
    expect(byName['Squat'], containsAll([Muscle.quads, Muscle.glutes]));
    expect(byName['Romanian Deadlift'], contains(Muscle.hamstrings));
    expect(byName['Standing Calf Raise'], [Muscle.calves]);
  });

  test('secondary groups come from supporting muscles outside the main group', () {
    expect(Exercise.secondaryGroupsFor('Chest', [Muscle.chestUpper, Muscle.frontDelts, Muscle.triceps]), [
      'Shoulders',
      'Arms',
    ]);
  });

  test('the body diagram picks the side that shows the main muscles', () {
    expect(preferredView([Muscle.chest]), BodyView.front);
    expect(preferredView([Muscle.lats, Muscle.upperBack]), BodyView.back);
    expect(preferredView([Muscle.quads, Muscle.glutes]), BodyView.front, reason: 'a tie shows the front');
    expect(preferredView([Muscle.hamstrings, Muscle.glutes]), BodyView.back);
  });
}
