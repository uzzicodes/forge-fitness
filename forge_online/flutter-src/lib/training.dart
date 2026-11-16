class Exercise {
  final String id, name, muscle, equipment, reps, movement;
  final int rest;
  final List<String> cues;
  const Exercise(
    this.id,
    this.name,
    this.muscle,
    this.equipment,
    this.reps,
    this.movement,
    this.rest,
    this.cues,
  );
}

const library = <Exercise>[
  Exercise(
    "machinechest",
    "Machine chest press",
    "Chest · triceps",
    "Full gym",
    "8–12",
    "press",
    120,
    [
      "Set the seat so handles are around mid-chest; keep feet planted and your back against the pad.",
      "Press forward without shrugging or locking hard at the elbows.",
      "Return slowly through a comfortable range; keep the machine weight stack controlled.",
    ],
  ),
  Exercise(
    "machinerow",
    "Chest-supported machine row",
    "Back · biceps",
    "Full gym",
    "8–12",
    "row",
    90,
    [
      "Adjust the seat and chest pad so you can reach the handles without rounding your back.",
      "Keep your chest against the pad and pull elbows toward your hips.",
      "Return slowly without lifting your chest or jerking the weight.",
    ],
  ),
  Exercise(
    "machineshoulder",
    "Machine shoulder press",
    "Shoulders · triceps",
    "Full gym",
    "8–12",
    "overhead",
    90,
    [
      "Adjust the seat so handles start around shoulder height. Keep your back supported and feet planted.",
      "Press smoothly overhead with your ribs down; use a comfortable grip.",
      "Lower under control and stop before any painful range.",
    ],
  ),
  Exercise(
    "legpress",
    "45-degree leg press",
    "Quads · glutes",
    "Full gym",
    "10–15",
    "squat",
    120,
    [
      "Adjust the seat, set the safety stops and place feet about shoulder-width on the platform.",
      "Lower only as far as you can keep your pelvis and back against the pad.",
      "Push through your whole foot; do not lock your knees hard or put hands on your knees.",
    ],
  ),
  Exercise(
    "barbellrdl",
    "Barbell Romanian deadlift",
    "Hamstrings · glutes",
    "Full gym",
    "8–12",
    "hinge",
    120,
    [
      "Start standing with the bar close to your thighs, knees softly bent and trunk braced.",
      "Push your hips back with the bar close to your legs. Stop at a controlled hamstring stretch.",
      "Stand by bringing your hips forward; avoid rounding your back or leaning backward at the top.",
    ],
  ),
  Exercise(
    "seatedlegcurl",
    "Seated leg curl",
    "Hamstrings",
    "Full gym",
    "10–15",
    "legcurl",
    90,
    [
      "Align your knee joint with the machine pivot and secure the thigh pad without painful pressure.",
      "Curl your heels down and back while keeping your hips against the seat.",
      "Return slowly; choose a load you can control without lifting your hips.",
    ],
  ),
  Exercise(
    "lyinglegcurl",
    "Lying leg curl",
    "Hamstrings",
    "Full gym",
    "10–15",
    "legcurl",
    90,
    [
      "Align knees with the machine pivot and place the lower pad above your heels.",
      "Keep your hips on the pad while bending your knees to curl the weight.",
      "Lower slowly without arching your back or bouncing the stack.",
    ],
  ),
  Exercise(
    "cablelateral",
    "Single-arm cable lateral raise",
    "Shoulders",
    "Full gym",
    "12–20",
    "lateral",
    60,
    [
      "Set a light low cable and stand side-on with the handle in the hand farther from the stack.",
      "Raise your arm out to the side to about shoulder height with a soft elbow.",
      "Lower slowly without shrugging or leaning; complete both sides.",
    ],
  ),
  Exercise(
    "pushdown",
    "Cable triceps pushdown",
    "Triceps",
    "Full gym",
    "10–15",
    "triceps",
    60,
    [
      "Stand tall at a high pulley with elbows close to your sides.",
      "Extend your elbows to press the handle down without rocking your torso.",
      "Return slowly and keep your upper arms steady.",
    ],
  ),
  Exercise(
    "cablecurl",
    "Standing cable curl",
    "Biceps",
    "Full gym",
    "10–15",
    "curl",
    60,
    [
      "Face a low pulley, stand tall and hold the handle with palms up.",
      "Keep elbows close to your sides as you curl without swinging.",
      "Lower slowly through a comfortable range and keep wrists steady.",
    ],
  ),
  Exercise(
    "assistedpullup",
    "Assisted pull-up machine",
    "Back · biceps",
    "Full gym",
    "6–10",
    "pulldown",
    120,
    [
      "Select enough assistance to control every repetition; more assistance makes this machine easier.",
      "Use the machine steps and knee pad as instructed. Pull elbows down without swinging.",
      "Lower smoothly and use the steps to get off safely. Record assistance separately from ordinary lifting loads.",
    ],
  ),
  Exercise(
    "machinecalf",
    "Standing calf raise machine",
    "Calves",
    "Full gym",
    "12–20",
    "calf",
    60,
    [
      "Set shoulder pads and safety stops for your height and place the balls of your feet on the platform.",
      "Rise smoothly onto your toes with knees softly extended; avoid bouncing.",
      "Lower under control through a comfortable ankle range.",
    ],
  ),
  Exercise(
    'inclinedbpress',
    'Incline dumbbell bench press',
    'Upper chest · shoulders · triceps',
    'Full gym',
    '8–12',
    'press',
    90,
    [
      'Set the bench to a modest 15–30° incline. Plant your feet and hold the dumbbells above your chest.',
      'Lower with control, keeping wrists stacked over elbows and elbows at a comfortable angle.',
      'Press up smoothly without bouncing or shrugging. Start light and use help getting heavy dumbbells into position.',
    ],
  ),
  Exercise(
    'lateral',
    'Dumbbell lateral raise',
    'Shoulders',
    'Dumbbells',
    '10–15',
    'lateral',
    60,
    [
      'Stand tall with a light dumbbell in each hand and a slight bend in your elbows.',
      'Raise arms out to the sides to around shoulder height without shrugging.',
      'Lower slowly. Keep the load light and avoid swinging.',
    ],
  ),
  Exercise(
    'triceps',
    'Dumbbell triceps extension',
    'Triceps',
    'Dumbbells',
    '10–15',
    'triceps',
    60,
    [
      'Hold one light dumbbell with both hands overhead, ribs down.',
      'Bend your elbows to lower the weight behind your head through a comfortable range.',
      'Extend your elbows without arching your back. Use a light, controlled load.',
    ],
  ),
  Exercise(
    'bench',
    'Barbell bench press',
    'Chest · triceps',
    'Full gym',
    '6–10',
    'press',
    120,
    [
      'Lie with feet planted and shoulder blades gently back. Grip slightly wider than shoulders.',
      'Lower the bar under control toward your lower chest; keep forearms roughly vertical.',
      'Press up without bouncing. Use a spotter or safety arms; begin with a light load.',
    ],
  ),
  Exercise(
    'dbpress',
    'Dumbbell floor press',
    'Chest · triceps',
    'Dumbbells',
    '8–12',
    'press',
    90,
    [
      'Lie on the floor with knees bent and a dumbbell in each hand.',
      'Keep elbows about 45° from your body. Lower until upper arms lightly touch the floor.',
      'Press up smoothly, keeping wrists stacked above elbows.',
    ],
  ),
  Exercise(
    'pushup',
    'Push-up',
    'Chest · triceps',
    'Bodyweight',
    '6–15',
    'pushup',
    90,
    [
      'Place hands just wider than shoulders and make a straight line from head to heels.',
      'Brace your abdomen and lower your chest between your hands.',
      'Push the floor away. Use a wall or elevated surface if full repetitions are difficult.',
    ],
  ),
  Exercise(
    'row',
    'Seated cable row',
    'Back · biceps',
    'Full gym',
    '8–12',
    'row',
    90,
    [
      'Sit tall with knees slightly bent and torso steady.',
      'Pull the handle toward your lower ribs, allowing elbows to move behind you.',
      'Return slowly without rounding your back or rocking your torso.',
    ],
  ),
  Exercise(
    'dbrow',
    'One-arm dumbbell row',
    'Back · biceps',
    'Dumbbells',
    '8–12 / side',
    'row',
    90,
    [
      'Support one hand on a sturdy bench; hinge at your hips with a neutral back.',
      'Pull the dumbbell toward your hip without twisting your torso.',
      'Lower slowly until your arm is long. Complete both sides.',
    ],
  ),
  Exercise(
    'prone',
    'Prone W raise',
    'Upper back · shoulders',
    'Bodyweight',
    '10–15',
    'row',
    60,
    [
      'Lie face down, arms in a W with elbows bent.',
      'Gently lift hands and elbows a few centimetres, drawing shoulder blades together.',
      'Pause and lower. Keep your neck relaxed. This is a light control exercise.',
    ],
  ),
  Exercise(
    'lat',
    'Lat pulldown',
    'Back · biceps',
    'Full gym',
    '8–12',
    'pulldown',
    90,
    [
      'Secure thighs under pads and take a comfortable overhand grip.',
      'Keep chest tall and pull the bar toward your upper chest.',
      'Return slowly without swinging or pulling the bar behind your neck.',
    ],
  ),
  Exercise(
    'shoulder',
    'Dumbbell shoulder press',
    'Shoulders · triceps',
    'Dumbbells',
    '8–12',
    'overhead',
    90,
    [
      'Stand or sit tall, holding dumbbells near shoulder height.',
      'Brace your trunk and press overhead without arching your lower back.',
      'Lower under control. Use a comfortable, pain-free range.',
    ],
  ),
  Exercise(
    'pike',
    'Incline push-up',
    'Chest · shoulders',
    'Bodyweight',
    '8–15',
    'pushup',
    75,
    [
      'Place hands on a sturdy, fixed elevated surface.',
      'Keep a straight body line and lower your chest toward the surface.',
      'Press away. Choose a height that allows smooth, controlled repetitions.',
    ],
  ),
  Exercise(
    'curl',
    'Dumbbell curl',
    'Biceps',
    'Dumbbells',
    '10–15',
    'curl',
    60,
    [
      'Stand tall with elbows beside your ribs and palms facing forward.',
      'Curl without swinging or moving your upper arms forward.',
      'Lower slowly and keep wrists straight.',
    ],
  ),
  Exercise(
    'squat',
    'Goblet squat',
    'Quads · glutes',
    'Dumbbells',
    '8–12',
    'squat',
    120,
    [
      'Hold one dumbbell at your chest and stand about shoulder-width apart.',
      'Sit down between your hips; let knees track in the direction of your toes.',
      'Keep heels grounded and stand tall. Choose a depth you can control.',
    ],
  ),
  Exercise(
    'bbsquat',
    'Barbell back squat',
    'Quads · glutes',
    'Full gym',
    '6–10',
    'squat',
    150,
    [
      'Set the rack safeties and place the bar securely across your upper back.',
      'Brace, then bend at hips and knees while keeping the bar over mid-foot.',
      'Stand smoothly. Start light and learn the movement with a qualified coach.',
    ],
  ),
  Exercise(
    'airsquat',
    'Bodyweight squat',
    'Quads · glutes',
    'Bodyweight',
    '10–20',
    'squat',
    75,
    [
      'Stand with feet around shoulder-width apart.',
      'Bend at hips and knees while keeping your heels grounded.',
      'Stand tall without locking aggressively. Use a chair as a depth guide if needed.',
    ],
  ),
  Exercise(
    'rdl',
    'Dumbbell Romanian deadlift',
    'Hamstrings · glutes',
    'Dumbbells',
    '8–12',
    'hinge',
    120,
    [
      'Stand with soft knees and dumbbells in front of your thighs.',
      'Push your hips back, keeping weights close and your spine neutral.',
      'Stop when you feel a hamstring stretch; stand by driving your hips forward.',
    ],
  ),
  Exercise(
    'bridge',
    'Glute bridge',
    'Glutes · hamstrings',
    'Bodyweight',
    '12–20',
    'bridge',
    60,
    [
      'Lie on your back with knees bent and feet flat, hip-width apart.',
      'Brace, then lift your hips while keeping ribs down.',
      'Pause briefly and lower slowly. Avoid overextending your lower back.',
    ],
  ),
  Exercise(
    'lunge',
    'Reverse lunge',
    'Quads · glutes',
    'Bodyweight',
    '8–12 / side',
    'lunge',
    90,
    [
      'Stand tall, then step one foot back and lower both knees.',
      'Keep your front foot planted and torso controlled.',
      'Push through the front foot to stand. Hold a stable support for balance if needed.',
    ],
  ),
  Exercise(
    'calf',
    'Standing calf raise',
    'Calves',
    'Bodyweight',
    '12–20',
    'calf',
    60,
    [
      'Stand tall with a stable support nearby.',
      'Rise onto the balls of your feet and pause briefly.',
      'Lower heels slowly through a comfortable range. Avoid bouncing.',
    ],
  ),
  Exercise(
    'plank',
    'Forearm plank',
    'Core',
    'Bodyweight',
    '20–40 sec',
    'plank',
    60,
    [
      'Place elbows beneath shoulders and extend your legs.',
      'Brace your abdomen and glutes, keeping a straight line from head to heels.',
      'Breathe steadily. End the hold before your lower back starts to sag.',
    ],
  ),
  Exercise(
    'deadbug',
    'Dead bug',
    'Core · control',
    'Bodyweight',
    '6–10 / side',
    'deadbug',
    60,
    [
      'Lie on your back with arms reaching up and hips and knees at 90°.',
      'Gently brace, then extend the opposite arm and leg while keeping your back steady.',
      'Return slowly and alternate sides. Shorten the range if your back arches.',
    ],
  ),
];
Exercise ex(String id) => library.firstWhere((e) => e.id == id);

