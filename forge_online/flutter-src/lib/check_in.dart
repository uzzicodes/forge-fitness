import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';
import 'weekly_review.dart';
import 'main.dart' show box, gap, small, lime, orange, muted, line;

class DailyCheckInCard extends StatelessWidget {
  final AppStore store;
  final DateTime date;
  const DailyCheckInCard({super.key, required this.store, required this.date});
  @override
  Widget build(BuildContext context) {
    final d = store.fuelByDay[dayKey(date)] ?? DayFuel(),
        t = store.currentWeekTargets;
    final met = [
      d.proteinMet(t),
      d.caloriesMet(t),
      d.waterMet(t),
    ].where((x) => x).length;
    return box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How am I doing?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          gap(8),
          Text(
            '${d.meals} meal${d.meals == 1 ? '' : 's'} logged · $met / 3 fuel targets in range',
            style: const TextStyle(color: lime),
          ),
          gap(8),
          small(_nextSteps(store, date, d, t).first),
          gap(12),
          FilledButton.tonalIcon(
            onPressed: () => openCheckIn(context, store, date),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('Daily check-in & weekly XP'),
          ),
        ],
      ),
    );
  }
}

List<String> _nextSteps(AppStore s, DateTime date, DayFuel d, WeekTargets t) {
  final tips = <String>[];
  final past = weekDay(date).isBefore(s.xpToday());
  if (past) {
    return [
      'This day is finished. Add or correct any missing entries for the date they actually happened.',
      d.allMet(t)
          ? 'All three fuel targets were logged in range.'
          : 'The meters show gaps in that day’s saved entries. Use this review to plan future days; do not try to make up old food or water totals today.',
    ];
  }
  if (d.meals == 0) {
    tips.add(
      'No meals are logged yet. Start by recording what you already ate; meal count itself is not a nutrition target.',
    );
  }
  if (!d.proteinMet(t)) {
    final left = math.max(0, t.protein - d.protein).ceil();
    tips.add(
      d.calories >= t.calories
          ? 'Protein is about $left g short. Prioritise a lean protein source in your next planned meal; review portions and missing logs first.'
          : 'About $left g protein remains. Eggs, chicken, dal/chana or plain dahi can help with your next meal.',
    );
  }
  if (d.calories < t.calories * .9) {
    tips.add(
      'About ${math.max(0, t.calories - d.calories).ceil()} kcal remains to your calorie target. Plan a balanced meal or snack that fits your goal.',
    );
  }
  if (d.calories > t.calories * 1.1) {
    tips.add(
      'Logged calories are above the target range. Check portion sizes, oil and duplicate entries. Continue with your usual balanced routine; extra exercise is not a penalty.',
    );
  }
  if (!d.waterMet(t)) {
    tips.add(
      'About ${math.max(0, t.waterMl - d.waterMl).ceil()} ml remains to your saved water goal. Spread drinks across the day instead of trying to catch up all at once.',
    );
  }
  if (d.allMet(t)) {
    tips.add(
      'All three fuel targets are logged in range. Keep your normal routine and recovery; extra food or water earns no extra XP.',
    );
  }
  return tips;
}

Future<void> openCheckIn(BuildContext context, AppStore store, DateTime date) =>
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CheckInScreen(store: store, date: date),
      ),
    );

class CheckInScreen extends StatefulWidget {
  final AppStore store;
  final DateTime date;
  const CheckInScreen({super.key, required this.store, required this.date});
  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  late DateTime selected;
  bool changing = false;
  @override
  void initState() {
    super.initState();
    selected = weekDay(widget.date);
  }

