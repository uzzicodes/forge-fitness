import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_fitness/weekly_review.dart';
import 'package:forge_fitness/models.dart';
import 'package:forge_fitness/check_in.dart';

const target = WeekTargets(
  trainingDays: 5,
  calories: 2000,
  protein: 120,
  waterMl: 2000,
);
const athlete = Profile(
  name: 'Review Test',
  sex: 'Male',
  goal: 'Build muscle',
  equipment: 'Full gym',
  experience: 'Beginner',
  weight: 75,
  height: 175,
  activity: 1.55,
  age: 25,
  days: 5,
  preferredDays: [1, 2, 3, 4, 5],
);
final monday = DateTime.utc(2026, 10, 19);
Map<String, DayFuel> completeWeek({
  List<int> workouts = const [0, 1, 2, 3, 4],
}) => {
  for (var i = 0; i < 7; i++)
    weekKey(monday.add(Duration(days: i))): DayFuel()
      ..calories = 2000
      ..protein = 120
      ..waterMl = 2000
      ..meals = 3
      ..trained = workouts.contains(i),
};
WeeklyLedger ledger(
  DateTime today, {
  Map<String, DayFuel>? days,
  Map<String, int>? earnings,
  Map<String, WeekTargets>? plans,
}) => calculateWeeklyXp(
  today: today,
  start: monday,
  targets: plans ?? {weekKey(monday): target},
  days: days ?? completeWeek(),
  earnedByDay: earnings ?? {'2026-10-18': 500},
);
void main() {
  test(
    'Sunday is open; a Saturday make-up meets five sessions after Monday was missed',
    () {
      final days = completeWeek(workouts: [1, 2, 3, 4, 5]);
      expect(ledger(DateTime.utc(2026, 10, 25), days: days).deductedXp, 0);
      expect(
        ledger(DateTime.utc(2026, 10, 25), days: days).closedWeeks,
        isEmpty,
      );
      final closed = ledger(DateTime.utc(2026, 10, 26), days: days);
      expect(closed.closedWeeks.single.workouts, 5);
      expect(closed.deductedXp, 0);
      days['2026-10-24']!.trained = false;
      expect(ledger(DateTime.utc(2026, 10, 26), days: days).deductedXp, 25);
    },
  );
  test(
    'personal training goals, exact fuel boundaries, and no meal-count minimum',
    () {
      for (final count in [2, 3, 4, 5]) {
        final plan = WeekTargets(
          trainingDays: count,
          calories: 2000,
          protein: 120,
          waterMl: 2250,
        );
        final days = completeWeek(workouts: List.generate(count, (i) => i));
        for (final d in days.values) {
          d.calories = 1800;
          d.waterMl = 2250;
          d.meals = 1;
        }
        expect(
          ledger(
            DateTime.utc(2026, 10, 26),
            days: days,
            plans: {weekKey(monday): plan},
          ).deductedXp,
          0,
        );
        for (final d in days.values) {
          d.calories = 2200;
        }
        expect(
          ledger(
            DateTime.utc(2026, 10, 26),
            days: days,
            plans: {weekKey(monday): plan},
          ).deductedXp,
          0,
        );
        days.values.first
          ..calories = 2201
          ..protein = 119.9
          ..waterMl = 2249;
        expect(
          ledger(
            DateTime.utc(2026, 10, 26),
            days: days,
            plans: {weekKey(monday): plan},
          ).deductedXp,
          13,
        );
      }
    },
  );
  test('unlogged days count, current unfinished day does not, cap is 120', () {
    final open = WeekReview(
      monday: monday,
      today: DateTime.utc(2026, 10, 21),
      targets: target,
      days: {},
    );
    expect(open.proteinGaps, 2);
    expect(open.waterGaps, 2);
    expect(open.missedWorkouts, 0);
    final closed = ledger(DateTime.utc(2026, 10, 26), days: {});
    expect(closed.closedWeeks.single.rawPenalty, 216);
    expect(closed.deductedXp, 120);
  });
  test(
    'zero floor applies chronologically; no future XP debt or future rewards',
    () {
      final earned = {'2026-10-20': 30, '2026-10-27': 60, '2026-11-10': 1000};
      final first = ledger(
        DateTime.utc(2026, 10, 27),
        days: {},
        earnings: earned,
      );
      expect(first.earnedXp, 90);
      expect(first.deductedXp, 30);
      expect(first.netXp, 60);
      final second = ledger(
        DateTime.utc(2026, 11, 2),
        days: {},
        earnings: earned,
      );
      expect(second.deductedXp, 90);
      expect(second.netXp, 0);
      final corrected = ledger(
        DateTime.utc(2026, 10, 27),
        days: completeWeek(),
        earnings: earned,
      );
      expect(corrected.netXp, 90);
      expect(corrected.deductedXp, 0);
      expect(
        ledger(DateTime.utc(2026, 10, 27), days: {}, earnings: earned).netXp,
        first.netXp,
      );
    },
  );
  test(
    'recovery exempts only that week, and next week numeric targets carry forward',
    () {
      final plans = {weekKey(monday): target.withRecovery(true)};
      final result = ledger(DateTime.utc(2026, 11, 2), days: {}, plans: plans);
      expect(result.closedWeeks.length, 2);
      expect(result.closedWeeks.first.appliedPenalty, 0);
      expect(result.closedWeeks.last.targets.recovery, false);
      expect(result.closedWeeks.last.appliedPenalty, 120);
    },
  );
  test(
    'old history keeps XP and a missing future plan never back-charges practice',
    () {
      final r = calculateWeeklyXp(
        today: DateTime.utc(2026, 10, 29),
        start: DateTime.utc(2026, 11, 2),
        targets: {'2026-11-02': target},
        days: {},
        earnedByDay: {'2026-10-01': 80},
      );
      expect(r.netXp, 80);
      expect(r.closedWeeks, isEmpty);
    },
  );
  test(
    'activation, frozen weekly targets, recovery, account clock and backup survive reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance(), s = AppStore(prefs);
      await s.load();
      s.profile = athlete;
      await s.save();
      final next = weekMonday(s.xpToday()).add(const Duration(days: 7));
      expect(weekKey(s.weeklyXpStart!), weekKey(next));
      expect(s.deductedXp, 0);
      final current = weekMonday(s.xpToday());
      s.accountPreferences['weeklyXpStart'] = weekKey(current);
      s.accountPreferences['weeklyXpOffsetMinutes'] = 300;
      s.weekPlans[weekKey(current)] = target.toJson();
      await s.setWaterTarget(2500);
      expect(s.targetsForWeek(current).waterMl, 2000);
      expect(s.targetsForWeek(next).waterMl, 2500);
      await s.setRecoveryWeek(true);
      expect(s.targetsForWeek(current).recovery, true);
      expect(s.targetsForWeek(next).recovery, false);
      expect(
        weekKey(s.xpToday(DateTime.utc(2026, 10, 25, 18, 59))),
        '2026-10-25',
      );
      expect(weekKey(s.xpToday(DateTime.utc(2026, 10, 25, 19))), '2026-10-26');
      final copy = AppStore(prefs);
      await copy.restore(s.backup());
      expect(copy.weekPlans, s.weekPlans);
      expect(copy.accountPreferences, s.accountPreferences);
      expect(copy.totalXp, s.totalXp);
      final bad = jsonDecode(s.backup()) as Map<String, dynamic>;
      bad['weekPlans'] = {'2026-10-20': target.toJson()};
      await expectLater(s.restore(jsonEncode(bad)), throwsFormatException);
      expect(s.targetsForWeek(current).waterMl, 2000);
      await s.clearAccountCache();
      expect(s.weekPlans, isEmpty);
      expect(s.weeklyXpStart, isNull);
      s.dispose();
      copy.dispose();
    },
  );
  testWidgets(
    'small phone check-in shows next steps and weekly rules without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final s = AppStore(await SharedPreferences.getInstance());
      s.profile = athlete;
      await s.save();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: CheckInScreen(store: s, date: s.xpToday()),
        ),
      );
      expect(find.text('0 meals logged'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Weekly scorecard'), 400);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Recovery week'), 400);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(s.targetsForWeek(s.weeklyXpStart!).recovery, true);
      await tester.scrollUntilVisible(find.text('Weekly XP rules'), 300);
      await tester.tap(find.text('Weekly XP rules'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      s.dispose();
    },
  );
}
