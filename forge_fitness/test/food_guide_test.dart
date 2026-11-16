import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_fitness/food_guide.dart';
import 'package:forge_fitness/models.dart';

FoodGuideData guide() => FoodGuideData(
  jsonDecode(File('assets/food-guide.json').readAsStringSync())
      as Map<String, dynamic>,
);
void main() {
  test(
    'cooked servings, ingredient costs and calorie-only foods remain distinct',
    () {
      final g = guide(),
          eggs = g.items.firstWhere((f) => f.id == 'eggs'),
          chicken = g.items.firstWhere((f) => f.id == 'chicken'),
          oil = g.items.firstWhere((f) => f.id == 'oil');
      expect(eggs.number('calories'), 155);
      expect(eggs.number('protein'), 12.6);
      expect(eggs.low, 40);
      expect(eggs.high, 46.7);
      expect(chicken.number('protein'), 46.5);
      expect(chicken.low, 234.6);
      expect(chicken.data['notes'], contains('200 g raw'));
      expect(oil.number('protein'), 0);
      expect(oil.proteinCost, contains('No protein'));
      expect(oil.data['proteinPick'], false);
      expect(eggs.estimate(2)['calories'], 310);
      expect(eggs.estimate(.5)['protein'], 6.3);
    },
  );
  test(
    'budget uses upper cost and dietary/category filters stay independent',
    () {
      final g = guide();
      final low = g.select(budget: 50);
      expect(low.any((f) => f.id == 'eggs'), true);
      expect(low.any((f) => f.id == 'milk'), false);
      expect(
        g
            .select(group: 'Plant sources')
            .every((f) => f.data['group'] == 'Plant sources'),
        true,
      );
      expect(g.select(category: 'Meal ideas').length, 6);
      expect(g.select(query: 'not a real food'), isEmpty);
      expect(
        g.select(category: 'Calorie boosters').any((f) => f.id == 'oil'),
        true,
      );
      expect(
        g.select(category: 'Protein picks').any((f) => f.id == 'oil'),
        false,
      );
      final meal = g.items.firstWhere((f) => f.id == 'egg-roti');
      expect(meal.number('calories'), 359);
      expect(meal.number('protein'), 20.5);
    },
  );
  testWidgets('food guide fits a small phone and logging needs confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(await SharedPreferences.getInstance());
    await s.setProfile(
      const Profile(
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
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: FoodGuideScreen(
          store: s,
          date: DateTime(2026, 10, 28),
          guide: guide(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField).first, 'Boiled eggs');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review & log'));
    await tester.tap(find.text('Review & log'));
    await tester.pumpAndSettle();
    expect(s.meals, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(s.meals, isEmpty);
    await tester.ensureVisible(find.text('Review & log'));
    await tester.tap(find.text('Review & log'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, log this serving'));
    await tester.pumpAndSettle();
    expect(s.meals.length, 1);
    expect(s.meals.single.calories, 155);
    expect(s.meals.single.protein, 12.6);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    s.dispose();
  });
}
