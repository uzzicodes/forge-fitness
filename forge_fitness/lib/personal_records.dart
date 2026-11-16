import 'package:flutter/material.dart';
import 'models.dart';
import 'training.dart';
import 'exercise_records.dart';
import 'main.dart' show box, gap, small, lime, muted, line;

class PersonalRecordCard extends StatelessWidget {
  final Exercise exercise;
  final AppStore store;
  final DateTime date;
  const PersonalRecordCard({
    super.key,
    required this.exercise,
    required this.store,
    required this.date,
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => recordContent(context),
  );
  Widget recordContent(BuildContext context) {
    final r = exerciseRecords(store.sessions, exercise, date),
        best = r.best,
        added = r.addedBest,
        previous = r.previousSets;
    return Semantics(
      button: true,
      label: 'Personal records for ${exercise.name}',
      child: Material(
        color: lime.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showPersonalRecord(context, r),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      color: lime,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        best == null
                            ? r.bodyweight
                                  ? 'PR · No bodyweight record yet'
                                  : 'PR · No load record yet'
                            : 'PR · ${best.describe(exercise)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: lime,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: muted, size: 18),
                  ],
                ),
                if (added != null) ...[
                  gap(5),
                  Text(
                    'Added-load PR · ${added.describe(exercise)}',
                    style: const TextStyle(fontSize: 12, color: lime),
                  ),
                ],
                if (r.newPr || r.newAddedPr) ...[
                  gap(5),
                  const Text(
                    'NEW PR THIS SESSION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: lime,
                      letterSpacing: .6,
                    ),
                  ),
                ],
                gap(5),
                small(
                  previous.isEmpty
                      ? 'Previous · No earlier completed sets'
                      : 'Previous · ${prettyDay(DateTime.parse(previous.first.date))} · ${_previousSummary(r)}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _previousSummary(ExerciseRecordSummary r) {
  final previous = r.previousSets;
  final representative =
      r.strongest(previous) ??
      r.strongest(previous, addedLoad: true) ??
      previous.first;
  return '${representative.describe(r.exercise)}${previous.length > 1 ? ' · ${previous.length} sets saved' : ''}';
}

Future<void> showPersonalRecord(
  BuildContext context,
  ExerciseRecordSummary r,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (ctx) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(ctx).height * .78,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.exercise.name,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close personal records',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            gap(8),
            Text(
              r.metric,
              style: const TextStyle(color: lime, fontWeight: FontWeight.w700),
            ),
            gap(7),
            Text(
              r.best?.describe(r.exercise) ?? 'No completed record yet',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            if (r.best != null)
              small('Recorded ${prettyDay(DateTime.parse(r.best!.date))}'),
            if (r.addedBest != null) ...[
              gap(16),
              const Text(
                'Added-load PR',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(r.addedBest!.describe(r.exercise)),
              small('Recorded ${prettyDay(DateTime.parse(r.addedBest!.date))}'),
            ],
            gap(20),
            PrTrendChart(records: r),
            gap(18),
            small(
              'Only checked, completed sets count. The workout can still be in progress. Reopening, correcting or deleting a set recalculates its PR. Historical days show records up to that date; future logs never count.',
            ),
            gap(10),
            small(
              r.assisted
                  ? 'Lower assistance is this record’s goal; the value is assistance, not weight lifted. Ties use more reps.'
                  : r.bodyweight
                  ? 'Bodyweight repetitions or hold time and added-load records stay separate. Added kg means external weight, not your body mass.'
                  : 'This is your heaviest recorded set, not a tested or estimated one-rep maximum. At the same load, more reps breaks the tie.',
            ),
            gap(10),
            small(
              'Compare the same exercise, machine and setup. Different machine stacks are not interchangeable. Barbell kg is the total; dumbbell kg is one dumbbell. Keep that convention consistent. You do not need to attempt a max or chase a PR every workout.',
            ),
            gap(22),
            const Text(
              'Recent completed sets',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            gap(10),
            if (r.sets.isEmpty)
              small(
                'Save a set after doing it to start your record. To add an older session, select its actual date on Train and log the sets you completed.',
              ),
            for (final date
                in r.sets
                    .map((s) => s.date)
                    .toSet()
                    .toList()
                    .reversed
                    .take(6)) ...[
              Text(
                prettyDay(DateTime.parse(date)),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              gap(4),
              for (final s in r.sets.where((s) => s.date == date))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Set ${s.index + 1} · ${s.describe(r.exercise)}',
                    style: const TextStyle(color: muted),
                  ),
                ),
              gap(12),
            ],
          ],
        ),
      ),
    ),
  ),
);