class Workout {
  final String name, focus;
  final List<Exercise> exercises;
  final int sets;
  final int? rotationIndex;
  const Workout(
    this.name,
    this.focus,
    this.exercises,
    this.sets, [
    this.rotationIndex,
  ]);
  bool get rest => exercises.isEmpty;
}

const recoveryWorkout = Workout(
  'Rest & recovery',
  'Your next workout stays in the queue.',
  [],
  0,
);

List<Workout> rotationFor(
  String equipment,
  int days,
  String experience, {
  String goal = '',
}) {
  final plans = _baseRotationFor(equipment, days, experience, goal: goal);
  if (goal != 'Reduce body fat' && goal != 'Reduce waist / belly fat') {
    return plans;
  }
  return List.generate(plans.length, (i) {
    final w = plans[i], moves = List<Exercise>.from(w.exercises);
    if (goal == 'Reduce waist / belly fat' &&
        (i == 0 || i == (plans.length > 2 ? 2 : 1)) &&
        !moves.any((e) => e.muscle.contains('Core'))) {
      moves.add(ex('deadbug'));
    }
    return Workout(
      w.name,
      '${w.focus} · optional 5–15 min comfortable walking/cycling',
      moves,
      w.sets,
      w.rotationIndex,
    );
  });
}

List<Workout> _baseRotationFor(
  String equipment,
  int days,
  String experience, {
  String goal = '',
}) {
  if (equipment == 'Full gym') return gymRotation(days, experience, goal);
  final gym = equipment == 'Full gym', body = equipment == 'Bodyweight';
  final press = ex(
    gym
        ? 'bench'
        : body
        ? 'pushup'
        : 'dbpress',
  );
  final row = ex(
    gym
        ? 'row'
        : body
        ? 'prone'
        : 'dbrow',
  );
  final squat = ex(
    gym
        ? 'bbsquat'
        : body
        ? 'airsquat'
        : 'squat',
  );
  final hinge = ex(body ? 'bridge' : 'rdl');
  final shoulder = ex(body ? 'pike' : 'shoulder');
  final sets = experience == 'Beginner' ? 2 : 3;
  final upper = [
    press,
    row,
    goal == 'Lean & defined' && !body ? ex('lateral') : shoulder,
    body ? ex('deadbug') : ex('curl'),
    ex('plank'),
  ];
  final lower = [squat, hinge, ex('lunge'), ex('calf'), ex('deadbug')];
  List<Workout> plan;
  if (days <= 3) {
    plan = [
      Workout('Full body A', 'Squat, push, pull & core', [
        squat,
        press,
        row,
        hinge,
        ex('plank'),
      ], sets),
      Workout('Full body B', 'Strength + muscular endurance', [
        ex('lunge'),
        shoulder,
        row,
        hinge,
        ex('deadbug'),
      ], sets),
      if (days == 3)
        Workout('Full body C', 'Controlled reps, balanced strength', [
          squat,
          press,
          row,
          ex('calf'),
          ex('deadbug'),
        ], sets),
    ];
  } else if (days == 4) {
    plan = [
      Workout(
        'Upper body · strength',
        'Chest, back, shoulders & arms',
        upper,
        sets,
      ),
      Workout('Lower body · strength', 'Legs, glutes & core', lower, sets),
      Workout(
        'Upper body · volume',
        'Controlled reps + muscular endurance',
        upper,
        sets,
      ),
      Workout('Lower body · volume', 'Legs, glutes & core', [
        ex('lunge'),
        hinge,
        squat,
        ex('calf'),
        ex('plank'),
      ], sets),
    ];
  } else {
    plan = [
      Workout(
        'Push · chest & shoulders',
        'Chest, shoulders, triceps & core',
        body
            ? [press, shoulder, ex('deadbug'), ex('plank')]
            : [
                goal == 'Lean & defined' && gym ? ex('inclinedbpress') : press,
                shoulder,
                ex('lateral'),
                ex('triceps'),
                ex('plank'),
              ],
        sets,
      ),
      Workout(
        'Pull · back & biceps',
        body
            ? 'Back control & core · add resistance equipment for stronger pulling'
            : 'Back, biceps & trunk control',
        body
            ? [row, ex('deadbug'), ex('bridge'), ex('plank')]
            : [row, gym ? ex('lat') : ex('prone'), ex('curl'), ex('deadbug')],
        sets,
      ),
      Workout(
        'Legs · strength',
        'Quads, hamstrings, glutes & calves',
        lower,
        sets,
      ),
      Workout(
        'Upper body · balanced',
        'Push + pull, shoulders & core',
        upper,
        sets,
      ),
      Workout(
        'Lower body · endurance',
        'Controlled leg work · optional 10–15 min easy cardio',
        [ex('lunge'), hinge, squat, ex('calf'), ex('plank')],
        sets,
      ),
    ];
  }
  return plan
      .asMap()
      .entries
      .map(
        (e) => Workout(
          e.value.name,
          e.value.focus,
          e.value.exercises,
          e.value.sets,
          e.key,
        ),
      )
      .toList();
}

