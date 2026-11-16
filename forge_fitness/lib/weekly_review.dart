import 'dart:math' as math;

DateTime weekDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);
String weekKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime weekMonday(DateTime d) {
  final day = weekDay(d);
  return day.subtract(Duration(days: day.weekday - 1));
}

class WeekTargets {
  final int trainingDays, calories, protein, waterMl;
  final bool recovery;
  const WeekTargets({
    required this.trainingDays,
    required this.calories,
    required this.protein,
    required this.waterMl,
    this.recovery = false,
  });
  factory WeekTargets.fromJson(Map j) {
    bool valid(String k, int low, int high) =>
        j[k] is int && (j[k] as int) >= low && (j[k] as int) <= high;
    if (!valid('trainingDays', 2, 5) ||
        !valid('calories', 1200, 6000) ||
        !valid('protein', 30, 600) ||
        !valid('waterMl', 500, 6000) ||
        j['recovery'] is! bool) {
      throw const FormatException('Invalid weekly targets');
    }
    return WeekTargets(
      trainingDays: j['trainingDays'],
      calories: j['calories'],
      protein: j['protein'],
      waterMl: j['waterMl'],
      recovery: j['recovery'],
    );
  }
  Map<String, dynamic> toJson() => {
    'trainingDays': trainingDays,
    'calories': calories,
    'protein': protein,
    'waterMl': waterMl,
    'recovery': recovery,
  };
  WeekTargets withRecovery(bool value) => WeekTargets(
    trainingDays: trainingDays,
    calories: calories,
    protein: protein,
    waterMl: waterMl,
    recovery: value,
  );
}

class DayFuel {
  double calories = 0, protein = 0, waterMl = 0;
  int meals = 0;
  bool trained = false;
  bool proteinMet(WeekTargets t) => protein >= t.protein;
  bool caloriesMet(WeekTargets t) =>
      calories >= t.calories * .9 && calories <= t.calories * 1.1;
  bool waterMet(WeekTargets t) => waterMl >= t.waterMl;
  bool allMet(WeekTargets t) => proteinMet(t) && caloriesMet(t) && waterMet(t);
  bool get hasLogs => meals > 0 || waterMl > 0 || trained;
}

class WeekReview {
  final DateTime monday, today;
  final WeekTargets targets;
  final Map<String, DayFuel> days;
  final int appliedPenalty;
  const WeekReview({
    required this.monday,
    required this.today,
    required this.targets,
    required this.days,
    this.appliedPenalty = 0,
  });
  DateTime get nextMonday => monday.add(const Duration(days: 7));
  bool get closed => !nextMonday.isAfter(today);
  List<DateTime> get completedDays => [
    for (var i = 0; i < 7; i++)
      if (monday.add(Duration(days: i)).isBefore(today))
        monday.add(Duration(days: i)),
  ];
  DayFuel day(DateTime date) => days[weekKey(date)] ?? DayFuel();
  int get workouts => [
    for (var i = 0; i < 7; i++) monday.add(Duration(days: i)),
  ].where((d) => !d.isAfter(today) && day(d).trained).length;
  int get missedWorkouts =>
      closed ? math.max(0, targets.trainingDays - workouts) : 0;
  int get proteinGaps =>
      completedDays.where((d) => !day(d).proteinMet(targets)).length;
  int get calorieGaps =>
      completedDays.where((d) => !day(d).caloriesMet(targets)).length;
  int get waterGaps =>
      completedDays.where((d) => !day(d).waterMet(targets)).length;
  int get rawPenalty => targets.recovery
      ? 0
      : missedWorkouts * 25 + proteinGaps * 5 + calorieGaps * 5 + waterGaps * 3;
  int get cappedPenalty => math.min(120, rawPenalty);
  WeekReview withApplied(int amount) => WeekReview(
    monday: monday,
    today: today,
    targets: targets,
    days: days,
    appliedPenalty: amount,
  );
}

class WeeklyLedger {
  final int earnedXp, deductedXp;
  final List<WeekReview> closedWeeks;
  const WeeklyLedger(this.earnedXp, this.deductedXp, this.closedWeeks);
  int get netXp => math.max(0, earnedXp - deductedXp);
}

WeeklyLedger calculateWeeklyXp({
  required DateTime today,
  DateTime? start,
  required Map<String, WeekTargets> targets,
  required Map<String, DayFuel> days,
  required Map<String, int> earnedByDay,
}) {
  final current = weekDay(today),
      key = weekKey(current),
      earnings =
          earnedByDay.entries.where((e) => e.key.compareTo(key) <= 0).toList()
            ..sort((a, b) => a.key.compareTo(b.key));
  final total = earnings.fold<int>(0, (n, e) => n + e.value);
  if (start == null || targets.isEmpty) return WeeklyLedger(total, 0, []);
  final plans = targets.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  var monday = weekMonday(start),
      planIndex = 0,
      incomeIndex = 0,
      available = 0,
      deducted = 0;
  final reviews = <WeekReview>[];
  while (!monday.add(const Duration(days: 7)).isAfter(current) &&
      reviews.length < 5200) {
    final mondayKey = weekKey(monday);
    while (planIndex + 1 < plans.length &&
        plans[planIndex + 1].key.compareTo(mondayKey) <= 0) {
      planIndex++;
    }
    if (plans[planIndex].key.compareTo(mondayKey) > 0) {
      monday = monday.add(const Duration(days: 7));
      continue;
    }
    final end = weekKey(monday.add(const Duration(days: 6)));
    while (incomeIndex < earnings.length &&
        earnings[incomeIndex].key.compareTo(end) <= 0) {
      available += earnings[incomeIndex].value;
      incomeIndex++;
    }
    final chosen = plans[planIndex];
    final review = WeekReview(
      monday: monday,
      today: current,
      targets: chosen.key == mondayKey
          ? chosen.value
          : chosen.value.withRecovery(false),
      days: days,
    );
    // The zero floor is applied at each week end: no debt is borrowed from future XP.
    final loss = math.min(available, review.cappedPenalty);
    available -= loss;
    deducted += loss;
    reviews.add(review.withApplied(loss));
    monday = monday.add(const Duration(days: 7));
  }
  return WeeklyLedger(total, deducted, List.unmodifiable(reviews));
}
