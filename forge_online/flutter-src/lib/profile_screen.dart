import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'body_status.dart';
import 'main.dart' show lime, orange, muted, gap, small, tag;

class ProfileScreen extends StatefulWidget {
  final AppStore store;
  final bool editing;
  const ProfileScreen({super.key, required this.store, this.editing = false});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      weight = TextEditingController(),
      height = TextEditingController(),
      age = TextEditingController(),
      calories = TextEditingController(),
      protein = TextEditingController();
  final feet = TextEditingController(), inches = TextEditingController();
  String heightUnit = 'cm', formError = '';
  bool lowerBmiThresholds = false;
  String sex = 'Male',
      goal = 'Lean & defined',
      equipment = 'Full gym',
      experience = 'Beginner';
  double activity = 1.375;
  List<int> selectedDays = [1, 2, 3, 4, 5];
  @override
  void initState() {
    super.initState();
    final p = widget.store.profile;
    if (p != null) {
      name.text = p.name;
      weight.text = '${p.weight}';
      height.text = '${p.height}';
      age.text = '${p.age}';
      sex = p.sex;
      goal = p.goal;
      equipment = p.equipment;
      experience = p.experience;
      activity = p.activity;
      selectedDays = List<int>.from(p.trainingDays);
      calories.text = p.calorieOverride?.toString() ?? '';
      protein.text = p.proteinOverride?.toString() ?? '';
      lowerBmiThresholds = p.lowerBmiThresholds;
    }
  }

