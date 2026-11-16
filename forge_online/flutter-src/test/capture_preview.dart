// Explicit visual QA only: flutter test test/capture_preview.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_fitness/main.dart';
import 'package:forge_fitness/models.dart';
import 'package:forge_fitness/training.dart';
import 'package:forge_fitness/workout_screen.dart';

void main() {
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/arial.ttf');
    if (await font.exists()) {
      final loader = FontLoader('Arial')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
    }
    final icons = File(
      'C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
    if (await icons.exists()) {
      final loader = FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
      await loader.load();
    }
    final roboto = File(
      'C:/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
    );
    if (await roboto.exists()) {
      final loader = FontLoader('Roboto')
        ..addFont(
          Future.value(ByteData.sublistView(await roboto.readAsBytes())),
        );
      await loader.load();
    }
  });
  Future<AppStore> demo() async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(await SharedPreferences.getInstance());
    s.profile = const Profile(
      name: 'Alex',
      sex: 'Male',
      goal: 'Build muscle',
      equipment: 'Full gym',
      experience: 'Intermediate',
      weight: 75,
      height: 178,
      activity: 1.55,
      age: 25,
      days: 4,
      calorieOverride: 2600,
      proteinOverride: 140,
    );
    final d = dayKey(DateTime.now());
    s.meals = [
      Meal(
        id: 'demo1',
        date: d,
        name: 'Eggs, toast & avocado',
        type: 'Breakfast',
        calories: 520,
        protein: 28,
        carbs: 44,
        fat: 26,
      ),
      Meal(
        id: 'demo2',
        date: d,
        name: 'Grilled chicken & rice bowl',
        type: 'Lunch',
        calories: 640,
        protein: 48,
        carbs: 72,
        fat: 16,
        estimated: true,
      ),
    ];
    s.water[d] = 5;
    return s;
  }

  testWidgets('desktop overview preview', (tester) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ForgeApp(store: await demo()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ForgeApp),
      matchesGoldenFile('../releases/preview-desktop.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('phone overview preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ForgeApp(store: await demo()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ForgeApp),
      matchesGoldenFile('../releases/preview-phone.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('form illustration preview', (tester) async {
    tester.view.physicalSize = const Size(600, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = await demo();
    await tester.pumpWidget(ForgeApp(store: s));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(HomeScreen));
    showSheet(context, ExerciseGuide(exercise: ex('squat')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Make every rep count.'), findsOneWidget);
    await expectLater(
      find.byType(ForgeApp),
      matchesGoldenFile('../releases/preview-exercise.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
