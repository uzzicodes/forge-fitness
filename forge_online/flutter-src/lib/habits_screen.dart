import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'rank_card.dart';
import 'main.dart' show muted, gap, small, box, heading;

const habitIdeas = <Map<String, String>>[
  {
    'id': 'walk',
    'title': 'Take a short walk',
    'detail': 'An easy 10-minute walk, at a pace that suits you.',
    'group': 'Movement',
  },
  {
    'id': 'read',
    'title': 'Read for 10 minutes',
    'detail': 'A book, a useful article, anything you enjoy.',
    'group': 'Focus',
  },
  {
    'id': 'wind-down',
    'title': 'Make time to wind down',
    'detail': 'Choose a small evening routine you can repeat.',
    'group': 'Recovery',
  },
  {
    'id': 'plan',
    'title': 'Plan one thing for tomorrow',
    'detail': 'Keep tomorrow’s first step small and clear.',
    'group': 'Focus',
  },
  {
    'id': 'brush',
    'title': 'Brush before bed',
    'detail': 'Try two minutes with fluoride toothpaste.',
    'group': 'Daily care',
  },
  {
    'id': 'face',
    'title': 'Gentle face care',
    'detail': 'Use a gentle cleanser. Avoid harsh scrubbing.',
    'group': 'Daily care',
  },
  {
    'id': 'sun',
    'title': 'Sun protection outdoors',
    'detail': 'Consider shade, clothing and broad-spectrum SPF 30+.',
    'group': 'Daily care',
  },
];

class HabitsView extends StatefulWidget {
  final AppStore store;
  final DateTime date;
  const HabitsView({super.key, required this.store, required this.date});
  @override
  State<HabitsView> createState() => _HabitsViewState();
}

class _HabitsViewState extends State<HabitsView> {
  AppStore get s => widget.store;
  Future<void> custom() async {
    final title = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('A habit that fits your life'),
        content: TextField(
          controller: title,
          maxLength: 60,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Habit name',
            hintText: 'e.g. Practice a skill for 10 minutes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isNotEmpty) {
                Navigator.pop(ctx, title.text.trim());
              }
            },
            child: const Text('Start this habit'),
          ),
        ],
      ),
    );
    title.dispose();
    if (value != null) {
      await s.setHabit(
        'custom-${DateTime.now().microsecondsSinceEpoch}',
        value,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = s.habits.entries
        .where((h) => (h.value as Map)['enabled'] == true)
        .toList();
    final logs = s.habitLogs[dayKey(widget.date)] as Map? ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RankCard(store: s),
        heading(
          'Your daily quests',
          subtitle:
              'Choose your habits. These are optional, and rest still counts.',
          action: TextButton.icon(
            onPressed: active.length >= 10 ? null : custom,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Custom'),
          ),
        ),
        if (active.isEmpty)
          box(
            const Text(
              'Start with one habit below. You can add more when it feels easy.',
              style: TextStyle(color: muted),
            ),
          ),
        ...active.map(
          (h) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: box(
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text((h.value as Map)['title'] as String),
                      subtitle: Text(
                        '${s.streak(DateTime.now(), habitId: h.key)} day streak · +10 XP',
                      ),
                      value: logs[h.key] == true,
                      onChanged: (v) =>
                          s.checkHabit(widget.date, h.key, v == true),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Pause habit',
                    onPressed: () => s.setHabit(
                      h.key,
                      (h.value as Map)['title'] as String,
                      enabled: false,
                    ),
                    icon: const Icon(Icons.pause_circle_outline, color: muted),
                  ),
                ],
              ),
            ),
          ),
        ),
        heading(
          'Find your next small habit',
          subtitle: 'Suggestions, not rules. Pick only what helps you.',
        ),
        ...habitIdeas
            .where((h) => s.habits[h['id']]?['enabled'] != true)
            .map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: box(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            small(h['group']!),
                            gap(6),
                            Text(
                              h['title']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            gap(5),
                            Text(
                              h['detail']!,
                              style: const TextStyle(color: muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: active.length >= 10
                            ? null
                            : () => s.setHabit(h['id']!, h['title']!),
                        child: const Text('Start'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        heading('Simple care. No pressure.'),
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Skin care can support comfort and skin health. It does not promise a different face shape. Start gently and skip products that irritate your skin.',
                style: TextStyle(color: muted),
              ),
              gap(10),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.aad.org/public/everyday-care/skin-care-basics/care/face-washing-101',
                  ),
                ),
                child: const Text('Gentle cleansing · AAD ↗'),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://www.aad.org/media/stats-sunscreen'),
                ),
                child: const Text('Sun protection · AAD ↗'),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.nhs.uk/live-well/healthy-teeth-and-gums/how-to-keep-your-teeth-clean/',
                  ),
                ),
                child: const Text('Daily dental care · NHS ↗'),
              ),
            ],
          ),
        ),
        gap(24),
      ],
    );
  }
}