  @override
  void dispose() {
    for (final c in [
      name,
      weight,
      height,
      age,
      calories,
      protein,
      feet,
      inches,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget number(
    String label,
    TextEditingController c,
    double low,
    double high, {
    bool optional = false,
    bool integer = false,
  }) => TextFormField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    onChanged: (_) => setState(() {}),
    validator: (s) {
      if (optional && s!.isEmpty) return null;
      final v = double.tryParse(s ?? '');
      return v == null ||
              !v.isFinite ||
              v < low ||
              v > high ||
              (integer && int.tryParse(s ?? '') == null)
          ? 'Enter ${low.round()}–${high.round()}${integer ? ' (whole number)' : ''}'
          : null;
    },
  );
  Widget select(
    String label,
    String value,
    List<String> items,
    void Function(String) onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: items
        .map(
          (v) => DropdownMenuItem(
            value: v,
            child: Text(v, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (v) => setState(() => onChanged(v!)),
  );
  double? get heightCm {
    if (heightUnit == 'cm') return double.tryParse(height.text);
    final f = double.tryParse(feet.text), i = double.tryParse(inches.text);
    if (f == null ||
        i == null ||
        !f.isFinite ||
        !i.isFinite ||
        f != f.floorToDouble() ||
        i < 0 ||
        i >= 12) {
      return null;
    }
    return (f * 12 + i) * 2.54;
  }

  Profile? get draft {
    final w = double.tryParse(weight.text),
        h = heightCm,
        a = int.tryParse(age.text);
    if (w == null ||
        h == null ||
        a == null ||
        !w.isFinite ||
        !h.isFinite ||
        w < 30 ||
        w > 300 ||
        h < 120 ||
        h > 230 ||
        a < 18 ||
        a > 85) {
      return null;
    }
    final custom = int.tryParse(calories.text),
        customProtein = int.tryParse(protein.text);
    return Profile(
      name: name.text.trim(),
      sex: sex,
      goal: goal,
      equipment: equipment,
      experience: experience,
      weight: w,
      height: h,
      activity: activity,
      age: a,
      days: selectedDays.length,
      preferredDays: List<int>.from(selectedDays),
      calorieOverride: custom != null && custom >= 1200 && custom <= 6000
          ? custom
          : null,
      proteinOverride:
          customProtein != null && customProtein >= 30 && customProtein <= 350
          ? customProtein
          : null,
      lowerBmiThresholds: lowerBmiThresholds,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.editing ? AppBar(title: const Text('Your profile')) : null,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: lime, size: 32),
                      const Text(
                        'FORGE',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: FittedBox(
                          child: tag(
                            widget.editing
                                ? 'YOUR FOUNDATION'
                                : 'LET’S BUILD YOU',
                          ),
                        ),
                      ),
                    ],
                  ),
                  gap(36),
                  Text(
                    widget.editing
                        ? 'Make it personal.'
                        : 'Stronger starts\nwith you.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  gap(10),
                  const Text(
                    'A little about you. A plan built around your life.',
                    style: TextStyle(color: muted, fontSize: 16),
                  ),
                  gap(30),
                  if (widget.store.cloudEnabled &&
                      widget.store.cloudAuthRequired) ...[
                    const Text(
                      'Sign in to keep your profile and progress private.',
                      style: TextStyle(color: orange),
                    ),
                    gap(12),
                    FilledButton(
                      onPressed: () => launchUrl(
                        Uri.base.resolve('/signin-with-chatgpt?return_to=/'),
                        webOnlyWindowName: '_top',
                      ),
                      child: const Text('Sign in to FORGE'),
                    ),
                    gap(20),
                  ],
                  if (widget.store.storageError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Saved data could not be read. Your existing storage has been kept. Avoid saving a new profile until your backup is recovered.',
                        style: TextStyle(color: orange),
                      ),
                    ),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'What should we call you?',
                    ),
                    maxLength: 30,
                    validator: (s) => s == null || s.trim().isEmpty
                        ? 'Enter your name'
                        : null,
                  ),
                  gap(),
                  number('Weight · kg', weight, 30, 300),
                  gap(),
                  select('Height units', heightUnit, ['cm', 'Feet & inches'], (
                    v,
                  ) {
                    final old = heightCm;
                    if (v == 'Feet & inches' && old != null && old.isFinite) {
                      final total = old / 2.54;
                      feet.text = '${(total / 12).floor()}';
                      inches.text = (total % 12).toStringAsFixed(1);
                    } else if (v == 'cm' && old != null && old.isFinite) {
                      height.text = old.toStringAsFixed(2);
                    }
                    heightUnit = v;
                  }),
                  gap(),
                  if (heightUnit == 'cm')
                    number('Height · cm', height, 120, 230)
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: number(
                            'Height · feet',
                            feet,
                            3,
                            7,
                            integer: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: number('Height · inches', inches, 0, 11.99),
                        ),
                      ],
                    ),
                    FormField<double>(
                      validator: (_) =>
                          heightCm == null || heightCm! < 120 || heightCm! > 230
                          ? 'Check height: enter feet and inches separately (120–230 cm total).'
                          : null,
                      builder: (field) => field.hasError
                          ? Text(
                              field.errorText!,
                              style: const TextStyle(color: orange),
                            )
                          : small(
                              heightCm == null
                                  ? 'For 5 ft 3 in, enter 5 and 3.'
                                  : '${heightCm!.toStringAsFixed(2)} cm · stored in centimetres',
                            ),
                    ),
                  ],
                  gap(),
                  Row(
                    children: [
                      Expanded(
                        child: number('Age · 18+', age, 18, 85, integer: true),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: select('Sex for calorie formula', sex, [
                          'Male',
                          'Female',
                        ], (v) => sex = v),
                      ),
                    ],
                  ),
                  gap(),
                  select('Your main goal', goal, [
                    'Lean & defined',
                    'Build muscle',
                    'Maintain & get stronger',
                    'Improve endurance',
                    'Reduce body fat',
                    'Reduce waist / belly fat',
                  ], (v) => goal = v),
                  FormField<String>(
                    validator: (_) =>
                        draft != null && draft!.fatLossGoal && draft!.bmi < 18.5
                        ? 'Your BMI is underweight. Choose strength or gradual gain rather than a weight-loss plan; a dietitian can help.'
                        : null,
                    builder: (f) => f.hasError
                        ? Text(
                            f.errorText!,
                            style: const TextStyle(color: orange),
                          )
                        : const SizedBox.shrink(),
                  ),
                  gap(10),
                  small(
                    'Men and women both benefit from balanced strength training. The sex field adjusts the calorie formula; your goal, equipment and experience shape the plan. Belly-fat goals use overall fat loss, not spot reduction.',
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: lowerBmiThresholds,
                    onChanged: (v) =>
                        setState(() => lowerBmiThresholds = v == true),
                    title: const Text(
                      'Use lower BMI thresholds for my background',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Optional: South Asian, Chinese/other Asian, Middle Eastern, Black African or African–Caribbean. NHS risk bands begin at BMI 23.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  gap(),
                  DropdownButtonFormField<double>(
                    initialValue: activity,
                    decoration: const InputDecoration(
                      labelText: 'Activity, including training',
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 1.2,
                        child: Text('Mostly seated · little activity'),
                      ),
                      DropdownMenuItem(
                        value: 1.375,
                        child: Text('Lightly active · 1–3 days/week'),
                      ),
                      DropdownMenuItem(
                        value: 1.55,
                        child: Text('Active · 3–5 days/week'),
                      ),
                      DropdownMenuItem(
                        value: 1.725,
                        child: Text('Very active · 6–7 days/week'),
                      ),
                    ],
                    onChanged: (v) => setState(() => activity = v!),
                  ),
                  gap(),
                  select('Equipment you have', equipment, [
                    'Full gym',
                    'Dumbbells',
                    'Bodyweight',
                  ], (v) => equipment = v),
                  gap(),
                  select('Experience', experience, [
                    'Beginner',
                    'Intermediate',
                  ], (v) => experience = v),
                  gap(22),
                  const Text(
                    'Which days do you usually train?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  small(
                    'Choose 2–5 days. You can change your mind on the day.',
                  ),
                  gap(12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      7,
                      (i) => FilterChip(
                        label: Text(weekdays[i].substring(0, 3)),
                        selected: selectedDays.contains(i + 1),
                        onSelected: (v) => setState(() {
                          if (v) {
                            if (selectedDays.length < 5) {
                              selectedDays.add(i + 1);
                              selectedDays.sort();
                            }
                          } else {
                            selectedDays.remove(i + 1);
                          }
                        }),
                      ),
                    ),
                  ),
                  FormField<int>(
                    validator: (_) => selectedDays.length < 2
                        ? 'Choose at least two training days.'
                        : null,
                    builder: (field) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        field.errorText ??
                            '${selectedDays.length} training days · ${7 - selectedDays.length} recovery days',
                        style: TextStyle(
                          color: field.hasError ? orange : muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  gap(8),
                  small(
                    'Missed a day? Your next unfinished session moves with you. Only finishing a workout advances the sequence.',
                  ),
                  gap(20),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Set my own nutrition targets',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: small(
                      'Optional. Leave blank for calculated estimates.',
                    ),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: number(
                              'Calories · kcal',
                              calories,
                              1200,
                              6000,
                              optional: true,
                              integer: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: number(
                              'Protein · g',
                              protein,
                              30,
                              350,
                              optional: true,
                              integer: true,
                            ),
                          ),
                        ],
                      ),
                      gap(),
                    ],
                  ),
                  gap(),
                  small(
                    'Adult starting estimates: Mifflin–St Jeor × activity; +200 kcal for muscle gain or −250 kcal for a chosen fat-loss goal. Other goals start at maintenance. Protein 1.6 g/kg. Review progress and adjust; pregnancy or breastfeeding need individual advice.',
                  ),
                  if (draft != null) ...[
                    gap(18),
                    BodyStatusCard(
                      profile: draft!,
                      preview: true,
                      onUseTarget: (n) => setState(() => calories.text = '$n'),
                    ),
                  ],
                  gap(24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        if (!form.currentState!.validate()) {
                          setState(
                            () => formError =
                                draft != null &&
                                    draft!.fatLossGoal &&
                                    draft!.bmi < 18.5
                                ? 'Your BMI is underweight. Choose strength or gradual gain rather than a weight-loss plan.'
                                : 'Check the highlighted fields above before building your plan.',
                          );
                          return;
                        }
                        setState(() => formError = '');
                        final p = Profile(
                          name: name.text.trim(),
                          sex: sex,
                          goal: goal,
                          equipment: equipment,
                          experience: experience,
                          weight: double.parse(weight.text),
                          height: heightCm!,
                          activity: activity,
                          age: int.parse(age.text),
                          days: selectedDays.length,
                          preferredDays: List<int>.from(selectedDays),
                          calorieOverride: int.tryParse(calories.text),
                          proteinOverride: int.tryParse(protein.text),
                          lowerBmiThresholds: lowerBmiThresholds,
                        );
                        await widget.store.setProfile(p);
                        if (context.mounted && widget.editing) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        widget.editing ? 'Save my profile' : 'Build my plan',
                      ),
                    ),
                  ),
                  if (formError.isNotEmpty) ...[
                    gap(12),
                    Text(formError, style: const TextStyle(color: orange)),
                  ],
                  gap(12),
                  Center(
                    child: small(
                      widget.store.cloudEnabled
                          ? 'PRIVATE ACCOUNT · SYNCED ACROSS DEVICES'
                          : 'YOUR DATA STAYS ON THIS DEVICE',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
