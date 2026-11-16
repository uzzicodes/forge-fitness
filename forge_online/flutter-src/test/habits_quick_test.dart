import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_fitness/models.dart';
import 'package:forge_fitness/quick_meal.dart';
import 'package:forge_fitness/training.dart';
import 'package:forge_fitness/habits_screen.dart';

Future<AppStore> store() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance());
}

void main() {
  test(
    'habit checks award once per day and streak tolerates an unfinished today',
    () async {
      final s = await store(), today = DateTime(2026, 10, 27);
      await s.setHabit('walk', 'Take a short walk');
      await s.checkHabit(today, 'walk', true);
      await s.checkHabit(today, 'walk', true);
      expect(s.totalXp, 10);
      expect(s.streak(today, habitId: 'walk'), 1);
      await s.checkHabit(DateTime(2026, 10, 26), 'walk', true);
      expect(s.streak(today, habitId: 'walk'), 2);
      await s.checkHabit(today, 'walk', false);
      expect(s.totalXp, 10);
      expect(s.streak(today, habitId: 'walk'), 1);
      await s.checkHabit(DateTime(2026, 10, 24), 'walk', true);
      expect(s.streak(today, habitId: 'walk'), 1);
      s.dispose();
    },
  );
  test(
    'water accepts metric fractions and extra drinking does not farm XP',
    () async {
      final s = await store(), day = DateTime(2026, 10, 27);
      await s.addWater(day, .6);
      expect(s.waterMl(day), 150);
      expect(s.totalXp, 10);
      await s.addWater(day, 12);
      expect(s.waterMl(day), 3150);
      expect(s.totalXp, 10);
      await s.setWaterTarget(2500);
      expect(s.totalXp, 10);
      final restored = await store();
      await restored.restore(s.backup());
      expect(restored.waterMl(day), 3150);
      expect(restored.waterTargetMl, 2500);
      s.dispose();
      restored.dispose();
    },
  );
  test(
    'meal confirmation saves food and water together, not unresolved guesses',
    () async {
      final s = await store(), day = DateTime(2026, 10, 27);
      await s.confirmMealEstimate(day, {
        'needsClarification': false,
        'items': [
          {'name': 'Eggs'},
        ],
        'name': '3 boiled eggs',
        'calories': 232.5,
        'protein': 18.9,
        'carbs': 1.7,
        'fat': 15.9,
        'waterMl': 500,
        'portion': '3 large eggs',
        'assumptions': '50 g each',
      });
      expect(s.meals.single.protein, 18.9);
      expect(s.waterMl(day), 500);
      expect(s.totalXp, 20);
      await expectLater(
        s.confirmMealEstimate(day, {'needsClarification': true}),
        throwsArgumentError,
      );
      expect(s.meals.length, 1);
      s.dispose();
    },
  );
  test(
    'lean aesthetic goal starts at maintenance and uses appropriate balanced equipment',
    () {
      const p = Profile(
        name: 'Test',
        sex: 'Male',
        goal: 'Build muscle',
        equipment: 'Full gym',
        experience: 'Beginner',
        weight: 75,
        height: 178,
        activity: 1.375,
        age: 25,
        days: 5,
      );
      final lean = p.withGoal('Lean & defined');
      expect(p.calories - lean.calories, 200);
      final plan = rotationFor('Full gym', 5, 'Beginner', goal: lean.goal);
      expect(plan.first.exercises.first.id, 'inclinedbpress');
      expect(plan[3].exercises.any((e) => e.id == 'lateral'), true);
      expect(plan[2].exercises.any((e) => e.muscle.contains('Quads')), true);
      expect(Profile.fromJson(lean.toJson()).goal, 'Lean & defined');
    },
  );
  testWidgets('one meal message estimates and requires a final confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = await store();
    final client = MockClient((r) async {
      if (r.url.path == '/api/status') {
        return http.Response('{"configured":false}', 200);
      }
      expect(jsonDecode(r.body)['description'], 'I ate 3 boiled eggs');
      return http.Response(
        jsonEncode({
          'is_food': true,
          'needsClarification': false,
          'name': 'Boiled eggs',
          'items': [
            {
              'name': 'Boiled eggs',
              'portion': '3 pieces · 150 g',
              'calories': 232.5,
            },
          ],
          'calories': 232.5,
          'protein': 18.9,
          'carbs': 1.7,
          'fat': 15.9,
          'assumptions': 'Large eggs, 50 g each',
          'source': 'Food reference estimate',
        }),
        200,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: QuickMealEntry(
            store: s,
            date: DateTime(2026, 10, 27),
            client: client,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'I ate 3 boiled eggs');
    await tester.tap(find.text('Estimate my meal'));
    await tester.pumpAndSettle();
    expect(s.meals, isEmpty);
    expect(find.text('18.9 g protein'), findsOneWidget);
    await tester.ensureVisible(find.text('Yes, confirm & log'));
    await tester.tap(find.text('Yes, confirm & log'));
    await tester.pumpAndSettle();
    expect(s.meals.single.calories, 232.5);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    s.dispose();
    client.close();
  });
  testWidgets('optional habits fit a small phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = await store();
    await s.setHabit('walk', 'Take a short walk');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HabitsView(store: s, date: DateTime(2026, 10, 27)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    s.dispose();
  });
}
