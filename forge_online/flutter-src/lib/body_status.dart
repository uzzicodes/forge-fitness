import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'main.dart' show box, gap, small, lime, orange;

class BodyStatusCard extends StatelessWidget {
  final Profile profile;
  final void Function(int)? onUseTarget;
  final bool preview;
  final bool compact;
  final VoidCallback? onOpen;
  const BodyStatusCard({
    super.key,
    required this.profile,
    this.onUseTarget,
    this.preview = false,
    this.compact = false,
    this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final p = profile,
        under = p.bmi < 18.5,
        above = p.bmi >= (p.lowerBmiThresholds ? 23 : 25),
        inches = p.height / 2.54,
        feet = (inches / 12).floor();
    final target =
        (under
                ? p.maintenanceCalories + 300
                : p.maintenanceCalories +
                      (p.fatLossGoal
                          ? -250
                          : p.goal == 'Build muscle'
                          ? 200
                          : 0))
            .clamp(p.fatLossGoal && p.sex == 'Male' ? 1500 : 1200, 6000);
    if (compact) {
      return box(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BMI ${p.bmi.toStringAsFixed(2)} · ${p.bmiCategory}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: under || above ? orange : lime,
              ),
            ),
            gap(6),
            small(
              '${p.sex} · ${p.weight} kg · ${p.height.toStringAsFixed(1)} cm · ${p.goal}',
            ),
            gap(8),
            small(
              'BMI is a screening guide, not a body-fat measurement. Your plan uses your chosen goal and profile.',
            ),
            if (onOpen != null)
              TextButton(
                onPressed: onOpen,
                child: const Text('View body & diet plan'),
              ),
          ],
        ),
      );
    }
    final guidance = under
        ? 'Prioritise gradual weight gain and strength, rather than a weight-loss diet. Add regular meals, protein foods and energy-dense snacks. An optional starting point is about 300 kcal above estimated maintenance. If weight loss was unintentional or ongoing, speak with a clinician.'
        : above
        ? 'BMI alone cannot tell whether extra weight is muscle or body fat. Check your waist and weight trend. If reducing body fat is appropriate for you, combine balanced meals with strength training and a moderate calorie deficit; a dietitian can help choose a suitable target.'
        : 'Your height and weight fall in the selected healthy BMI band. You do not need a weight-loss diet based on BMI alone. For an aesthetic, stronger physique, start with consistent strength training, balanced meals and adequate protein; adjust food using your energy and weight trend.';
    return box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview ? 'Your starting point' : 'Your body & starting plan',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          gap(8),
          small(
            '${p.sex} · ${p.weight} kg · ${p.height.toStringAsFixed(1)} cm ($feet ft ${(inches - feet * 12).toStringAsFixed(1)} in) · age ${p.age}',
          ),
          gap(12),
          Text(
            'BMI ${p.bmi.toStringAsFixed(2)} · ${p.bmiCategory}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: under || above ? orange : lime,
            ),
          ),
          gap(8),
          small(
            p.lowerBmiThresholds
                ? 'South Asian / other listed background bands: under 18.5; healthy 18.5–<23; overweight 23–<27.5; obesity 27.5+.'
                : 'Standard adult bands: under 18.5; healthy 18.5–<25; overweight 25–<30; obesity 30+.',
          ),
          gap(12),
          Text(guidance),
          gap(14),
          Text(
            'Current target: ${p.calories} kcal · ${p.protein} g protein / day',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          small(
            'Estimated maintenance: ${p.maintenanceCalories} kcal. Targets are starting estimates, not measurements of your metabolism.',
          ),
          if (under && p.calories < p.maintenanceCalories) ...[
            gap(8),
            const Text(
              'Your current target is below estimated maintenance while your BMI is underweight. Review this with a dietitian before using a weight-loss target.',
              style: TextStyle(color: orange),
            ),
          ],
          if (p.fatLossGoal && !under) ...[
            gap(12),
            small(
              'Your selected fat-loss goal starts about 250 kcal below estimated maintenance, within app bounds. Core training helps strength; overall fat loss changes waist size. No exercise can choose where your body loses fat.',
            ),
          ],
          gap(12),
          const Text(
            'Food starting points',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          small(
            under
                ? 'Build meals from eggs, dal/chana, chicken or fish, dahi/milk, roti/rice, fruit and vegetables. Add food gradually using milk, nuts or larger meal portions.'
                : p.fatLossGoal
                ? 'Keep protein in each meal (eggs, dal/chana, chicken/fish or dahi), add vegetables and fruit, and use roti/rice portions that fit your calorie target. Measure cooking oil; reduce sugary drinks if they add excess calories. You do not need to ban carbohydrates.'
                : 'Include protein, vegetables/fruit, roti/rice or other carbohydrates and some healthy fats. Use the food guide to compare affordable options and portions.',
          ),
          gap(12),
          const Text(
            'Movement starting points',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          small(
            'Follow your ${p.days}-day strength rotation using ${p.equipment.toLowerCase()}. Start walking or cycling with 5–10 comfortable minutes if inactive; build gradually toward 150 minutes of moderate activity per week. Choose low-impact options when jumping or running is uncomfortable.',
          ),
          if (p.goal == 'Reduce waist / belly fat') ...[
            gap(8),
            small(
              'Your waist-focus rotation includes core stability work. It strengthens the abdomen; it does not burn fat only from the belly.',
            ),
          ],
          if (onUseTarget != null) ...[
            gap(12),
            OutlinedButton(
              onPressed: () => onUseTarget!(target),
              child: Text(
                under
                    ? 'Use gradual-gain start · $target kcal'
                    : 'Use goal-based start · $target kcal',
              ),
            ),
          ],
          gap(12),
          small(
            'Adult screening only: BMI does not measure body fat, muscle or overall health. Pregnancy and some medical conditions need different assessment. Your chosen calorie target changes only when you select a target or edit it.',
          ),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(
                under
                    ? 'https://www.nhs.uk/live-well/healthy-weight/managing-your-weight/healthy-ways-to-gain-weight/'
                    : 'https://www.nhs.uk/conditions/overweight-and-obesity/',
              ),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('BMI & weight guidance · NHS'),
          ),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(
                'https://www.cdc.gov/physical-activity-basics/guidelines/adults.html',
              ),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Activity guidance · CDC'),
          ),
        ],
      ),
    );
  }
}