// Stateless preview for a fresh schedule. Live planning uses AppStore.workoutOn.
Workout workoutFor(int weekday, String equipment, int days, String experience) {
  final preferred = days == 2
      ? [1, 4]
      : days == 3
      ? [1, 3, 5]
      : days == 4
      ? [1, 2, 4, 5]
      : [1, 2, 3, 4, 5];
  final index = preferred.indexOf(weekday);
  return index < 0
      ? recoveryWorkout
      : rotationFor(equipment, days, experience)[index];
}

// Full-gym selection balances movement patterns; no tool is inherently superior.
List<Workout> gymRotation(int days, String experience, String goal) {
  final sets = experience == 'Beginner' ? 2 : 3;
  final squat = experience == 'Beginner' ? 'legpress' : 'bbsquat';
  Workout w(String name, String focus, List<String> ids) =>
      Workout(name, focus, ids.map(ex).toList(), sets);
  final upper = ['bench', 'row', 'lat', 'lateral', 'curl', 'plank'];
  final lower = [squat, 'rdl', 'seatedlegcurl', 'machinecalf', 'deadbug'];
  final lowerB = ['legpress', 'barbellrdl', 'lyinglegcurl', 'lunge', 'plank'];
  final plan = days <= 3
      ? [
          w('Full body A', 'Squat, chest press, row, hinge & core', [
            squat,
            'bench',
            'row',
            'rdl',
            'plank',
          ]),
          w('Full body B', 'Legs, chest, vertical pull & hamstrings', [
            'lunge',
            'machinechest',
            'lat',
            'seatedlegcurl',
            'deadbug',
          ]),
          if (days == 3)
            w('Full body C', 'Balanced strength with controlled repetitions', [
              squat,
              'inclinedbpress',
              'machinerow',
              'machineshoulder',
              'lyinglegcurl',
            ]),
        ]
      : days == 4
      ? [
          w(
            'Upper body · strength',
            'Chest, back, shoulders, arms & core',
            upper,
          ),
          w(
            'Lower body · strength',
            'Quads, hamstrings, glutes, calves & core',
            lower,
          ),
          w('Upper body · volume', 'Chest, back, shoulders & triceps', [
            'inclinedbpress',
            'machinerow',
            'lat',
            'cablelateral',
            'pushdown',
          ]),
          w('Lower body · volume', 'Squat, hinge, knee flexion & core', lowerB),
        ]
      : [
          w('Push · chest & shoulders', 'Chest, shoulders & triceps', [
            goal == 'Lean & defined' ? 'inclinedbpress' : 'bench',
            'machineshoulder',
            'machinechest',
            'cablelateral',
            'pushdown',
          ]),
          w(
            'Pull · back & biceps',
            'Vertical pull, supported row, biceps & core',
            ['lat', 'machinerow', 'cablecurl', 'deadbug'],
          ),
          w(
            'Legs · strength',
            'Quads, hamstrings, glutes, calves & core',
            lower,
          ),
          w(
            'Upper body · balanced',
            'Chest, back, shoulders, arms & core',
            upper,
          ),
          w(
            'Lower body · endurance',
            'Controlled leg work · optional easy cardio',
            lowerB,
          ),
        ];
  return plan
      .asMap()
      .entries
      .map(
        (e) => Workout(
          e.value.name,
          e.value.focus,
          e.value.exercises,
          sets,
          e.key,
        ),
      )
      .toList();
}

