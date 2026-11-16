import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_fitness/training.dart';
import 'package:forge_fitness/models.dart';
import 'package:forge_fitness/workout_screen.dart';

const profile = Profile(
  name: 'Test',
  sex: 'Male',
  goal: 'Lean & defined',
  equipment: 'Full gym',
  experience: 'Beginner',
  weight: 75,
  height: 178,
  activity: 1.375,
  age: 25,
  days: 5,
);
Map<String, dynamic> partial() => {
  'name': 'Push',
  'done': false,
  'exerciseIds': ['bench', 'row'],
  'plannedSets': 2,
  'rotationIndex': 0,
  'rotationSize': 5,
  'sets': <String, dynamic>{
    'bench-0': {'reps': 8, 'kg': 50.0, 'checked': true},
  },
};
void main() {
  test(
    'full gym balances tools and includes vertical pulling and knee flexion',
    () {
      for (final days in [2, 3, 4, 5]) {
        final plan = rotationFor(
          'Full gym',
          days,
          'Beginner',
          goal: 'Lean & defined',
        );
        final ids = plan.expand((w) => w.exercises).map((e) => e.id).toList();
        expect(plan.length, days);
        expect(ids.contains('lat'), true);
        expect(
          ids.any((id) => ['seatedlegcurl', 'lyinglegcurl'].contains(id)),
          true,
        );
        for (final w in plan) {
          expect(
            w.exercises.map((e) => e.id).toSet().length,
            w.exercises.length,
          );
          expect(w.sets, 2);
        }
      }
      final five = rotationFor(
        'Full gym',
        5,
        'Beginner',
        goal: 'Lean & defined',
      );
      expect(
        five.first.exercises
            .where(
              (e) => e.name.contains('Dumbbell') || e.name.contains('dumbbell'),
            )
            .length,
        1,
      );
      expect(five[2].exercises.first.id, 'legpress');
      expect(
        rotationFor('Full gym', 5, 'Intermediate')[2].exercises.first.id,
        'bbsquat',
      );
    },
  );
  test(
    'alternatives honor movement purpose, equipment and duplicate exclusions',
    () {
      expect(
        exerciseAlternatives('lat', 'Full gym', []).map((e) => e.id),
        contains('assistedpullup'),
      );
      expect(
        exerciseAlternatives('lat', 'Full gym', []).any((e) => e.id == 'row'),
        false,
      );
      expect(
        exerciseAlternatives('bench', 'Full gym', [
          'machinechest',
        ]).any((e) => e.id == 'machinechest'),
        false,
      );
      expect(
        exerciseAlternatives(
          'dbpress',
          'Dumbbells',
          [],
        ).every((e) => e.equipment != 'Full gym'),
        true,
      );
      expect(
        exerciseAlternatives(
          'airsquat',
          'Bodyweight',
          [],
        ).every((e) => e.equipment == 'Bodyweight'),
        true,
      );
    },
  );
  test(
    'partial swap preserves completed loads, moves remaining sets and starts fresh',
    () {
      final original = partial(),
          next = swapSessionExercise(
            original,
            'bench',
            'machinechest',
            'Full gym',
          );
      expect(next['exerciseIds'], ['machinechest', 'row']);
      expect(next['retiredExerciseIds'], ['bench']);
      expect(sessionTarget(next, 'machinechest'), 1);
      expect(sessionTotalSets(next), 4);
      expect(retiredSetCount(next), 1);
      expect((next['sets'] as Map)['bench-0']['kg'], 50);
      expect((next['sets'] as Map)['machinechest-0'], isNull);
      expect(original['exerciseIds'], ['bench', 'row']);
      expect(next['rotationIndex'], 0);
      expect(next['done'], false);
      expect(
        () => swapSessionExercise(next, 'row', 'machinechest', 'Full gym'),
        throwsFormatException,
      );
      expect(
        () => swapSessionExercise(
          {...original, 'done': true},
          'bench',
          'machinechest',
          'Full gym',
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'swap survives backup restore and does not award completion XP',
    () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore(await SharedPreferences.getInstance());
      await s.setProfile(profile);
      s.sessions[dayKey(DateTime.now())] = swapSessionExercise(
        partial(),
        'bench',
        'machinechest',
        'Full gym',
      );
      await s.save();
      final restored = AppStore(await SharedPreferences.getInstance());
      await restored.restore(s.backup());
      final record = restored.sessions[dayKey(DateTime.now())] as Map;
      expect(sessionTarget(record, 'machinechest'), 1);
      expect(retiredSetCount(record), 1);
      expect(restored.totalXp, 0);
      s.dispose();
      restored.dispose();
    },
  );
  testWidgets('phone swap keeps completed sets and logs only remaining sets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(await SharedPreferences.getInstance());
    await s.setProfile(profile);
    final date = calendarDay(DateTime.now());
    s.sessions[dayKey(date)] = partial();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: WorkoutScreen(store: s, date: date),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Swap / move Barbell bench press'));
    await tester.tap(find.text('Swap / move Barbell bench press'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Machine chest press'));
    await tester.pumpAndSettle();
    final record = s.sessions[dayKey(date)] as Map;
    expect(sessionTarget(record, 'machinechest'), 1);
    expect((record['sets'] as Map)['bench-0']['checked'], true);
    expect(find.byKey(const ValueKey('machinechest-1')), findsNothing);
    expect(find.byKey(const ValueKey('machinechest-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    s.dispose();
  });
}
