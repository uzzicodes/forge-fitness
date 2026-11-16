import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_fitness/models.dart';
import 'package:forge_fitness/profile_screen.dart';
import 'package:forge_fitness/training.dart';

Profile person({
  double weight = 58,
  double height = 160.02,
  String sex = 'Male',
  String goal = 'Lean & defined',
  bool lower = false,
}) => Profile(
  name: 'Test',
  sex: sex,
  goal: goal,
  equipment: 'Full gym',
  experience: 'Beginner',
  weight: weight,
  height: height,
  activity: 1.375,
  age: 28,
  days: 5,
  lowerBmiThresholds: lower,
);
void main() {
  test(
    'height determines the example category and lower BMI bands are optional',
    () {
      expect(person().bmi, closeTo(22.6506, .001));
      expect(person().bmiCategory, 'Healthy BMI range');
      expect(person(height: 190.5).bmiCategory, 'Underweight');
      expect(person(weight: 74, height: 200).bmiCategory, 'Healthy BMI range');
      expect(person(weight: 73.9, height: 200).bmiCategory, 'Underweight');
      expect(
        person(weight: 100, height: 200).bmiCategory,
        'Overweight BMI range',
      );
      expect(person(weight: 120, height: 200).bmiCategory, 'Obesity BMI range');
      expect(person(weight: 92, height: 200).bmiCategory, 'Healthy BMI range');
      expect(
        person(weight: 92, height: 200, lower: true).bmiCategory,
        'Overweight BMI range',
      );
      expect(
        person(weight: 110, height: 200, lower: true).bmiCategory,
        'Obesity BMI range',
      );
    },
  );
  test(
    'chosen fat-loss goals adjust calories; sex changes energy estimation and backups preserve BMI settings',
    () {
      final normal = person(weight: 90, height: 175),
          loss = person(weight: 90, height: 175, goal: 'Reduce body fat'),
          waist = person(
            weight: 90,
            height: 175,
            goal: 'Reduce waist / belly fat',
          );
      expect(normal.calories - loss.calories, 250);
      expect(loss.calories, waist.calories);
      expect(person(sex: 'Female').calories, lessThan(person().calories));
      final lower = person(lower: true);
      expect(Profile.fromJson(lower.toJson()).lowerBmiThresholds, true);
      expect(lower.withGoal('Build muscle').lowerBmiThresholds, true);
      expect(
        person(height: 190.5, goal: 'Reduce body fat').calories,
        person(height: 190.5).maintenanceCalories,
      );
    },
  );
  test(
    'waist-focus routines keep strength and include core plus optional low-impact cardio',
    () {
      for (final equipment in ['Full gym', 'Dumbbells', 'Bodyweight']) {
        final plans = rotationFor(
          equipment,
          5,
          'Beginner',
          goal: 'Reduce waist / belly fat',
        );
        expect(plans.length, 5);
        expect(
          plans
              .where((w) => w.exercises.any((e) => e.muscle.contains('Core')))
              .length,
          greaterThanOrEqualTo(2),
        );
        expect(plans.every((w) => w.focus.contains('walking/cycling')), true);
      }
    },
  );
  testWidgets(
    'signup converts feet/inches and saves the chosen waist goal in centimetres',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final s = AppStore(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ProfileScreen(store: s),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> enter(String label, String value) async {
        final f = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(f);
        await tester.enterText(f, value);
        await tester.pumpAndSettle();
      }

      await enter('What should we call you?', 'Height Tester');
      await enter('Weight · kg', '58');
      await tester.ensureVisible(find.text('cm'));
      await tester.tap(find.text('cm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Feet & inches').last);
      await tester.pumpAndSettle();
      await enter('Height · feet', '5');
      await enter('Height · inches', '3');
      await enter('Age · 18+', '28');
      await tester.ensureVisible(find.text('Lean & defined'));
      await tester.tap(find.text('Lean & defined'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reduce waist / belly fat').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('BMI 22.65'), findsOneWidget);
      await tester.ensureVisible(find.text('Build my plan'));
      await tester.tap(find.text('Build my plan'));
      await tester.pumpAndSettle();
      expect(s.profile?.height, closeTo(160.02, .001));
      expect(s.profile?.goal, 'Reduce waist / belly fat');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      s.dispose();
    },
  );
}
