import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'training.dart';
import 'exercise_media.dart';
import 'rank_card.dart';
import 'personal_records.dart';
import 'main.dart'
    show
        lime,
        ink,
        muted,
        orange,
        gap,
        small,
        tag,
        box,
        heading,
        toast,
        showSheet;

class WorkoutScreen extends StatefulWidget {
  final AppStore store;
  final DateTime date;
  const WorkoutScreen({super.key, required this.store, required this.date});
  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late Workout workout;
  late Map<String, dynamic> session;
  Timer? timer;
  DateTime? restUntil;
  int seconds = 0;
  bool get future =>
      calendarDay(widget.date).isAfter(calendarDay(DateTime.now()));
  Map<String, dynamic> get sets => session['sets'] as Map<String, dynamic>;
  bool get done => session['done'] == true;
  int targetFor(Exercise exercise) => sessionTarget(session, exercise.id);
  int get totalSets => sessionTotalSets(session);
  int get completed =>
      retiredSetCount(session) +
      workout.exercises.fold<int>(0, (n, e) => n + checkedSets(session, e.id));

  Future<void> changeExercise(Exercise exercise) async {
    final retired = List<String>.from(
      session['retiredExerciseIds'] as List? ?? [],
    );
    final options = exerciseAlternatives(
      exercise.id,
      widget.store.profile!.equipment,
      [...workout.exercises.map((e) => e.id), ...retired],
    );
    final remaining = targetFor(exercise) - checkedSets(session, exercise.id);
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .75,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Swap ${exercise.name}',
                  style: Theme.of(ctx).textTheme.headlineSmall,
                ),
                gap(8),
                small(
                  'Same training purpose · ${exercise.muscle}. Choose a comfortable alternative, start light and use its own rep range. Loads are not interchangeable between machines or exercises.',
                ),
                gap(8),
                small(
                  '$remaining set(s) remaining. Completed sets stay in your history; only remaining sets move to the replacement.',
                ),
                gap(8),
                if (options.isEmpty)
                  const Text(
                    'No matching alternative for your equipment. Move this exercise to the end and return when the station is free.',
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final e in options)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(e.name),
                          subtitle: Text('${e.equipment} · ${e.reps} reps'),
                          trailing: const Icon(Icons.swap_horiz),
                          onTap: remaining > 0
                              ? () => Navigator.pop(ctx, e.id)
                              : null,
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'move-to-end'),
                  icon: const Icon(Icons.vertical_align_bottom),
                  label: const Text('Move this exercise to the end'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Keep current exercise'),
                ),
                gap(8),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    if (selected == 'move-to-end') {
      final ids = List<String>.from(session['exerciseIds'] as List)
        ..remove(exercise.id)
        ..add(exercise.id);
      session = {...session, 'exerciseIds': ids};
    } else {
      session = swapSessionExercise(
        session,
        exercise.id,
        selected,
        widget.store.profile!.equipment,
      );
    }
    timer?.cancel();
    setState(() {
      seconds = 0;
      workout = Workout(
        workout.name,
        workout.focus,
        (session['exerciseIds'] as List).map((id) => ex(id as String)).toList(),
        workout.sets,
        workout.rotationIndex,
      );
    });
    widget.store.sessions[dayKey(widget.date)] = session;
    await widget.store.save();
    if (mounted) {
      toast(
        context,
        selected == 'move-to-end'
            ? 'Moved to the end. Saved sets stay recorded.'
            : 'Exercise swapped. Start with a light practice set.',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    workout = widget.store.workoutOn(widget.date);
    final existing = widget.store.sessions[dayKey(widget.date)];
    if (existing is Map) {
      session = Map<String, dynamic>.from(existing);
      session['sets'] = Map<String, dynamic>.from(existing['sets'] as Map);
      if (existing['exerciseIds'] is List) {
        workout = Workout(
          existing['name'] as String,
          'Your saved workout',
          (existing['exerciseIds'] as List)
              .map((id) => ex(id as String))
              .toList(),
          existing['plannedSets'] as int,
          existing['rotationIndex'] as int?,
        );
      }
    } else {
      session = {
        'done': false,
        'name': workout.name,
        'sets': <String, dynamic>{},
        'exerciseIds': workout.exercises.map((e) => e.id).toList(),
        'plannedSets': workout.sets,
        'rotationIndex': workout.rotationIndex,
        'rotationSize': widget.store.profile!.days,
      };
    }
    session.putIfAbsent(
      'exerciseIds',
      () => workout.exercises.map((e) => e.id).toList(),
    );
    session.putIfAbsent('plannedSets', () => workout.sets);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void startRest(int duration) {
    timer?.cancel();
    restUntil = DateTime.now().add(Duration(seconds: duration));
    setState(() => seconds = duration);
    timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final remaining = restUntil!.difference(DateTime.now()).inMilliseconds;
      setState(() => seconds = math.max(0, (remaining / 1000).ceil()));
      if (remaining <= 0) {
        timer?.cancel();
        HapticFeedback.mediumImpact();
      }
    });
  }

  Future<void> saveSet(
    String key,
    int reps,
    double kg,
    bool checked,
    int rest,
  ) async {
    setState(() {
      sets[key] = {'reps': reps, 'kg': kg, 'checked': checked};
      if (!checked) session['done'] = false;
    });
    widget.store.sessions[dayKey(widget.date)] = session;
    await widget.store.save();
    if (checked && mounted) startRest(rest);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your training'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: tag(
              future
                  ? 'PREVIEW'
                  : done
                  ? 'COMPLETE'
                  : 'LET’S MOVE',
            ),
          ),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            small(prettyDay(widget.date).toUpperCase()),
            gap(10),
            Text(
              workout.name,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            gap(8),
            Text(workout.focus, style: const TextStyle(color: muted)),
            gap(24),
            if (future) ...[
              box(
                const Text(
                  'This is a future plan. Come back on the day to log your sets.',
                  style: TextStyle(color: orange),
                ),
              ),
              gap(),
            ],
            if (workout.rest) ...[
              box(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.spa_outlined, color: lime, size: 44),
                    gap(20),
                    const Text(
                      'Let your work sink in.',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    gap(12),
                    const Text(
                      'Walk, cycle or move at an easy conversational pace for 20–30 minutes. Start with less if needed. Add a few gentle mobility movements for your hips, upper back and shoulders.',
                      style: TextStyle(color: muted),
                    ),
                    gap(20),
                    tag('EASY EFFORT · NO RUSH'),
                  ],
                ),
              ),
              heading('Recovery checklist'),
              const ListTile(
                leading: Icon(Icons.bedtime_outlined, color: orange),
                title: Text('Make room for sleep'),
                subtitle: Text('Aim for a regular sleep schedule.'),
              ),
              const ListTile(
                leading: Icon(Icons.restaurant_outlined, color: orange),
                title: Text('Fuel even on rest days'),
                subtitle: Text(
                  'Your body is still recovering. Keep your protein consistent.',
                ),
              ),
              const ListTile(
                leading: Icon(Icons.directions_walk_outlined, color: orange),
                title: Text('Build endurance gradually'),
                subtitle: Text(
                  'Add short, easy cardio sessions at a pace you can sustain.',
                ),
              ),
            ] else ...[
              box(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: small('SESSION PROGRESS')),
                        Text(
                          '$completed / $totalSets sets',
                          style: const TextStyle(
                            color: lime,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    gap(12),
                    LinearProgressIndicator(
                      value: completed / (totalSets),
                      backgroundColor: ink,
                      color: lime,
                      borderRadius: BorderRadius.circular(10),
                      minHeight: 7,
                    ),
                    gap(14),
                    small(
                      'Warm up for 5–10 min, then do lighter practice sets. Tap each checkmark to save the reps and weight you actually did. Timed holds use seconds.',
                    ),
                  ],
                ),
              ),
              gap(20),
              ...workout.exercises.asMap().entries.map((entry) {
                final e = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: box(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            tag((entry.key + 1).toString().padLeft(2, '0')),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  small(e.muscle),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Form preview',
                              onPressed: () => showSheet(
                                context,
                                ExerciseGuide(exercise: e),
                              ),
                              icon: const Icon(
                                Icons.play_circle_outline,
                                color: lime,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                        gap(18),
                        PersonalRecordCard(
                          exercise: e,
                          store: widget.store,
                          date: widget.date,
                        ),
                        gap(12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            tag('${targetFor(e)} SETS', color: muted),
                            tag(
                              '${e.reps} ${e.reps.contains('sec') ? '' : 'REPS'}',
                              color: muted,
                            ),
                            tag('${e.rest}s REST', color: muted),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: future || done
                                ? null
                                : () => changeExercise(e),
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: Text('Swap / move ${e.name}'),
                          ),
                        ),
                        if (e.id == 'assistedpullup')
                          small(
                            'Record assistance kg. More assistance makes this machine easier; reduce assistance as you get stronger.',
                          ),
                        gap(8),
                        ...List.generate(
                          targetFor(e),
                          (i) => SetRow(
                            key: ValueKey('${e.id}-$i'),
                            index: i,
                            initial: sets['${e.id}-$i'] as Map?,
                            timed: e.reps.contains('sec'),
                            bodyweight: e.equipment == 'Bodyweight',
                            assistance: e.id == 'assistedpullup',
                            suggestedReps: int.parse(
                              RegExp(r'\d+').firstMatch(e.reps)!.group(0)!,
                            ),
                            disabled: future,
                            onSave: (r, k, c) =>
                                saveSet('${e.id}-$i', r, k, c, e.rest),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if ((session['retiredExerciseIds'] as List? ?? []).isNotEmpty)
                box(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Completed before swapping',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      gap(8),
                      for (final id
                          in session['retiredExerciseIds'] as List) ...[
                        Text(ex(id as String).name),
                        for (final entry in sets.entries.where(
                          (e) =>
                              e.key.startsWith('$id-') &&
                              (e.value as Map)['checked'] == true,
                        ))
                          small(
                            '${(entry.value as Map)['reps']} ${ex(id).reps.contains('sec') ? 'sec' : 'reps'} · ${(entry.value as Map)['kg']} kg',
                          ),
                        gap(8),
                      ],
                    ],
                  ),
                ),
              gap(8),
              FilledButton.icon(
                onPressed: future
                    ? null
                    : () async {
                        final beforeXp = widget.store.totalXp;
                        if (done) {
                          setState(() => session['done'] = false);
                        } else {
                          if (completed < totalSets) {
                            toast(
                              context,
                              'Save each completed set before finishing your workout.',
                            );
                            return;
                          }
                          setState(() => session['done'] = true);
                        }
                        widget.store.sessions[dayKey(widget.date)] = session;
                        await widget.store.save();
                        if (context.mounted) {
                          if (done) {
                            await showWorkoutReward(
                              context,
                              before: beforeXp,
                              after: widget.store.totalXp,
                            );
                          } else {
                            toast(context, 'Workout reopened.');
                          }
                        }
                      },
                icon: Icon(done ? Icons.replay : Icons.check_circle_outline),
                label: Text(done ? 'Reopen workout' : 'Finish workout'),
              ),
              gap(20),
              small(
                'Choose a load that leaves 2–3 reps in reserve. The goal is steady progress with controlled form. Weight is the barbell total or one dumbbell; stay consistent in how you log it.',
              ),
            ],
            gap(35),
          ],
        ),
      ),
    ),
    bottomNavigationBar: seconds > 0
        ? SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: lime,
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'REST · ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      timer?.cancel();
                      setState(() => seconds = 0);
                    },
                    child: const Text('Skip', style: TextStyle(color: ink)),
                  ),
                ],
              ),
            ),
          )
        : null,
  );
}

