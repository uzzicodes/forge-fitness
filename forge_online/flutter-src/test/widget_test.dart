import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_fitness/main.dart';
import 'package:forge_fitness/models.dart';
import 'package:forge_fitness/meal_editor.dart';
import 'package:forge_fitness/training.dart';
import 'package:forge_fitness/workout_screen.dart';

const profile = Profile(
  name: 'Sam',
  sex: 'Male',
  goal: 'Build muscle',
  equipment: 'Full gym',
  experience: 'Beginner',
  weight: 75,
  height: 175,
  activity: 1.55,
  age: 25,
  days: 3,
);
Future<AppStore> store() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance());
}

void main() {
  test('Personal targets use the declared calorie and protein formulas', () {
    expect(profile.calories, 2870);
    expect(profile.protein, 120);
    final j = profile.toJson();
    j['calorieOverride'] = 2400;
    j['proteinOverride'] = 140;
    final p = Profile.fromJson(j);
    expect(p.calories, 2400);
    expect(p.protein, 140);
    j['age'] = 17;
    expect(() => Profile.fromJson(j), throwsFormatException);
  });
  test(
    'Meals edit without double counting and totals remain isolated by date',
    () async {
      final s = await store();
      final day = DateTime(2026, 10, 27);
      Meal meal(String id, double kcal, double protein, String date) => Meal(
        id: id,
        date: date,
        name: 'Chicken rice',
        type: 'Lunch',
        calories: kcal,
        protein: protein,
        carbs: 30,
        fat: 5,
      );
      await s.upsertMeal(meal('1', 500, 30, dayKey(day)));
      await s.upsertMeal(meal('1', 600, 40, dayKey(day)));
      await s.upsertMeal(meal('2', 300, 20, '2026-10-26'));
      expect(s.total(day, 'calories'), 600);
      expect(s.total(day, 'protein'), 40);
      expect(s.meals.length, 2);
      await s.removeMeal('1');
      expect(s.total(day, 'calories'), 0);
    },
  );
  test(
    'Backup roundtrip persists logs and invalid restore is atomic',
    () async {
      final s = await store();
      await s.setProfile(profile);
      await s.addWater(DateTime(2026, 10, 27), 1);
      await s.addWeight(DateTime(2026, 10, 27), 74.5);
      s.sessions['2026-10-27'] = {
        'name': 'Full body A',
        'done': false,
        'sets': {
          'bench-0': {'reps': 8, 'kg': 20, 'checked': true},
        },
      };
      await s.save();
      final raw = s.backup();
      final restored = AppStore(s.preferences);
      await restored.load();
      expect(restored.profile!.name, 'Sam');
      expect(restored.water['2026-10-27'], 1);
      expect(restored.weights.single['kg'], 74.5);
      final broken = jsonDecode(raw) as Map<String, dynamic>;
      broken['weights'] = [
        {'date': 'x', 'kg': -5},
      ];
      await expectLater(
        restored.restore(jsonEncode(broken)),
        throwsFormatException,
      );
      expect(restored.backup(), raw);
    },
  );
  test('Weekly training uses rest days, equipment and experience', () {
    for (final equipment in ['Full gym', 'Dumbbells', 'Bodyweight']) {
      for (final days in [3, 4]) {
        final plan = List.generate(
          7,
          (i) => workoutFor(i + 1, equipment, days, 'Beginner'),
        );
        expect(plan.where((w) => !w.rest).length, days);
        for (final w in plan.where((w) => !w.rest)) {
          expect(w.sets, 2);
          expect(w.exercises.length, inInclusiveRange(4, 6));
          if (equipment == 'Bodyweight') {
            expect(w.exercises.every((e) => e.equipment == 'Bodyweight'), true);
          }
          if (equipment == 'Dumbbells') {
            expect(w.exercises.every((e) => e.equipment != 'Full gym'), true);
          }
        }
      }
    }
  });
  testWidgets('Onboarding renders at phone width without errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ForgeApp(store: await store()));
    await tester.pumpAndSettle();
    expect(find.text('Stronger starts\nwith you.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final size in [const Size(360, 800), const Size(1440, 1000)]) {
    testWidgets('Dashboard and all sections render at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = await store();
      await s.setProfile(profile);
      await tester.pumpWidget(ForgeApp(store: s));
      await tester.pumpAndSettle();
      expect(find.text('Hey, Sam.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label
          in (size.width > 1000
              ? ['Nutrition', 'Training', 'Progress', 'Settings']
              : ['Food', 'Train', 'Progress', 'Settings'])) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('Manual meal confirmation updates nutrition and can be edited', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = await store();
    final date = DateTime(2026, 10, 27);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showSheet(context, MealEditor(store: s, date: date)),
              child: const Text('Open meal'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open meal'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Chicken and rice');
    await tester.enterText(fields.at(1), '650');
    await tester.enterText(fields.at(2), '45');
    await tester.ensureVisible(find.text('Confirm & add to my day'));
    await tester.tap(find.text('Confirm & add to my day'));
    await tester.pumpAndSettle();
    expect(s.total(date, 'calories'), 650);
    expect(s.total(date, 'protein'), 45);
    expect(find.byType(MealEditor), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MealEditor(store: s, date: date, existing: s.meals.single),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '700');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(s.total(date, 'calories'), 700);
    expect(s.meals.length, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Workout set saves and rest timer starts', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = await store();
    await s.setProfile(profile);
    final date = calendarDay(
      DateTime.now(),
    ).subtract(Duration(days: DateTime.now().weekday - 1));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: WorkoutScreen(store: s, date: date),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Save completed set').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save completed set').first);
    await tester.pump(const Duration(milliseconds: 600));
    final session = s.sessions[dayKey(date)] as Map;
    expect((session['sets'] as Map)['legpress-0']['checked'], true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Future workout cannot log sets', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = await store();
    await s.setProfile(profile);
    final today = calendarDay(DateTime.now());
    final nextMonday = today.add(Duration(days: 8 - today.weekday));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: WorkoutScreen(store: s, date: nextMonday),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find
                .byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Save completed set',
                )
                .first,
          )
          .onPressed,
      isNull,
    );
    expect(s.sessions, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