class PersonalRecordsScreen extends StatelessWidget {
  final AppStore store;
  const PersonalRecordsScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Personal records')),
    body: AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final today = calendarDay(DateTime.now()),
            records = library
                .map((e) => exerciseRecords(store.sessions, e, today))
                .where((r) => r.sets.isNotEmpty)
                .toList();
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            small(
              'Your records come from saved sets. They stay separate for each exercise and update when you correct a log. Tap a record for the sets and dates.',
            ),
            gap(18),
            if (records.isEmpty)
              box(
                const Text(
                  'Your first record starts with a completed set. You can also select a previous date on Train and log an older session.',
                ),
              ),
            for (final r in records) ...[
              Text(
                r.exercise.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              gap(8),
              PersonalRecordCard(
                exercise: r.exercise,
                store: store,
                date: today,
              ),
              gap(20),
            ],
          ],
        );
      },
    ),
  );
}

/// Per-exercise trend of each day's best completed set. Drawn with a
/// CustomPainter so it adds no package and works offline in the PWA.
class PrTrendChart extends StatelessWidget {
  final ExerciseRecordSummary records;
  const PrTrendChart({super.key, required this.records});
  @override
  Widget build(BuildContext context) {
    final points = records.trend();
    if (points.length < 2) {
      return small(
        'Trend · appears after two training days with a completed set for this exercise.',
      );
    }
    final first = points.first, last = points.last;
    final change = last.value - first.value;
    final better = records.assisted ? change < 0 : change > 0;
    final unit = records.trendUnit;
    String fmt(double v) => recordNumber(v);
    final summary = change == 0
        ? 'No change over ${points.length} sessions'
        : '${change > 0 ? '+' : '−'}${fmt(change.abs())} ${records.bodyweight ? unit : 'kg'} over ${points.length} sessions';
    return Semantics(
      label:
          'Trend for ${records.exercise.name}: from ${fmt(first.value)} to ${fmt(last.value)} $unit across ${points.length} sessions.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Trend',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                summary,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: change == 0 || !better ? muted : lime,
                ),
              ),
            ],
          ),
          gap(4),
          small('Best set each training day · $unit'),
          gap(10),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendPainter(
                points.map((p) => p.value).toList(),
                lowerIsBetter: records.assisted,
              ),
            ),
          ),
          gap(6),
          Row(
            children: [
              small(prettyDay(DateTime.parse(first.date))),
              const Spacer(),
              small(prettyDay(DateTime.parse(last.date))),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  final bool lowerIsBetter;
  _TrendPainter(this.values, {required this.lowerIsBetter});
  @override
  void paint(Canvas canvas, Size size) {
    const labelWidth = 34.0, padY = 10.0;
    final chartW = size.width - labelWidth, chartH = size.height - padY * 2;
    var lo = values.reduce((a, b) => a < b ? a : b),
        hi = values.reduce((a, b) => a > b ? a : b);
    if (hi == lo) {
      hi += 1;
      lo = lo - 1 < 0 ? 0.0 : lo - 1;
    }
    double y(double v) => padY + chartH * (1 - (v - lo) / (hi - lo));
    double x(int i) =>
        labelWidth + (values.length == 1 ? 0 : chartW * i / (values.length - 1));
    final grid = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (final v in [lo, hi]) {
      canvas.drawLine(Offset(labelWidth, y(v)), Offset(size.width, y(v)), grid);
      final tp = TextPainter(
        text: TextSpan(
          text: recordNumber(v),
          style: const TextStyle(fontSize: 10, color: muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: labelWidth - 4);
      tp.paint(canvas, Offset(0, y(v) - tp.height / 2));
    }
    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = lime;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(x(i), y(values[i])), i == values.length - 1 ? 4.5 : 3, dot);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.lowerIsBetter != lowerIsBetter || !_same(old.values, values);
  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