const substitutionGroups = <List<String>>[
  ['bench', 'inclinedbpress', 'machinechest', 'dbpress', 'pushup', 'pike'],
  ['row', 'machinerow', 'dbrow'],
  ['lat', 'assistedpullup'],
  ['shoulder', 'machineshoulder'],
  ['squat', 'bbsquat', 'legpress', 'airsquat', 'lunge'],
  ['rdl', 'barbellrdl'],
  ['seatedlegcurl', 'lyinglegcurl'],
  ['lateral', 'cablelateral'],
  ['triceps', 'pushdown'],
  ['curl', 'cablecurl'],
  ['calf', 'machinecalf'],
  ['plank', 'deadbug'],
];
List<Exercise> exerciseAlternatives(
  String id,
  String equipment,
  Iterable<String> excluded,
) {
  final group = substitutionGroups.where((g) => g.contains(id)).firstOrNull;
  if (group == null) return [];
  return group
      .where((other) => other != id && !excluded.contains(other))
      .map(ex)
      .where(
        (e) =>
            equipment == 'Full gym' ||
            e.equipment == 'Bodyweight' ||
            (equipment == 'Dumbbells' && e.equipment == 'Dumbbells'),
      )
      .toList();
}

int sessionTarget(Map session, String id) =>
    (session['setTargets'] as Map?)?[id] as int? ??
    session['plannedSets'] as int;