  String short(DateTime d) => '${d.day} ${months[d.month - 1]}';
  Widget meter(String label, String detail, double fraction, bool met) =>
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(detail, style: TextStyle(color: met ? lime : orange)),
              ],
            ),
            gap(7),
            LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 7,
              color: met ? lime : orange,
              backgroundColor: line,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your check-in')),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final s = widget.store,
            today = s.xpToday(),
            t = selected.isBefore(today)
                ? s.targetsForWeek(selected)
                : s.currentWeekTargets,
            day = s.fuelByDay[weekKey(selected)] ?? DayFuel(),
            ledger = s.xpLedger(),
            week = s.weekReview(selected),
            start = s.weeklyXpStart;
        final active = start != null && !week.monday.isBefore(weekDay(start));
        WeekReview? settled;
        for (final r in ledger.closedWeeks) {
          if (weekKey(r.monday) == weekKey(week.monday)) settled = r;
        }
        final recoveryWeek =
                start != null && weekMonday(today).isBefore(weekDay(start))
                ? weekDay(start)
                : weekMonday(today),
            recovery = s.targetsForWeek(recoveryWeek).recovery;
        final offset =
            s.accountPreferences['weeklyXpOffsetMinutes'] as int? ??
            DateTime.now().timeZoneOffset.inMinutes;
        final zone =
            'UTC${offset >= 0 ? '+' : '−'}${(offset.abs() ~/ 60).toString().padLeft(2, '0')}:${(offset.abs() % 60).toString().padLeft(2, '0')}';
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous check-in day',
                        onPressed: () => setState(
                          () => selected = selected.subtract(
                            const Duration(days: 1),
                          ),
                        ),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          prettyDay(selected),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next check-in day',
                        onPressed: selected.isBefore(today)
                            ? () => setState(
                                () => selected = selected.add(
                                  const Duration(days: 1),
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  gap(12),
                  box(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${day.meals} meal${day.meals == 1 ? '' : 's'} logged',
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        gap(6),
                        small(
                          'Progress from your saved entries. Nutrition and water targets are personal; meal count is information, not a minimum to earn points.',
                        ),
                        meter(
                          'Protein',
                          '${day.protein.toStringAsFixed(1)} / ${t.protein} g',
                          day.protein / t.protein,
                          day.proteinMet(t),
                        ),
                        meter(
                          'Calories',
                          '${day.calories.round()} / ${t.calories} kcal',
                          day.calories / t.calories,
                          day.caloriesMet(t),
                        ),
                        meter(
                          'Water',
                          '${day.waterMl.round()} / ${t.waterMl} ml',
                          day.waterMl / t.waterMl,
                          day.waterMet(t),
                        ),
                        gap(12),
                        small(
                          'Calorie range: ${(t.calories * .9).round()}–${(t.calories * 1.1).round()} kcal (±10%). Protein and water use your full saved targets. ${t.waterMl == 2000 ? '2,000 ml is eight 250 ml glasses; your water target can be edited.' : ''}',
                        ),
                      ],
                    ),
                  ),
                  gap(18),
                  const Text(
                    'Your next steps',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  gap(12),
                  box(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final tip in _nextSteps(s, selected, day, t))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: lime,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(tip)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  gap(24),
                  const Text(
                    'Weekly scorecard',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  gap(10),
                  box(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${short(week.monday)} – ${short(week.nextMonday.subtract(const Duration(days: 1)))}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        gap(8),
                        Text(
                          '${week.workouts} / ${week.targets.trainingDays} workouts completed',
                          style: const TextStyle(
                            color: lime,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        gap(8),
                        small(
                          'Any Monday–Sunday workout counts, including a Saturday or Sunday make-up session. Daily rest choices do not deduct training XP. At most one completed workout per date counts.',
                        ),
                        gap(14),
                        Row(
                          children: [
                            for (var i = 0; i < 7; i++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Builder(
                                    builder: (context) {
                                      final date = week.monday.add(
                                            Duration(days: i),
                                          ),
                                          d = week.day(date),
                                          future = date.isAfter(today),
                                          color = future
                                              ? muted
                                              : d.allMet(week.targets)
                                              ? lime
                                              : d.hasLogs
                                              ? orange
                                              : muted;
                                      return Semantics(
                                        label:
                                            '${weekdays[i]} ${d.trained ? 'workout completed' : 'no completed workout'}, ${d.allMet(week.targets)
                                                ? 'fuel targets met'
                                                : future
                                                ? 'upcoming'
                                                : 'fuel targets incomplete'}',
                                        button: true,
                                        child: InkWell(
                                          onTap: () => setState(
                                            () => selected = date.isAfter(today)
                                                ? today
                                                : date,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: .1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color:
                                                    weekKey(date) ==
                                                        weekKey(selected)
                                                    ? lime
                                                    : color.withValues(
                                                        alpha: .25,
                                                      ),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  weekdays[i].substring(0, 1),
                                                  style: TextStyle(
                                                    color: color,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                gap(6),
                                                Icon(
                                                  d.trained
                                                      ? Icons.fitness_center
                                                      : d.allMet(week.targets)
                                                      ? Icons
                                                            .check_circle_outline
                                                      : Icons.circle_outlined,
                                                  size: 18,
                                                  color: color,
                                                ),
                                                gap(5),
                                                small('${date.day}'),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                        gap(14),
                        if (!active)
                          Text(
                            'Practice week. Deductions start with your first full week on ${start == null ? 'the Monday after setup' : short(start)}. Earlier history keeps its earned XP.',
                            style: const TextStyle(color: lime),
                          )
                        else if (week.targets.recovery)
                          const Text(
                            'Recovery week: weekly deductions are paused.',
                            style: TextStyle(color: lime),
                          )
                        else if (!week.closed)
                          Text(
                            'Week in progress: no XP deducted yet. Training is assessed only after Sunday ends. ${week.proteinGaps + week.calorieGaps + week.waterGaps} completed-day fuel gaps are currently recorded.',
                            style: const TextStyle(color: orange),
                          )
                        else
                          Text(
                            'Week closed · −${settled?.appliedPenalty ?? 0} XP applied',
                            style: const TextStyle(
                              color: orange,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        gap(10),
                        small(
                          'This week’s XP targets: ${week.targets.trainingDays} sessions · ${week.targets.protein} g protein/day · ${week.targets.calories} kcal/day ±10% · ${week.targets.waterMl} ml water/day. These targets are saved for the week. Target edits apply to the next week’s score. Today’s check-in uses your current profile; past check-ins use the saved weekly targets.',
                        ),
                        if (active &&
                            week.closed &&
                            !week.targets.recovery) ...[
                          gap(14),
                          Text(
                            'Missed sessions: ${week.missedWorkouts} × 25 XP\nProtein gaps: ${week.proteinGaps} days × 5 XP\nCalorie-range gaps: ${week.calorieGaps} days × 5 XP\nWater gaps: ${week.waterGaps} days × 3 XP',
                          ),
                          gap(8),
                          small(
                            'Raw deduction ${week.rawPenalty}; weekly cap 120; applied ${settled?.appliedPenalty ?? 0}. The balance stops at zero and never borrows future XP.',
                          ),
                        ],
                      ],
                    ),
                  ),
                  gap(18),
                  box(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your XP balance',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        gap(10),
                        Text(
                          '${ledger.netXp} rank XP',
                          style: const TextStyle(
                            color: lime,
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        small(
                          '${ledger.earnedXp} earned · ${ledger.deductedXp} weekly deductions',
                        ),
                        gap(10),
                        small(
                          'Weeks close after Sunday in your saved $zone clock. Reloading does not deduct again. Corrections to past logs recalculate that week and can restore XP. Unlogged days count as incomplete; the app cannot know what you did without an entry.',
                        ),
                      ],
                    ),
                  ),
                  gap(18),
                  if (weekKey(week.monday) == weekKey(weekMonday(today)) &&
                      s.profile != null)
                    box(
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: recovery,
                        onChanged: changing
                            ? null
                            : (v) async {
                                setState(() => changing = true);
                                try {
                                  await s.setRecoveryWeek(v == true);
                                } finally {
                                  if (mounted) setState(() => changing = false);
                                }
                              },
                        title: const Text(
                          'Recovery week',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          'Illness, injury or travel · pauses deductions for the open week beginning ${short(recoveryWeek)}. Closed weeks stay in the history.',
                        ),
                      ),
                    ),
                  if (ledger.closedWeeks.isNotEmpty) ...[
                    gap(20),
                    const Text(
                      'Recent completed weeks',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    gap(12),
                    for (final r in ledger.closedWeeks.reversed.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: box(
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${short(r.monday)} · ${r.workouts}/${r.targets.trainingDays} workouts',
                                    ),
                                    small(
                                      r.targets.recovery
                                          ? 'Recovery week'
                                          : r.rawPenalty == 0
                                          ? 'All weekly targets logged'
                                          : '${r.proteinGaps} protein · ${r.calorieGaps} calorie · ${r.waterGaps} water gaps',
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '−${r.appliedPenalty} XP',
                                style: TextStyle(
                                  color: r.appliedPenalty > 0 ? orange : lime,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  gap(16),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Weekly XP rules'),
                    children: [
                      small(
                        'Existing rewards remain: +60 per completed workout; +10 per meal-logging day; +10 per water-logging day; +5 per chosen recovery day; +10 per completed habit/day. Extra food or water gives no extra points.\n\nAfter a complete scored week: −25 per missed planned session, −5 per day below protein, −5 per day outside the calorie range, and −3 per day below the saved water goal. Maximum loss is 120 XP per week, limited by XP available at that week’s close. Ranks can move down; XP cannot become negative. New scoring starts next Monday, never retroactively. Recovery status applies only to the chosen open week, not indefinitely.',
                      ),
                      gap(12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
