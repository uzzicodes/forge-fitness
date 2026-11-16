import 'training.dart';

String recordDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String recordNumber(num n) => n.toDouble() == n.roundToDouble()
    ? n.toInt().toString()
    : n
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

class RecordedSet {
  final String date;
  final int index, reps;
  final double kg;
  const RecordedSet(this.date, this.index, this.reps, this.kg);
  String describe(Exercise exercise) {
    final amount = '$reps ${exercise.reps.contains('sec') ? 'sec' : 'reps'}';
    if (exercise.id == 'assistedpullup') {
      return '${recordNumber(kg)} kg assistance × $amount';
    }
    if (exercise.equipment == 'Bodyweight' || exercise.reps.contains('sec')) {
      return kg == 0
          ? '$amount · bodyweight'
          : '+${recordNumber(kg)} kg × $amount';
    }
    return '${recordNumber(kg)} kg × $amount';
  }
}

class TrendPoint {
  final String date;
  final double value;
  final RecordedSet set;
  const TrendPoint(this.date, this.value, this.set);
}

class ExerciseRecordSummary {
  final Exercise exercise;
  final String selectedDate;
  final List<RecordedSet> sets;
  const ExerciseRecordSummary(this.exercise, this.selectedDate, this.sets);
  bool get assisted => exercise.id == 'assistedpullup';
  bool get bodyweight =>
      exercise.equipment == 'Bodyweight' || exercise.reps.contains('sec');
  bool get timed => exercise.reps.contains('sec');
  String get metric => assisted
      ? 'Least assistance'
      : bodyweight
      ? (timed ? 'Longest bodyweight hold' : 'Most bodyweight reps')
      : 'Heaviest recorded load';
  List<RecordedSet> get previousSets {
    final earlier = sets
        .where((s) => s.date.compareTo(selectedDate) < 0)
        .toList();
    if (earlier.isEmpty) return [];
    final date = earlier.last.date;
    return earlier.where((s) => s.date == date).toList();
  }

  RecordedSet? strongest(Iterable<RecordedSet> rows, {bool addedLoad = false}) {
    RecordedSet? best;
    for (final s in rows) {
      if (addedLoad
          ? (!bodyweight || s.kg <= 0)
          : bodyweight
          ? s.kg != 0
          : !assisted && s.kg <= 0) {
        continue;
      }
      if (best == null || compare(s, best, addedLoad: addedLoad) > 0) best = s;
    }
    return best;
  }

  int compare(RecordedSet a, RecordedSet b, {bool addedLoad = false}) {
    final load = assisted
        ? b.kg.compareTo(a.kg)
        : bodyweight && !addedLoad
        ? 0
        : a.kg.compareTo(b.kg);
    return load != 0 ? load : a.reps.compareTo(b.reps);
  }

  RecordedSet? get best => strongest(sets);
  RecordedSet? get addedBest => strongest(sets, addedLoad: true);
  RecordedSet? get previousBest =>
      strongest(sets.where((s) => s.date.compareTo(selectedDate) < 0));
  bool get newPr {
    final current = strongest(sets.where((s) => s.date == selectedDate)),
        prior = previousBest;
    return current != null && (prior == null || compare(current, prior) > 0);
  }

  /// One point per training day: that day's best set under the same rule the
  /// PR uses (load, reps/hold, or assistance). Oldest first, most recent
  /// [limit] days. Read-only view of the same completed-set rows as the PR.
  List<TrendPoint> trend({int limit = 12}) {
    final points = <TrendPoint>[];
    for (final date in sets.map((s) => s.date).toSet()) {
      final top = strongest(sets.where((s) => s.date == date));
      if (top == null) continue;
      points.add(
        TrendPoint(
          date,
          bodyweight ? top.reps.toDouble() : top.kg,
          top,
        ),
      );
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points.length > limit
        ? points.sublist(points.length - limit)
        : points;
  }

  /// Axis label for [trend] values.
  String get trendUnit => assisted
      ? 'kg assistance (lower is better)'
      : bodyweight
      ? (timed ? 'seconds' : 'reps')
      : 'kg';

  bool get newAddedPr {
    final current = strongest(
          sets.where((s) => s.date == selectedDate),
          addedLoad: true,
        ),
        prior = strongest(
          sets.where((s) => s.date.compareTo(selectedDate) < 0),
          addedLoad: true,
        );
    return current != null &&
        (prior == null || compare(current, prior, addedLoad: true) > 0);
  }
}

/// Records derive from completed set logs, including sets saved before a swap.
/// No extra PR ledger can get out of sync with edits, deletions or cloud merges.
ExerciseRecordSummary exerciseRecords(
  Map<String, dynamic> sessions,
  Exercise exercise,
  DateTime date, {
  DateTime? now,
}) {
  final selected = recordDate(date),
      today = recordDate(now ?? DateTime.now()),
      cutoff = selected.compareTo(today) < 0 ? selected : today,
      rows = <RecordedSet>[];
  final key = RegExp('^${RegExp.escape(exercise.id)}-([0-9]+)\$');
  for (final session in sessions.entries) {
    final parsed = DateTime.tryParse(session.key);
    if (parsed == null ||
        recordDate(parsed) != session.key ||
        session.key.compareTo(cutoff) > 0 ||
        session.value is! Map) {
      continue;
    }
    final sets = (session.value as Map)['sets'];
    if (sets is! Map) continue;
    for (final entry in sets.entries) {
      final match = key.firstMatch(entry.key.toString()), s = entry.value;
      if (match == null ||
          s is! Map ||
          s['checked'] != true ||
          s['reps'] is! int ||
          (s['reps'] as int) < 1 ||
          (s['reps'] as int) > 600 ||
          s['kg'] is! num ||
          !(s['kg'] as num).isFinite ||
          (s['kg'] as num) < 0 ||
          (s['kg'] as num) > 600) {
        continue;
      }
      final index = int.tryParse(match.group(1)!);
      if (index == null) {
        continue;
      }
      rows.add(
        RecordedSet(
          session.key,
          index,
          s['reps'] as int,
          (s['kg'] as num).toDouble(),
        ),
      );
    }
  }
  rows.sort((a, b) {
    final d = a.date.compareTo(b.date);
    return d != 0 ? d : a.index.compareTo(b.index);
  });
  return ExerciseRecordSummary(exercise, selected, List.unmodifiable(rows));
}
