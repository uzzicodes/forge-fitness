import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_fitness/models.dart';
import 'package:forge_fitness/ranks.dart';
import 'package:forge_fitness/rank_card.dart';

void main() {
  test(
    'every rank boundary promotes exactly once and progress stays bounded',
    () {
      expect(fitnessRanks.length, 25);
      expect(RankProgress(0).current.name, 'Iron I');
      for (var i = 1; i < fitnessRanks.length; i++) {
        final threshold = fitnessRanks[i].minimumXp;
        expect(RankProgress(threshold - 1).index, i - 1);
        expect(RankProgress(threshold).index, i);
        expect(RankProgress(threshold).fraction, i == 24 ? 1 : 0);
      }
      expect(RankProgress(-10).fraction, 0);
      expect(RankProgress(999999).current.name, 'Radiant');
      expect(RankProgress(999999).next, isNull);
      expect(RankProgress(999999).remaining, 0);
    },
  );

  test(
    'existing workouts count and reopening never duplicates XP across backup',
    () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore(await SharedPreferences.getInstance());
      final session = <String, dynamic>{
        'done': true,
        'name': 'Test',
        'sets': <String, dynamic>{},
      };
      s.sessions['2026-10-27'] = session;
      expect(s.totalXp, 60);
      session['done'] = false;
      expect(s.totalXp, 0);
      session['done'] = true;
      expect(s.totalXp, 60);
      s.sessions['2026-10-26'] = {
        'done': true,
        'name': 'Test',
        'sets': <String, dynamic>{},
      };
      expect(RankProgress(s.totalXp).current.name, 'Iron II');
      final restored = AppStore(await SharedPreferences.getInstance());
      await restored.restore(s.backup());
      expect(restored.totalXp, 120);
      expect(RankProgress(restored.totalXp).current.name, 'Iron II');
      s.dispose();
      restored.dispose();
    },
  );

  testWidgets('rank card, scrollable ladder and promotion fit a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(child: RankCard(store: s)),
        ),
      ),
    );
    expect(find.text('Iron I'), findsOneWidget);
    await tester.tap(find.text('View all ranks'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Radiant'),
      450,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Radiant'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Back to FORGE'));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(RankCard));
    showWorkoutReward(ctx, before: 60, after: 120);
    await tester.pumpAndSettle();
    expect(find.text('RANK UP!'), findsOneWidget);
    expect(find.text('+60 XP'), findsOneWidget);
    expect(find.text('Iron II'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    showWorkoutReward(ctx, before: 120, after: 180);
    await tester.pumpAndSettle();
    expect(find.text('Workout complete!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    s.dispose();
  });
}
