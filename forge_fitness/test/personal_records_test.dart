import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_fitness/models.dart';
import 'package:forge_fitness/training.dart';
import 'package:forge_fitness/exercise_records.dart';
import 'package:forge_fitness/personal_records.dart';
import 'package:forge_fitness/workout_screen.dart';

Map<String, dynamic> logged(int reps, double kg, {bool checked = true}) => {
  'reps': reps,
  'kg': kg,
  'checked': checked,
};
final now = DateTime(2026, 11, 1);
const athlete = Profile(
  name: 'PR Test',
  sex: 'Male',
  goal: 'Lean & defined',
  equipment: 'Full gym',
  experience: 'Beginner',
  weight: 75,
  height: 175,
  activity: 1.375,
  age: 25,
  days: 5,
  preferredDays: [1, 2, 3, 4, 5],
);
void main() {
  test(
    'heaviest completed load wins; equal loads compare reps and unchecked/future sets do not count',
    () {
      final sessions = <String, dynamic>{
        '2026-10-19': {
          'sets': {
            'bench-0': logged(8, 60),
            'bench-1': logged(12, 55),
            'dbpress-0': logged(20, 100),
          },
        },
        '2026-10-26': {
          'sets': {
            'bench-0': logged(10, 60),
            'bench-1': logged(8, 90, checked: false),
            'bench-2': logged(0, 100),
          },
        },
        '2026-11-02': {
          'sets': {'bench-0': logged(8, 110)},
        },
      };
      final r = exerciseRecords(sessions, ex('bench'), now, now: now);
      expect(r.best!.kg, 60);
      expect(r.best!.reps, 10);
      expect(r.best!.date, '2026-10-26');
      expect(r.previousSets.length, 1);
      expect(r.newPr, false);
      final past = exerciseRecords(
        sessions,
        ex('bench'),
        DateTime(2026, 10, 19),
        now: now,
      );
      expect(past.best!.reps, 8);
      expect(past.previousSets, isEmpty);
      expect(past.newPr, true);
      final future = exerciseRecords(
        sessions,
        ex('bench'),
        DateTime(2026, 11, 3),
        now: now,
      );
      expect(future.best!.kg, 60);
    },
  );
  test(
    'previous means latest earlier session for that exercise, including retained completed sets after a swap',
    () {
      final sessions = <String, dynamic>{
        '2026-10-25': {
          'done': false,
          'exerciseIds': ['machinechest'],
          'retiredExerciseIds': ['bench'],
          'sets': {
            'bench-0': logged(8, 50),
            'bench-1': logged(10, 45),
            'machinechest-0': logged(12, 100),
          },
        },
        '2026-10-28': {
          'sets': {'row-0': logged(10, 40)},
        },
        '2026-11-01': {
          'sets': {'bench-0': logged(8, 55)},
        },
      };
      final r = exerciseRecords(sessions, ex('bench'), now, now: now);
      expect(r.previousSets.length, 2);
      expect(r.previousSets.first.date, '2026-10-25');
      expect(r.best!.kg, 55);
      expect(r.newPr, true);
      expect(
        exerciseRecords(sessions, ex('machinechest'), now, now: now).best!.kg,
        100,
      );
      (sessions['2026-11-01']['sets']['bench-0'] as Map)['checked'] = false;
      final reopened = exerciseRecords(sessions, ex('bench'), now, now: now);
      expect(reopened.best!.kg, 50);
      expect(reopened.newPr, false);
      sessions.remove('2026-10-25');
      expect(
        exerciseRecords(sessions, ex('bench'), now, now: now).best,
        isNull,
      );
    },
  );
  test(
    'assisted pull-up records favor lower assistance and ties favor more reps, including zero assistance',
    () {
      final sessions = <String, dynamic>{
        '2026-10-25': {
          'sets': {
            'assistedpullup-0': logged(12, 30),
            'assistedpullup-1': logged(8, 20),
            'assistedpullup-2': logged(10, 20),
          },
        },
      };
      final r = exerciseRecords(sessions, ex('assistedpullup'), now, now: now);
      expect(r.best!.kg, 20);
      expect(r.best!.reps, 10);
      expect(
        r.best!.describe(ex('assistedpullup')),
        '20 kg assistance × 10 reps',
      );
      sessions['2026-11-01'] = {
        'sets': {'assistedpullup-0': logged(5, 0)},
      };
      expect(
        exerciseRecords(sessions, ex('assistedpullup'), now, now: now).newPr,
        true,
      );
      expect(
        exerciseRecords(sessions, ex('assistedpullup'), now, now: now).best!.kg,
        0,
      );
    },
  );
  test('bodyweight reps, timed holds and added load stay separate', () {
    final sessions = <String, dynamic>{
      '2026-10-25': {
        'sets': {
          'pushup-0': logged(20, 0),
          'pushup-1': logged(8, 10),
          'plank-0': logged(60, 0),
          'plank-1': logged(30, 5),
        },
      },
      '2026-11-01': {
        'sets': {
          'pushup-0': logged(21, 0),
          'pushup-1': logged(9, 10),
          'plank-0': logged(45, 0),
          'plank-1': logged(25, 10),
        },
      },
    };
    final reps = exerciseRecords(sessions, ex('pushup'), now, now: now);
    expect(reps.best!.reps, 21);
    expect(reps.addedBest!.kg, 10);
    expect(reps.addedBest!.reps, 9);
    expect(reps.newPr, true);
    expect(reps.newAddedPr, true);
    final time = exerciseRecords(sessions, ex('plank'), now, now: now);
    expect(time.best!.reps, 60);
    expect(time.newPr, false);
    expect(time.addedBest!.kg, 10);
    expect(time.newAddedPr, true);
    expect(time.best!.describe(ex('plank')), '60 sec · bodyweight');
  });
  test(
    'invalid values and exercise prefixes cannot create a record; zero load is not a weighted PR',
    () {
      final sessions = <String, dynamic>{
        '2026-11-01': {
          'sets': {
            'bench-0': logged(8, 0),
            'bench-1': logged(8, double.nan),
            'bench-2': logged(8, -1),
            'bench-3': logged(601, 600),
            'bench-extra': logged(8, 99),
            'benchpress-0': logged(8, 100),
            'bench-4': logged(8, 600.1),
          },
        },
        '2026-02-30': {
          'sets': {'bench-0': logged(12, 120)},
        },
      };
      final r = exerciseRecords(sessions, ex('bench'), now, now: now);
      expect(r.best, isNull);
      expect(r.sets.length, 1);
    },
  );
  test(
    'records derive identically from cloud-style data, guest storage and backup reload',
    () async {
      SharedPreferences.setMockInitialValues({'forge.mode': 'guest'});
      final prefs = await SharedPreferences.getInstance(),
          s = AppStore(
            await SharedPreferences.getInstance(),
            enableCloud: true,
          );
      await s.load();
      s.profile = athlete;
      s.sessions['2026-10-25'] = {
        'name': 'Upper',
        'done': true,
        'sets': {'bench-0': logged(8, 60)},
        'exerciseIds': ['bench'],
        'plannedSets': 1,
      };
      await s.save();
      final copy = AppStore(prefs, enableCloud: true);
      await copy.load();
      expect(
        exerciseRecords(copy.sessions, ex('bench'), now, now: now).best!.kg,
        60,
      );
      final restored = AppStore(prefs);
      await restored.restore(s.backup());
      expect(
        exerciseRecords(
          restored.sessions,
          ex('bench'),
          now,
          now: now,
        ).best!.reps,
        8,
      );
      expect(restored.totalXp, s.totalXp);
      s.dispose();
      copy.dispose();
      restored.dispose();
    },
  );
  testWidgets(
    'PR card and full history fit small phone, and a live set updates then reopening removes its record',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final s = AppStore(await SharedPreferences.getInstance());
      s.profile = athlete;
      final today = calendarDay(DateTime.now()),
          prior = today.subtract(const Duration(days: 7));
      s.sessions[dayKey(prior)] = {
        'name': 'Earlier',
        'done': true,
        'sets': {'bench-0': logged(8, 50)},
      };
      s.sessions[dayKey(today)] = {
        'name': 'Upper',
        'done': false,
        'sets': <String, dynamic>{},
        'exerciseIds': ['bench'],
        'plannedSets': 1,
        'rotationIndex': 0,
        'rotationSize': 5,
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: WorkoutScreen(store: s, date: today),
        ),
      );
      await tester.scrollUntilVisible(
        find.byType(PersonalRecordCard),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('PR · 50 kg × 8 reps'), findsOneWidget);
      await tester.tap(find.byType(PersonalRecordCard));
      await tester.pumpAndSettle();
      expect(find.text('Heaviest recorded load'), findsOneWidget);
      expect(find.text('Set 1 · 50 kg × 8 reps'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close personal records'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(SetRow),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final fields = find.descendant(
        of: find.byType(SetRow),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '10');
      await tester.enterText(fields.at(1), '55');
      await tester.tap(find.byTooltip('Save completed set'));
      await tester.pump();
      expect(find.text('PR · 55 kg × 10 reps'), findsOneWidget);
      expect(find.text('NEW PR THIS SESSION'), findsOneWidget);
      await tester.tap(find.byTooltip('Reopen set'));
      await tester.pump();
      expect(find.text('PR · 50 kg × 8 reps'), findsOneWidget);
      expect(find.text('NEW PR THIS SESSION'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      s.dispose();
    },
  );

  test('trend keeps one best set per day using the same rule as the PR', () {
    final sessions = <String, dynamic>{
      '2026-10-05': {'sets': {'bench-0': logged(8, 50), 'bench-1': logged(10, 50)}},
      '2026-10-12': {'sets': {'bench-0': logged(8, 55), 'bench-1': logged(8, 70, checked: false)}},
      '2026-10-19': {'sets': {'dbpress-0': logged(10, 20)}},
      '2026-10-26': {'sets': {'bench-0': logged(6, 52.5)}},
      '2026-11-09': {'sets': {'bench-0': logged(8, 90)}},
    };
    final t = exerciseRecords(sessions, ex('bench'), now, now: now).trend();
    expect(t.map((p) => p.date), ['2026-10-05', '2026-10-12', '2026-10-26']);
    expect(t.map((p) => p.value), [50, 55, 52.5]);
    expect(t.first.set.reps, 10);
  });

  test('assisted trend tracks assistance; bodyweight trend tracks reps', () {
    final sessions = <String, dynamic>{
      '2026-10-05': {'sets': {'assistedpullup-0': logged(8, 30), 'plank-0': logged(30, 0)}},
      '2026-10-12': {'sets': {'assistedpullup-0': logged(8, 25), 'plank-0': logged(45, 0), 'plank-1': logged(20, 10)}},
    };
    final a = exerciseRecords(sessions, ex('assistedpullup'), now, now: now);
    expect(a.trend().map((p) => p.value), [30, 25]);
    expect(a.trendUnit, contains('lower is better'));
    final b = exerciseRecords(sessions, ex('plank'), now, now: now);
    expect(b.trend().map((p) => p.value), [30, 45]);
    expect(b.trendUnit, 'seconds');
  });

  test('trend is capped to the most recent sessions', () {
    final sessions = <String, dynamic>{
      for (var d = 1; d <= 20; d++)
        '2026-10-${d.toString().padLeft(2, '0')}': {'sets': {'bench-0': logged(8, d.toDouble())}},
    };
    final t = exerciseRecords(sessions, ex('bench'), now, now: now).trend();
    expect(t.length, 12);
    expect(t.first.value, 9);
    expect(t.last.value, 20);
  });

  testWidgets('trend chart needs two days, then shows the change', (tester) async {
    Future<void> show(Map<String, dynamic> sessions) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrTrendChart(records: exerciseRecords(sessions, ex('bench'), now, now: now)),
        ),
      ),
    );
    await show({'2026-10-05': {'sets': {'bench-0': logged(8, 50)}}});
    expect(find.textContaining('appears after two training days'), findsOneWidget);
    await show({
      '2026-10-05': {'sets': {'bench-0': logged(8, 50)}},
      '2026-10-12': {'sets': {'bench-0': logged(8, 57.5)}},
    });
    expect(find.text('+7.5 kg over 2 sessions'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
