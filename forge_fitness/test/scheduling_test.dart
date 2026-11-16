import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_fitness/models.dart';
import 'package:forge_fitness/training.dart';

const p = Profile(
  name: 'Sam',
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
Future<AppStore> setup() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppStore(await SharedPreferences.getInstance());
  s.profile = p;
  return s;
}

void finish(AppStore s, DateTime date, int index) {
  final w = rotationFor('Full gym', 5, 'Beginner')[index];
  s.sessions[dayKey(date)] = {
    'name': w.name,
    'done': true,
    'sets': <String, dynamic>{},
    'rotationIndex': index,
    'rotationSize': 5,
    'exerciseIds': w.exercises.map((e) => e.id).toList(),
    'plannedSets': w.sets,
  };
}

void main() {
  final monday = DateTime(2026, 10, 19),
      tuesday = DateTime(2026, 10, 20),
      wednesday = DateTime(2026, 10, 21);
  test(
    'Monday to Friday is five workouts and weekends default to recovery',
    () async {
      final s = await setup();
      expect(s.profile!.trainingDays, [1, 2, 3, 4, 5]);
      for (var i = 0; i < 5; i++) {
        expect(s.plansToTrain(monday.add(Duration(days: i))), true);
      }
      expect(s.workoutOn(monday.add(const Duration(days: 5))).rest, true);
      expect(s.workoutOn(monday.add(const Duration(days: 6))).rest, true);
    },
  );
  test('A missed Monday leaves the first workout for Tuesday', () async {
    final s = await setup();
    expect(s.workoutOn(monday).rotationIndex, 0);
    expect(s.workoutOn(tuesday).rotationIndex, 0);
    await s.setAttendance(monday, 'rest');
    expect(s.workoutOn(tuesday).rotationIndex, 0);
  });
  test('Completed work advances once; a skipped day does not', () async {
    final s = await setup();
    finish(s, monday, 0);
    expect(s.workoutOn(tuesday).rotationIndex, 1);
    await s.setAttendance(tuesday, 'rest');
    expect(s.workoutOn(tuesday).rest, true);
    expect(s.workoutOn(wednesday).rotationIndex, 1);
    expect(s.lastCompletedBefore(wednesday)!.key, dayKey(monday));
  });
  test('The rotation wraps after the fifth completed session', () async {
    final s = await setup();
    finish(s, DateTime(2026, 10, 23), 4);
    expect(s.workoutOn(DateTime(2026, 10, 26)).rotationIndex, 0);
  });
  test(
    'Custom weekdays persist and future forecasts never advance actual state',
    () async {
      final s = await setup();
      final j = p.toJson();
      j['days'] = 3;
      j['trainingDays'] = [2, 4, 6];
      s.profile = Profile.fromJson(j);
      expect(s.plansToTrain(monday), false);
      expect(s.plansToTrain(tuesday), true);
      expect(s.plansToTrain(DateTime(2026, 10, 24)), true);
      final before = s.backup();
      s.workoutOn(DateTime.now().add(const Duration(days: 14)));
      expect(s.backup(), before);
      await s.save();
      final loaded = AppStore(s.preferences);
      await loaded.load();
      expect(loaded.profile!.trainingDays, [2, 4, 6]);
    },
  );
  test('All rotations use unique exercises and available equipment', () {
    for (final equipment in ['Full gym', 'Dumbbells', 'Bodyweight']) {
      for (final days in [2, 3, 4, 5]) {
        final plan = rotationFor(equipment, days, 'Beginner');
        expect(plan.length, days);
        for (final w in plan) {
          expect(
            w.exercises.map((e) => e.id).toSet().length,
            w.exercises.length,
          );
          if (equipment == 'Bodyweight') {
            expect(w.exercises.every((e) => e.equipment == 'Bodyweight'), true);
          }
        }
      }
    }
  });
}
