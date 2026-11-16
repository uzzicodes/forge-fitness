import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'training.dart';
import 'weekly_review.dart';
import 'guest_food_client.dart';

String dayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
DateTime calendarDay(DateTime day) => DateTime(day.year, day.month, day.day);
const weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
String prettyDay(DateTime d) =>
    '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';

class Profile {
  final String name, sex, goal, equipment, experience;
  final double weight, height, activity;
  final int age, days;
  final List<int>? preferredDays;
  List<int> get trainingDays =>
      preferredDays ??
      (days == 2
          ? [1, 4]
          : days == 3
          ? [1, 3, 5]
          : days == 4
          ? [1, 2, 4, 5]
          : [1, 2, 3, 4, 5]);
  final int? calorieOverride, proteinOverride;
  final bool lowerBmiThresholds;
  const Profile({
    required this.name,
    required this.sex,
    required this.goal,
    required this.equipment,
    required this.experience,
    required this.weight,
    required this.height,
    required this.activity,
    required this.age,
    required this.days,
    this.preferredDays,
    this.calorieOverride,
    this.proteinOverride,
    this.lowerBmiThresholds = false,
  });
  double get bmi => weight / ((height / 100) * (height / 100));
  String get bmiCategory => bmi < 18.5
      ? 'Underweight'
      : bmi < (lowerBmiThresholds ? 23 : 25)
      ? 'Healthy BMI range'
      : bmi < (lowerBmiThresholds ? 27.5 : 30)
      ? 'Overweight BMI range'
      : 'Obesity BMI range';
  int get maintenanceCalories =>
      (((10 * weight + 6.25 * height - 5 * age + (sex == 'Male' ? 5 : -161)) *
                  activity) /
              10)
          .round() *
      10;
  bool get fatLossGoal =>
      goal == 'Reduce body fat' || goal == 'Reduce waist / belly fat';
  int get calories =>
      calorieOverride ??
      (maintenanceCalories +
              (goal == 'Build muscle'
                  ? 200
                  : fatLossGoal && bmi >= 18.5
                  ? -250
                  : 0))
          .clamp(fatLossGoal && sex == 'Male' ? 1500 : 1200, 6000);
  int get protein => proteinOverride ?? (weight * 1.6).round();
  Profile withGoal(String next) => Profile(
    name: name,
    sex: sex,
    goal: next,
    equipment: equipment,
    experience: experience,
    weight: weight,
    height: height,
    activity: activity,
    age: age,
    days: days,
    preferredDays: trainingDays,
    proteinOverride: proteinOverride,
    lowerBmiThresholds: lowerBmiThresholds,
  );
  Map<String, dynamic> toJson() => {
    'name': name,
    'sex': sex,
    'goal': goal,
    'equipment': equipment,
    'experience': experience,
    'weight': weight,
    'height': height,
    'activity': activity,
    'age': age,
    'days': days,
    'trainingDays': trainingDays,
    'calorieOverride': calorieOverride,
    'proteinOverride': proteinOverride,
    'lowerBmiThresholds': lowerBmiThresholds,
  };
  factory Profile.fromJson(Map<String, dynamic> j) {
    final p = Profile(
      name: j['name'] as String,
      sex: j['sex'] as String,
      goal: j['goal'] as String,
      equipment: j['equipment'] as String,
      experience: j['experience'] as String,
      weight: (j['weight'] as num).toDouble(),
      height: (j['height'] as num).toDouble(),
      activity: (j['activity'] as num).toDouble(),
      age: j['age'] as int,
      days: j['trainingDays'] == null ? 5 : j['days'] as int,
      preferredDays: j['trainingDays'] == null
          ? [1, 2, 3, 4, 5]
          : (j['trainingDays'] as List).cast<int>(),
      calorieOverride: j['calorieOverride'] as int?,
      proteinOverride: j['proteinOverride'] as int?,
      lowerBmiThresholds: j['lowerBmiThresholds'] as bool? ?? false,
    );
    if (p.name.trim().isEmpty ||
        !p.weight.isFinite ||
        !p.height.isFinite ||
        !p.activity.isFinite ||
        p.name.length > 30 ||
        p.weight < 30 ||
        p.weight > 300 ||
        p.height < 120 ||
        p.height > 230 ||
        p.age < 18 ||
        p.age > 85 ||
        ![2, 3, 4, 5].contains(p.days) ||
        p.trainingDays.length != p.days ||
        p.trainingDays.toSet().length != p.days ||
        p.trainingDays.any((d) => d < 1 || d > 7) ||
        ![1.2, 1.375, 1.55, 1.725].contains(p.activity) ||
        !['Male', 'Female'].contains(p.sex) ||
        ![
          'Lean & defined',
          'Build muscle',
          'Maintain & get stronger',
          'Improve endurance',
          'Reduce body fat',
          'Reduce waist / belly fat',
        ].contains(p.goal) ||
        !['Full gym', 'Dumbbells', 'Bodyweight'].contains(p.equipment) ||
        !['Beginner', 'Intermediate'].contains(p.experience) ||
        (p.calorieOverride != null &&
            (p.calorieOverride! < 1200 || p.calorieOverride! > 6000)) ||
        (p.proteinOverride != null &&
            (p.proteinOverride! < 30 || p.proteinOverride! > 350))) {
      throw const FormatException('Invalid profile values');
    }
    return p;
  }
}