int checkedSets(Map session, String id) => (session['sets'] as Map).entries
    .where(
      (e) =>
          e.key.toString().startsWith('$id-') &&
          (e.value as Map)['checked'] == true,
    )
    .length;
int retiredSetCount(Map session) =>
    (session['retiredExerciseIds'] as List? ?? []).fold<int>(
      0,
      (n, id) => n + checkedSets(session, id as String),
    );
int sessionTotalSets(Map session) => (session['exerciseIds'] as List).fold<int>(
  retiredSetCount(session),
  (n, id) => n + sessionTarget(session, id as String),
);
Map<String, dynamic> swapSessionExercise(
  Map<String, dynamic> original,
  String from,
  String to,
  String equipment,
) {
  final ids = List<String>.from(original['exerciseIds'] as List),
      retired = List<String>.from(
        original['retiredExerciseIds'] as List? ?? [],
      );
  if (original['done'] == true ||
      !ids.contains(from) ||
      retired.length >= 20 ||
      !exerciseAlternatives(from, equipment, [
        ...ids,
        ...retired,
      ]).any((e) => e.id == to)) {
    throw const FormatException('This swap is unavailable.');
  }
  final completed = checkedSets(original, from),
      remaining = sessionTarget(original, from) - completed;
  if (remaining < 1) {
    throw const FormatException(
      'All sets for this exercise are already saved.',
    );
  }
  final sets = Map<String, dynamic>.from(original['sets'] as Map);
  sets.removeWhere(
    (key, value) =>
        key.startsWith('$to-') ||
        (key.startsWith('$from-') && (value as Map)['checked'] != true),
  );
  if (completed > 0) retired.add(from);
  final targets =
      Map<String, dynamic>.from(original['setTargets'] as Map? ?? {})
        ..remove(from)
        ..[to] = remaining;
  ids[ids.indexOf(from)] = to;
  return {
    ...original,
    'exerciseIds': ids,
    'sets': sets,
    'setTargets': targets,
    'retiredExerciseIds': retired,
  };
}