class SetRow extends StatefulWidget {
  final int index;
  final Map? initial;
  final bool timed, bodyweight, disabled, assistance;
  final int suggestedReps;
  final Future<void> Function(int, double, bool) onSave;
  const SetRow({
    super.key,
    required this.index,
    this.initial,
    required this.timed,
    required this.bodyweight,
    this.assistance = false,
    this.suggestedReps = 8,
    required this.disabled,
    required this.onSave,
  });
  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final TextEditingController reps, weight;
  late bool checked;
  String? error;
  @override
  void initState() {
    super.initState();
    checked = widget.initial?['checked'] == true;
    reps = TextEditingController(
      text:
          widget.initial?['reps']?.toString() ??
          widget.suggestedReps.toString(),
    );
    weight = TextEditingController(
      text: widget.initial?['kg']?.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    reps.dispose();
    weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 45, child: small('SET ${widget.index + 1}')),
            Expanded(
              child: TextField(
                controller: reps,
                enabled: !checked && !widget.disabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: widget.timed ? 'Seconds' : 'Reps',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: weight,
                enabled: !checked && !widget.disabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: widget.assistance
                      ? 'Assistance kg'
                      : widget.bodyweight
                      ? 'Added kg'
                      : 'Weight · kg',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: checked ? 'Reopen set' : 'Save completed set',
              onPressed: widget.disabled
                  ? null
                  : () async {
                      final r = int.tryParse(reps.text),
                          w = double.tryParse(weight.text);
                      if (r == null ||
                          r < 1 ||
                          r > 600 ||
                          w == null ||
                          !w.isFinite ||
                          w < 0 ||
                          w > 600) {
                        setState(
                          () =>
                              error = 'Enter 1–600 reps/seconds and 0–600 kg.',
                        );
                        return;
                      }
                      setState(() {
                        error = null;
                        checked = !checked;
                      });
                      await widget.onSave(r, w, checked);
                    },
              icon: Icon(
                checked ? Icons.check_circle : Icons.check_circle_outline,
                color: checked ? lime : muted,
                size: 27,
              ),
            ),
          ],
        ),
      ),
      if (error != null)
        Text(error!, style: const TextStyle(color: orange, fontSize: 11)),
    ],
  );
}

class ExerciseGuide extends StatefulWidget {
  final Exercise exercise;
  const ExerciseGuide({super.key, required this.exercise});
  @override
  State<ExerciseGuide> createState() => _ExerciseGuideState();
}

class _ExerciseGuideState extends State<ExerciseGuide> {
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.exercise.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              tooltip: 'Close exercise demo',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        gap(8),
        small('${widget.exercise.muscle} · ${widget.exercise.reps}'),
        gap(20),
        ExerciseMedia(exerciseId: widget.exercise.id),
        gap(18),
        small(
          'Watch the setup and the whole repetition. Use a light practice set before adding load.',
        ),
        heading('Make every rep count.'),
        ...widget.exercise.cues.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tag('${entry.key + 1}', color: orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(entry.value, style: const TextStyle(height: 1.6)),
                ),
              ],
            ),
          ),
        ),
        gap(12),
      ],
    ),
  );
}