class Meal {
  final String id, date, name, type, notes;
  final double calories, protein, carbs, fat;
  final bool estimated;
  final String source, photoUrl;
  const Meal({
    required this.id,
    required this.date,
    required this.name,
    required this.type,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.notes = '',
    this.estimated = false,
    this.source = 'manual',
    this.photoUrl = '',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'name': name,
    'type': type,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'notes': notes,
    'estimated': estimated,
    'source': source,
    'photoUrl': photoUrl,
  };
  factory Meal.fromJson(Map<String, dynamic> j) {
    final m = Meal(
      id: j['id'] as String,
      date: j['date'] as String,
      name: j['name'] as String,
      type: j['type'] as String,
      calories: (j['calories'] as num).toDouble(),
      protein: (j['protein'] as num).toDouble(),
      carbs: (j['carbs'] as num).toDouble(),
      fat: (j['fat'] as num).toDouble(),
      notes: j['notes'] as String? ?? '',
      estimated: j['estimated'] == true,
      source:
          j['source'] as String? ??
          (j['estimated'] == true ? 'estimate' : 'manual'),
      photoUrl: j['photoUrl'] as String? ?? '',
    );
    if ([
          m.calories,
          m.protein,
          m.carbs,
          m.fat,
        ].any((n) => !n.isFinite || n < 0) ||
        m.calories > 10000 ||
        [m.protein, m.carbs, m.fat].any((n) => n > 1500) ||
        m.name.trim().isEmpty ||
        m.name.length > 100 ||
        m.notes.length > 2000 ||
        m.id.isEmpty ||
        !['Breakfast', 'Lunch', 'Dinner', 'Snack'].contains(m.type) ||
        DateTime.tryParse(m.date) == null) {
      throw const FormatException('Invalid meal');
    }
    return m;
  }
}

class AppStore extends ChangeNotifier {
  final SharedPreferences preferences;
  Profile? profile;
  List<Meal> meals = [];
  Map<String, dynamic> sessions = {}, water = {};
  Map<String, dynamic> attendance = {};
  Map<String, dynamic> habits = {}, habitLogs = {};
  Map<String, dynamic> weekPlans = {};
  Map<String, dynamic> accountPreferences = {'waterTargetMl': 2000};
  int get waterTargetMl =>
      (accountPreferences['waterTargetMl'] as num? ?? 2000).round();
  double waterMl(DateTime date) => (water[dayKey(date)] as num? ?? 0) * 250.0;
  List<Map<String, dynamic>> weights = [];
  String server = '', token = '';
  bool storageError = false;
  final bool hosted;
  bool _guestMode = false;
  bool get guestMode => hosted && _guestMode;
  bool get cloudEnabled => hosted && !_guestMode;
  String get stateStorageKey => guestMode ? 'forge.guest.v1' : 'forge.v1';
  http.Client foodClient() =>
      guestMode ? GuestFoodClient(preferences) : http.Client();
  final http.Client? syncClient;
  String syncStatus = 'Local', clientId = '';
  bool cloudAuthRequired = false, _syncing = false;
  int _clock = 0;
  Timer? _syncTimer;
  Map<String, String> _baseline = {};
  Map<String, dynamic> _pending = {};
  AppStore(this.preferences, {bool? enableCloud, this.syncClient})
    : hosted = enableCloud ?? const bool.fromEnvironment('FORGE_HOSTED');
  Future<http.Response> _cloudGet(Uri uri) =>
      syncClient?.get(uri) ?? http.get(uri);
  Future<http.Response> _cloudPost(Uri uri, String body) =>
      syncClient?.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ) ??
      http.post(uri, headers: {'Content-Type': 'application/json'}, body: body);
  Future<void> load() async {
    try {
      if (hosted) {
        final mode = kIsWeb ? Uri.base.queryParameters['mode'] : null;
        if (mode == 'guest' || mode == 'account') {
          await preferences.setString('forge.mode', mode!);
        }
        _guestMode = preferences.getString('forge.mode') == 'guest';
      }
      final raw = preferences.getString(stateStorageKey);
      if (raw != null) {
        _read(jsonDecode(raw) as Map<String, dynamic>);
      }
      server = guestMode ? '' : preferences.getString('forge.server') ?? '';
      token = guestMode ? '' : preferences.getString('forge.token') ?? '';
      _pending = guestMode
          ? {}
          : Map<String, dynamic>.from(
              jsonDecode(preferences.getString('forge.cloud.pending') ?? '{}')
                  as Map,
            );
    } catch (_) {
      storageError = true;
    }
    _baseline = _flatten(
      toJson(),
    ).map((key, value) => MapEntry(key, jsonEncode(value)));
    if (cloudEnabled) {
      clientId =
          preferences.getString('forge.cloud.client') ??
          '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${math.Random.secure().nextInt(1 << 30).toRadixString(36)}';
      await preferences.setString('forge.cloud.client', clientId);
      await syncCloud();
    }
    if (guestMode) syncStatus = 'Guest · this device';
    if (!storageError &&
        !cloudAuthRequired &&
        _prepareWeeklyGoals(DateTime.now())) {
      await save();
    }
    notifyListeners();
  }

  void _read(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw const FormatException('Unsupported backup version');
    }
    final nextProfile = j['profile'] == null
        ? null
        : Profile.fromJson(j['profile'] as Map<String, dynamic>);
    final nextMeals = (j['meals'] as List)
        .map((m) => Meal.fromJson(m as Map<String, dynamic>))
        .toList();
    if (nextMeals.map((m) => m.id).toSet().length != nextMeals.length) {
      throw const FormatException('Duplicate meal identifiers');
    }
    final nextWeights = (j['weights'] as List)
        .map((w) => Map<String, dynamic>.from(w as Map))
        .toList();
    for (final w in nextWeights) {
      if (DateTime.tryParse(w['date'] as String) == null ||
          w['kg'] is! num ||
          (w['kg'] as num) < 30 ||
          (w['kg'] as num) > 300) {
        throw const FormatException('Invalid weight');
      }
    }
    final nextWater = Map<String, dynamic>.from(j['water'] as Map);
    for (final entry in nextWater.entries) {
      if (DateTime.tryParse(entry.key) == null ||
          entry.value is! num ||
          !(entry.value as num).isFinite ||
          (entry.value as num) < 0 ||
          (entry.value as num) > 40) {
        throw const FormatException('Invalid water log');
      }
    }
    final nextSessions = Map<String, dynamic>.from(j['sessions'] as Map);
    final nextAttendance = Map<String, dynamic>.from(
      j['attendance'] as Map? ?? {},
    );
    for (final e in nextAttendance.entries) {
      if (DateTime.tryParse(e.key) == null ||
          !['train', 'rest'].contains(e.value)) {
        throw const FormatException('Invalid attendance');
      }
    }
    for (final entry in nextSessions.entries) {
      if (DateTime.tryParse(entry.key) == null || entry.value is! Map) {
        throw const FormatException('Invalid workout log');
      }
      final session = entry.value as Map;
      if (session['rotationIndex'] != null &&
          (session['rotationIndex'] is! int ||
              (session['rotationIndex'] as int) < 0 ||
              (session['rotationIndex'] as int) > 4 ||
              ![2, 3, 4, 5].contains(session['rotationSize']))) {
        throw const FormatException('Invalid workout sequence');
      }
      if (session['done'] is! bool ||
          session['name'] is! String ||
          session['sets'] is! Map) {
        throw const FormatException('Invalid workout');
      }
      if (session.containsKey('exerciseIds')) {
        final ids = session['exerciseIds'];
        if (ids is! List ||
            ids.isEmpty ||
            ids.length > 12 ||
            ids.any((id) => id is! String || !library.any((e) => e.id == id)) ||
            ids.toSet().length != ids.length ||
            session['plannedSets'] is! int ||
            (session['plannedSets'] as int) < 1 ||
            (session['plannedSets'] as int) > 5) {
          throw const FormatException('Invalid saved training plan');
        }
      }
      final targets = session['setTargets'];
      final retired = session['retiredExerciseIds'];
      if (targets != null &&
          (targets is! Map ||
              targets.entries.any(
                (e) =>
                    !(session['exerciseIds'] as List? ?? []).contains(e.key) ||
                    e.value is! int ||
                    (e.value as int) < 1 ||
                    (e.value as int) > 5,
              ))) {
        throw const FormatException('Invalid replacement set targets');
      }
      if (retired != null &&
          (retired is! List ||
              retired.length > 20 ||
              retired.toSet().length != retired.length ||
              retired.any(
                (id) =>
                    !library.any((e) => e.id == id) ||
                    (session['exerciseIds'] as List? ?? []).contains(id),
              ))) {
        throw const FormatException('Invalid replaced exercise history');
      }
      for (final set in (session['sets'] as Map).values) {
        if (set is! Map ||
            set['checked'] is! bool ||
            set['reps'] is! int ||
            set['kg'] is! num ||
            (set['reps'] as num) < 0 ||
            (set['reps'] as num) > 600 ||
            !(set['kg'] as num).isFinite ||
            (set['kg'] as num) > 600 ||
            (set['kg'] as num) < 0) {
          throw const FormatException('Invalid set');
        }
      }
    }
    final nextHabits = Map<String, dynamic>.from(j['habits'] as Map? ?? {});
    final nextHabitLogs = Map<String, dynamic>.from(
      j['habitLogs'] as Map? ?? {},
    );
    final nextPreferences = Map<String, dynamic>.from(
      j['preferences'] as Map? ?? {'waterTargetMl': 2000},
    );
    final target = nextPreferences['waterTargetMl'];
    if (target is! int || target < 500 || target > 6000) {
      throw const FormatException('Invalid water target');
    }
    final nextWeekPlans = Map<String, dynamic>.from(
      j['weekPlans'] as Map? ?? {},
    );
    for (final entry in nextWeekPlans.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date == null ||
          weekKey(date) != entry.key ||
          date.weekday != DateTime.monday ||
          date.year < 2026 ||
          date.year > 2100 ||
          entry.value is! Map) {
        throw const FormatException('Invalid weekly plan');
      }
      WeekTargets.fromJson(entry.value as Map);
    }
    if (nextPreferences['weeklyXpStart'] != null) {
      final start = DateTime.tryParse(
        nextPreferences['weeklyXpStart'] as String,
      );
      if (start == null ||
          weekKey(start) != nextPreferences['weeklyXpStart'] ||
          start.weekday != DateTime.monday ||
          start.year < 2026 ||
          start.year > 2100) {
        throw const FormatException('Invalid weekly XP start');
      }
    }
    if (nextPreferences['weeklyXpOffsetMinutes'] != null &&
        (nextPreferences['weeklyXpOffsetMinutes'] is! int ||
            (nextPreferences['weeklyXpOffsetMinutes'] as int) < -720 ||
            (nextPreferences['weeklyXpOffsetMinutes'] as int) > 840)) {
      throw const FormatException('Invalid weekly clock');
    }
    for (final h in nextHabits.values) {
      if (h is! Map ||
          h['title'] is! String ||
          (h['title'] as String).trim().isEmpty ||
          (h['title'] as String).length > 60 ||
          h['enabled'] is! bool) {
        throw const FormatException('Invalid habit');
      }
    }
    for (final log in nextHabitLogs.entries) {
      if (DateTime.tryParse(log.key) == null ||
          log.value is! Map ||
          (log.value as Map).values.any((v) => v is! bool)) {
        throw const FormatException('Invalid habit log');
      }
    }
    profile = nextProfile;
    meals = nextMeals;
    weights = nextWeights;
    water = nextWater;
    sessions = nextSessions;
    attendance = nextAttendance;
    habits = nextHabits;
    habitLogs = nextHabitLogs;
    accountPreferences = nextPreferences;
    weekPlans = nextWeekPlans;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'profile': profile?.toJson(),
    'meals': meals.map((m) => m.toJson()).toList(),
    'sessions': sessions,
    'attendance': attendance,
    'water': water,
    'weights': weights,
    'habits': habits,
    'habitLogs': habitLogs,
    'preferences': accountPreferences,
    'weekPlans': weekPlans,
  };
  String backup() => const JsonEncoder.withIndent('  ').convert({
    ...toJson(),
    if (guestMode)
      'deviceLabels': jsonDecode(
        preferences.getString('forge.guest.labels') ?? '[]',
      ),
    if (guestMode)
      'deviceRecipes': jsonDecode(
        preferences.getString('forge.guest.recipes') ?? '[]',
      ),
  });
  Future<void> restore(String raw) async {
    final state = jsonDecode(raw) as Map<String, dynamic>;
    if (guestMode) {
      for (final key in ['deviceLabels', 'deviceRecipes']) {
        final rows = state[key];
        if (rows != null &&
            (rows is! List ||
                rows.length > 100 ||
                rows.any((r) => r is! Map || r['name'] is! String))) {
          throw const FormatException('Invalid device food library');
        }
      }
    }
    _read(state);
    await save();
    if (guestMode) {
      if (state['deviceLabels'] != null) {
        await preferences.setString(
          'forge.guest.labels',
          jsonEncode(state['deviceLabels']),
        );
      }
      if (state['deviceRecipes'] != null) {
        await preferences.setString(
          'forge.guest.recipes',
          jsonEncode(state['deviceRecipes']),
        );
      }
    }
  }

  Future<void> save() async {
    _prepareWeeklyGoals(DateTime.now());
    if (cloudEnabled) {
      final next = _flatten(toJson());
      for (final key in {..._baseline.keys, ...next.keys}) {
        if (_baseline[key] != jsonEncode(next[key])) {
          _clock = math.max(
            DateTime.now().toUtc().microsecondsSinceEpoch,
            _clock + 1,
          );
          _pending[key] = {
            'key': key,
            'clock': '${_clock.toString().padLeft(16, '0')}-$clientId',
            'value': next.containsKey(key)
                ? jsonDecode(jsonEncode(next[key]))
                : null,
          };
        }
      }
      _baseline = next.map((key, value) => MapEntry(key, jsonEncode(value)));
      syncStatus = 'Queued';
      await preferences.setString('forge.cloud.pending', jsonEncode(_pending));
      _syncTimer?.cancel();
      _syncTimer = Timer(const Duration(milliseconds: 650), () => syncCloud());
    }
    try {
      storageError = !await preferences.setString(
        stateStorageKey,
        jsonEncode(toJson()),
      );
    } catch (_) {
      storageError = true;
    }
    notifyListeners();
  }

  Map<String, dynamic> _flatten(Map<String, dynamic> state) {
    final flat = <String, dynamic>{
      'profile': state['profile'],
      'preferences': state['preferences'],
    };
    for (final m in state['meals'] as List) {
      flat['meal:${m['id']}'] = m;
    }
    for (final w in state['weights'] as List) {
      flat['weight:${w['date']}'] = w;
    }
    for (final pair in {
      'session': 'sessions',
      'water': 'water',
      'attendance': 'attendance',
      'habit': 'habits',
      'habitlog': 'habitLogs',
      'weekplan': 'weekPlans',
    }.entries) {
      for (final entry in (state[pair.value] as Map).entries) {
        flat['${pair.key}:${entry.key}'] = entry.value;
      }
    }
    return flat;
  }

  Map<String, dynamic> _unflatten(Map<String, dynamic> flat) {
    final state = <String, dynamic>{
      'version': 1,
      'profile': null,
      'meals': <dynamic>[],
      'weights': <dynamic>[],
      'sessions': <String, dynamic>{},
      'water': <String, dynamic>{},
      'attendance': <String, dynamic>{},
      'habits': <String, dynamic>{},
      'habitLogs': <String, dynamic>{},
      'weekPlans': <String, dynamic>{},
      'preferences': <String, dynamic>{'waterTargetMl': 2000},
    };
    for (final e in flat.entries) {
      if (e.value == null) continue;
      final p = e.key.indexOf(':');
      final kind = p < 0 ? e.key : e.key.substring(0, p);
      final id = p < 0 ? '' : e.key.substring(p + 1);
      switch (kind) {
        case 'profile':
          state['profile'] = e.value;
        case 'meal':
          (state['meals'] as List).add(e.value);
        case 'weight':
          (state['weights'] as List).add(e.value);
        case 'session':
          (state['sessions'] as Map)[id] = e.value;
        case 'water':
          (state['water'] as Map)[id] = e.value;
        case 'attendance':
          (state['attendance'] as Map)[id] = e.value;
        case 'preferences':
          state['preferences'] = e.value;
        case 'habit':
          (state['habits'] as Map)[id] = e.value;
        case 'habitlog':
          (state['habitLogs'] as Map)[id] = e.value;
        case 'weekplan':
          (state['weekPlans'] as Map)[id] = e.value;
      }
    }
    return state;
  }

  Future<void> syncCloud() async {
    if (!cloudEnabled || _syncing) return;
    _syncing = true;
    try {
      syncStatus = 'Syncing';
      notifyListeners();
      final status = await _cloudGet(
        Uri.base.resolve('/api/status'),
      ).timeout(const Duration(seconds: 12));
      if (status.statusCode == 401) {
        cloudAuthRequired = true;
        syncStatus = 'Sign in';
        return;
      }
      if (status.statusCode != 200) {
        throw const FormatException('Cloud unavailable');
      }
      cloudAuthRequired = false;
      final info = jsonDecode(status.body) as Map<String, dynamic>;
      final owner = info['userId'] as String;
      final previousOwner = preferences.getString('forge.cloud.owner');
      if (previousOwner != null && previousOwner != owner) {
        _pending = {};
        _read(_unflatten({}));
        _baseline = _flatten(
          toJson(),
        ).map((key, value) => MapEntry(key, jsonEncode(value)));
        await preferences.setString('forge.v1', jsonEncode(toJson()));
        await preferences.setString('forge.cloud.pending', '{}');
      }
      await preferences.setString('forge.cloud.owner', owner);
      while (_pending.isNotEmpty) {
        final batch = _pending.values
            .take(30)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        final result = await _cloudPost(
          Uri.base.resolve('/api/sync'),
          jsonEncode({'changes': batch}),
        ).timeout(const Duration(seconds: 15));
        if (result.statusCode != 200) {
          throw const FormatException('Sync rejected');
        }
        for (final op in batch) {
          if ((_pending[op['key']] as Map?)?['clock'] == op['clock']) {
            _pending.remove(op['key']);
          }
        }
        await preferences.setString(
          'forge.cloud.pending',
          jsonEncode(_pending),
        );
      }
      final response = await _cloudGet(
        Uri.base.resolve('/api/state'),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const FormatException('Cloud read failed');
      }
      final records = (jsonDecode(response.body) as Map)['records'] as List;
      final flat = <String, dynamic>{};
      for (final r in records) {
        flat[r['key'] as String] = r['value'];
        final remoteClock =
            int.tryParse((r['clock'] as String).split('-').first) ?? 0;
        _clock = math.max(_clock, remoteClock);
      }
      for (final op in _pending.values) {
        flat[op['key'] as String] = op['value'];
      }
      _read(_unflatten(flat));
      _baseline = _flatten(
        toJson(),
      ).map((key, value) => MapEntry(key, jsonEncode(value)));
      await preferences.setString('forge.v1', jsonEncode(toJson()));
      syncStatus = _pending.isEmpty ? 'Synced' : 'Queued';
      if (info['catalogReady'] != true) unawaited(warmCatalog());
    } catch (_) {
      syncStatus = _pending.isEmpty ? 'Offline' : 'Offline · queued';
    } finally {
      _syncing = false;
      notifyListeners();
    }
    if (!storageError &&
        !cloudAuthRequired &&
        _prepareWeeklyGoals(DateTime.now())) {
      await save();
    }
  }

  bool _importingCatalog = false;
  Future<void> continueAsGuest() async {
    if (!hosted || _syncing) return;
    _syncTimer?.cancel();
    // Account cache and queued edits are left in their original namespace.
    await preferences.setString('forge.mode', 'guest');
    _guestMode = true;
    _pending = {};
    _baseline = {};
    _read(_unflatten({}));
    cloudAuthRequired = false;
    storageError = false;
    server = '';
    token = '';
    final raw = preferences.getString(stateStorageKey);
    if (raw != null) {
      try {
        _read(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        storageError = true;
      }
    }
    syncStatus = 'Guest · this device';
    if (!storageError && _prepareWeeklyGoals(DateTime.now())) await save();
    notifyListeners();
  }

  Future<void> clearAccountCache() async {
    _syncTimer?.cancel();
    _pending = {};
    _read(_unflatten({}));
    _baseline = _flatten(
      toJson(),
    ).map((key, value) => MapEntry(key, jsonEncode(value)));
    await preferences.remove('forge.v1');
    await preferences.remove('forge.cloud.pending');
    await preferences.remove('forge.cloud.owner');
    // Navigation to the managed sign-out route follows immediately.
  }

  Future<void> warmCatalog() async {
    if (_importingCatalog) return;
    _importingCatalog = true;
    try {
      for (var i = 0; i < 45; i++) {
        final r = await _cloudPost(
          Uri.base.resolve('/api/catalog/bootstrap'),
          '{}',
        ).timeout(const Duration(seconds: 20));
        if (r.statusCode != 200) break;
        final data = jsonDecode(r.body) as Map;
        if (data['complete'] == true) break;
      }
    } catch (_) {
    } finally {
      _importingCatalog = false;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> saveConnection(String url, String pairing) async {
    server = url.trim().replaceFirst(RegExp(r'/+$'), '');
    token = pairing.trim();
    await preferences.setString('forge.server', server);
    await preferences.setString('forge.token', token);
    notifyListeners();
  }

  List<Meal> mealsFor(DateTime day) =>
      meals.where((m) => m.date == dayKey(day)).toList();
  double total(DateTime day, String macro) => mealsFor(day).fold(
    0,
    (v, m) =>
        v +
        switch (macro) {
          'protein' => m.protein,
          'carbs' => m.carbs,
          'fat' => m.fat,
          _ => m.calories,
        },
  );
  Future<void> setProfile(Profile p) async {
    profile = p;
    await save();
  }

  Future<void> upsertMeal(Meal m) async {
    meals.removeWhere((x) => x.id == m.id);
    meals.add(m);
    await save();
  }

  Future<void> removeMeal(String id) async {
    meals.removeWhere((m) => m.id == id);
    await save();
  }

  Future<void> addWater(DateTime date, num amount) async {
    final k = dayKey(date);
    water[k] = ((water[k] as num? ?? 0) + amount).clamp(0, 40);
    await save();
  }

  Future<void> setWaterTarget(int ml) async {
    if (ml < 500 || ml > 6000) throw ArgumentError('Choose 500–6000 ml');
    accountPreferences['waterTargetMl'] = ml;
    await save();
  }

  Future<void> setHabit(String id, String title, {bool enabled = true}) async {
    if (title.trim().isEmpty || title.length > 60) {
      throw ArgumentError('Use a short habit name');
    }
    habits[id] = {'title': title.trim(), 'enabled': enabled};
    await save();
  }

  Future<void> checkHabit(DateTime date, String id, bool done) async {
    final key = dayKey(date),
        logs = Map<String, dynamic>.from(habitLogs[key] as Map? ?? {});
    logs[id] = done;
    habitLogs[key] = logs;
    await save();
  }

  int streak(DateTime today, {String? habitId}) {
    bool active(DateTime day) {
      final key = dayKey(day);
      if (habitId != null) return (habitLogs[key] as Map?)?[habitId] == true;
      return meals.any((m) => m.date == key) ||
          (water[key] as num? ?? 0) > 0 ||
          (sessions[key] as Map?)?['done'] == true ||
          attendance[key] == 'rest' ||
          ((habitLogs[key] as Map?)?.values.any((v) => v == true) ?? false);
    }

    var cursor = calendarDay(today);
    if (!active(cursor)) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var count = 0;
    while (active(cursor) && count < 36600) {
      count++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return count;
  }

  DateTime xpToday([DateTime? now]) {
    final offset =
        accountPreferences['weeklyXpOffsetMinutes'] as int? ??
        (now ?? DateTime.now()).timeZoneOffset.inMinutes;
    return weekDay(
      (now ?? DateTime.now()).toUtc().add(Duration(minutes: offset)),
    );
  }

  DateTime? get weeklyXpStart => accountPreferences['weeklyXpStart'] == null
      ? null
      : DateTime.tryParse(accountPreferences['weeklyXpStart'] as String);
  WeekTargets get currentWeekTargets => WeekTargets(
    trainingDays: profile?.days ?? 5,
    calories: profile?.calories ?? 2000,
    protein: profile?.protein ?? 100,
    waterMl: waterTargetMl,
  );
  WeekTargets targetsForWeek(DateTime date) {
    final key = weekKey(weekMonday(date)),
        keys = weekPlans.keys.where((k) => k.compareTo(key) <= 0).toList()
          ..sort();
    if (keys.isEmpty) return currentWeekTargets;
    final chosen = keys.last;
    final t = WeekTargets.fromJson(weekPlans[chosen] as Map);
    return chosen == key ? t : t.withRecovery(false);
  }

  bool _prepareWeeklyGoals(DateTime now) {
    if (profile == null || storageError || cloudAuthRequired) return false;
    var changed = false;
    if (weeklyXpStart == null) {
      accountPreferences['weeklyXpOffsetMinutes'] =
          now.timeZoneOffset.inMinutes;
      accountPreferences['weeklyXpStart'] = weekKey(
        weekMonday(xpToday(now)).add(const Duration(days: 7)),
      );
      changed = true;
    }
    final today = xpToday(now),
        start = weekDay(weeklyXpStart!),
        thisMonday = weekMonday(today);
    if (!thisMonday.isBefore(start) &&
        !weekPlans.containsKey(weekKey(thisMonday))) {
      weekPlans[weekKey(thisMonday)] = targetsForWeek(thisMonday).toJson();
      changed = true;
    }
    final next = thisMonday.isBefore(start)
            ? start
            : thisMonday.add(const Duration(days: 7)),
        key = weekKey(next);
    final proposed = currentWeekTargets
        .withRecovery((weekPlans[key] as Map?)?['recovery'] == true)
        .toJson();
    if (jsonEncode(weekPlans[key]) != jsonEncode(proposed)) {
      weekPlans[key] = proposed;
      changed = true;
    }
    return changed;
  }

  Future<void> setRecoveryWeek(bool recovery) async {
    _prepareWeeklyGoals(DateTime.now());
    final now = xpToday(), start = weeklyXpStart;
    if (start == null) return;
    final current = weekMonday(now),
        week = current.isBefore(start) ? weekDay(start) : current;
    weekPlans[weekKey(week)] = targetsForWeek(
      week,
    ).withRecovery(recovery).toJson();
    await save();
  }

  Map<String, DayFuel> get fuelByDay {
    final result = <String, DayFuel>{};
    DayFuel day(String key) => result.putIfAbsent(key, () => DayFuel());
    for (final meal in meals) {
      final d = day(meal.date);
      d.meals++;
      d.calories += meal.calories;
      d.protein += meal.protein;
    }
    for (final e in water.entries) {
      day(e.key).waterMl = (e.value as num) * 250;
    }
    for (final e in sessions.entries) {
      day(e.key).trained = (e.value as Map)['done'] == true;
    }
    return result;
  }

  Map<String, int> get earnedXpByDay {
    final result = <String, int>{};
    void add(String key, int n) => result[key] = (result[key] ?? 0) + n;
    for (final date in meals.map((m) => m.date).toSet()) {
      add(date, 10);
    }
    for (final e in sessions.entries) {
      if ((e.value as Map)['done'] == true) add(e.key, 60);
    }
    for (final e in water.entries) {
      if ((e.value as num) > 0) add(e.key, 10);
    }
    for (final e in attendance.entries) {
      if (e.value == 'rest') add(e.key, 5);
    }
    for (final e in habitLogs.entries) {
      add(e.key, (e.value as Map).values.where((v) => v == true).length * 10);
    }
    return result;
  }

  WeeklyLedger xpLedger([DateTime? now]) => calculateWeeklyXp(
    today: xpToday(now),
    start: weeklyXpStart,
    targets: weekPlans.map(
      (k, v) => MapEntry(k, WeekTargets.fromJson(v as Map)),
    ),
    days: fuelByDay,
    earnedByDay: earnedXpByDay,
  );
  WeekReview weekReview(DateTime date, [DateTime? now]) => WeekReview(
    monday: weekMonday(date),
    today: xpToday(now),
    targets: targetsForWeek(date),
    days: fuelByDay,
  );
  int get earnedXp => xpLedger().earnedXp;
  int get deductedXp => xpLedger().deductedXp;
  int get totalXp => xpLedger().netXp;

  Future<void> confirmMealEstimate(
    DateTime date,
    Map<String, dynamic> estimate,
  ) async {
    if (estimate['needsClarification'] == true) {
      throw ArgumentError('Clarify the food first');
    }
    final items = estimate['items'] as List? ?? [];
    if (items.isNotEmpty || estimate['is_food'] == true) {
      final hour = DateTime.now().hour;
      meals.add(
        Meal(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          date: dayKey(date),
          name: estimate['name'] as String,
          type: hour < 11
              ? 'Breakfast'
              : hour < 16
              ? 'Lunch'
              : hour < 22
              ? 'Dinner'
              : 'Snack',
          calories: (estimate['calories'] as num).toDouble(),
          protein: (estimate['protein'] as num).toDouble(),
          carbs: (estimate['carbs'] as num).toDouble(),
          fat: (estimate['fat'] as num).toDouble(),
          notes: '${estimate['original'] ?? ''}\n${estimate['portion'] ?? ''}\n${estimate['assumptions'] ?? ''}'
              .substring(
                0,
                math.min(
                  2000,
                  '${estimate['original'] ?? ''}\n${estimate['portion'] ?? ''}\n${estimate['assumptions'] ?? ''}'
                      .length,
                ),
              ),
          estimated: true,
          source: estimate['source'] as String? ?? 'Food estimate',
        ),
      );
    }
    final ml = (estimate['waterMl'] as num? ?? 0).toDouble();
    if (ml > 0) {
      water[dayKey(date)] = ((water[dayKey(date)] as num? ?? 0) + ml / 250)
          .clamp(0, 40);
    }
    await save();
  }

  Future<void> addWeight(DateTime date, double kg) async {
    weights.removeWhere((w) => w['date'] == dayKey(date));
    weights.add({'date': dayKey(date), 'kg': kg});
    weights.sort(
      (a, b) => (a['date'] as String).compareTo(b['date'] as String),
    );
    await save();
  }

  Future<void> setAttendance(DateTime day, String value) async {
    if (!['train', 'rest'].contains(value)) {
      throw ArgumentError('Invalid attendance');
    }
    attendance[dayKey(day)] = value;
    await save();
  }

  MapEntry<String, dynamic>? lastCompletedBefore(DateTime day) {
    final entries =
        sessions.entries
            .where(
              (e) =>
                  e.key.compareTo(dayKey(day)) < 0 &&
                  (e.value as Map)['done'] == true,
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return entries.isEmpty ? null : entries.last;
  }

  int nextRotationIndex(DateTime day) {
    final last = lastCompletedBefore(day);
    final size = profile!.days;
    if (last == null) return 0;
    final j = last.value as Map;
    if (j['rotationIndex'] is int && j['rotationSize'] == size) {
      return ((j['rotationIndex'] as int) + 1) % size;
    }
    if (j['rotationIndex'] is int) return 0;
    return sessions.entries
            .where(
              (e) =>
                  e.key.compareTo(dayKey(day)) < 0 &&
                  (e.value as Map)['done'] == true,
            )
            .length %
        size;
  }

  bool plansToTrain(DateTime day) =>
      attendance[dayKey(day)] == 'train' ||
      (attendance[dayKey(day)] != 'rest' &&
          profile!.trainingDays.contains(day.weekday));
  Workout workoutOn(DateTime day, {bool forceTraining = false}) {
    final saved = sessions[dayKey(day)];
    if (saved is Map &&
        saved['exerciseIds'] is List &&
        (saved['done'] == true ||
            forceTraining ||
            attendance[dayKey(day)] != 'rest')) {
      return Workout(
        saved['name'] as String,
        'Your saved workout',
        (saved['exerciseIds'] as List).map((id) => ex(id as String)).toList(),
        saved['plannedSets'] as int,
        saved['rotationIndex'] as int?,
      );
    }
    if (!forceTraining && !plansToTrain(day)) return recoveryWorkout;
    final p = profile!;
    final rotation = rotationFor(
      p.equipment,
      p.days,
      p.experience,
      goal: p.goal,
    );
    final today = calendarDay(DateTime.now());
    var index = nextRotationIndex(day.isAfter(today) ? today : day);
    if (day.isAfter(today)) {
      for (
        var d = today;
        d.isBefore(calendarDay(day));
        d = d.add(const Duration(days: 1))
      ) {
        final logged = sessions[dayKey(d)] as Map?;
        if (logged?['done'] == true) {
          index = logged?['rotationIndex'] is int
              ? ((logged!['rotationIndex'] as int) + 1) % rotation.length
              : (index + 1) % rotation.length;
        } else if (plansToTrain(d)) {
          index = (index + 1) % rotation.length;
        }
      }
    }
    return rotation[index];
  }
}
