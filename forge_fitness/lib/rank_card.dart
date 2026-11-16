import 'package:flutter/material.dart';
import 'models.dart';
import 'ranks.dart';
import 'check_in.dart';
import 'main.dart' show box, gap, small, ink, muted;

const rankColors = <Color>[
  Color(0xFFA6AAA9),
  Color(0xFFCE956A),
  Color(0xFFD4E0ED),
  Color(0xFFFFD06E),
  Color(0xFF65D7CB),
  Color(0xFFB7A6FF),
  Color(0xFF83E89F),
  Color(0xFFFF7E93),
  Color(0xFFFFEEA8),
];

/// Original angular emblems: a distinct silhouette and metal for every tier.
class RankBadge extends StatelessWidget {
  final FitnessRank rank;
  final double size;
  const RankBadge({super.key, required this.rank, this.size = 66});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${rank.name} rank badge',
    image: true,
    child: CustomPaint(size: Size.square(size), painter: _BadgePainter(rank)),
  );
}

class _BadgePainter extends CustomPainter {
  final FitnessRank rank;
  _BadgePainter(this.rank);
  @override
  void paint(Canvas canvas, Size size) {
    final color = rankColors[rank.tierIndex];
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    Path polygon(List<Offset> points) => Path()..addPolygon(points, true);
    void plate(List<Offset> points, {bool dark = false}) {
      final path = polygon(points);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [color.withValues(alpha: .38), color.withValues(alpha: .12)]
                : [
                    Color.lerp(color, Colors.white, .65)!,
                    color,
                    Color.lerp(color, Colors.black, .32)!,
                  ],
          ).createShader(const Rect.fromLTWH(8, 0, 84, 90)),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // A shadowed backing makes the small emblem readable against any panel.
    final backdrop = polygon(const [
      Offset(50, 4),
      Offset(90, 26),
      Offset(83, 65),
      Offset(50, 88),
      Offset(17, 65),
      Offset(10, 26),
    ]);
    canvas.drawPath(backdrop, Paint()..color = color.withValues(alpha: .08));
    switch (rank.tierIndex) {
      case 0: // Iron: a solid forged chevron.
        plate(const [
          Offset(22, 30),
          Offset(50, 17),
          Offset(78, 30),
          Offset(70, 61),
          Offset(50, 77),
          Offset(30, 61),
        ], dark: true);
        plate(const [
          Offset(27, 35),
          Offset(50, 47),
          Offset(73, 35),
          Offset(69, 51),
          Offset(50, 64),
          Offset(31, 51),
        ]);
      case 1: // Bronze: paired blades around a central crest.
        plate(const [
          Offset(12, 24),
          Offset(39, 36),
          Offset(43, 65),
          Offset(25, 55),
        ]);
        plate(const [
          Offset(88, 24),
          Offset(61, 36),
          Offset(57, 65),
          Offset(75, 55),
        ]);
        plate(const [
          Offset(50, 16),
          Offset(63, 39),
          Offset(50, 77),
          Offset(37, 39),
        ]);
      case 2: // Silver: three feathered wings.
        for (var i = 0; i < 3; i++) {
          final y = 22.0 + i * 13;
          plate([
            Offset(9 + i * 4, y),
            Offset(44, y + 14),
            Offset(44, y + 25),
            Offset(20 + i * 4, y + 13),
          ]);
          plate([
            Offset(91 - i * 4, y),
            Offset(56, y + 14),
            Offset(56, y + 25),
            Offset(80 - i * 4, y + 13),
          ]);
        }
        plate(const [
          Offset(50, 14),
          Offset(60, 37),
          Offset(50, 75),
          Offset(40, 37),
        ]);
      case 3: // Gold: a crown and a floating lower facet.
        plate(const [
          Offset(13, 24),
          Offset(34, 38),
          Offset(50, 9),
          Offset(66, 38),
          Offset(87, 24),
          Offset(74, 61),
          Offset(26, 61),
        ]);
        plate(const [
          Offset(28, 67),
          Offset(72, 67),
          Offset(50, 81),
        ], dark: true);
      case 4: // Platinum: an open diamond with side wings.
        plate(const [
          Offset(50, 8),
          Offset(77, 38),
          Offset(50, 79),
          Offset(23, 38),
        ], dark: true);
        plate(const [
          Offset(50, 19),
          Offset(64, 38),
          Offset(50, 63),
          Offset(36, 38),
        ]);
        plate(const [
          Offset(6, 31),
          Offset(25, 40),
          Offset(35, 67),
          Offset(16, 56),
        ]);
        plate(const [
          Offset(94, 31),
          Offset(75, 40),
          Offset(65, 67),
          Offset(84, 56),
        ]);
      case 5: // Diamond: a cut gemstone with split facets.
        plate(const [
          Offset(29, 14),
          Offset(71, 14),
          Offset(88, 36),
          Offset(50, 80),
          Offset(12, 36),
        ]);
        plate(const [
          Offset(29, 14),
          Offset(50, 36),
          Offset(12, 36),
        ], dark: true);
        plate(const [
          Offset(71, 14),
          Offset(50, 36),
          Offset(88, 36),
        ], dark: true);
        plate(const [
          Offset(35, 36),
          Offset(65, 36),
          Offset(50, 80),
        ], dark: true);
      case 6: // Ascendant: an upright crystal and outward blades.
        plate(const [
          Offset(50, 4),
          Offset(68, 36),
          Offset(50, 76),
          Offset(32, 36),
        ]);
        plate(const [
          Offset(12, 18),
          Offset(31, 32),
          Offset(39, 69),
          Offset(21, 57),
        ], dark: true);
        plate(const [
          Offset(88, 18),
          Offset(69, 32),
          Offset(61, 69),
          Offset(79, 57),
        ], dark: true);
        plate(const [
          Offset(9, 39),
          Offset(24, 49),
          Offset(34, 74),
          Offset(16, 62),
        ]);
        plate(const [
          Offset(91, 39),
          Offset(76, 49),
          Offset(66, 74),
          Offset(84, 62),
        ]);
      case 7: // Immortal: a ruby crest framed by angular horns.
        plate(const [
          Offset(8, 9),
          Offset(32, 29),
          Offset(37, 55),
          Offset(20, 45),
        ]);
        plate(const [
          Offset(92, 9),
          Offset(68, 29),
          Offset(63, 55),
          Offset(80, 45),
        ]);
        plate(const [
          Offset(50, 13),
          Offset(73, 43),
          Offset(50, 81),
          Offset(27, 43),
        ]);
        plate(const [
          Offset(50, 30),
          Offset(60, 44),
          Offset(50, 65),
          Offset(40, 44),
        ], dark: true);
      case 8: // Radiant: a luminous star, surrounded by four rays.
        plate(const [
          Offset(50, 4),
          Offset(61, 30),
          Offset(84, 42),
          Offset(61, 54),
          Offset(50, 82),
          Offset(39, 54),
          Offset(16, 42),
          Offset(39, 30),
        ]);
        plate(const [
          Offset(50, 26),
          Offset(61, 42),
          Offset(50, 61),
          Offset(39, 42),
        ], dark: true);
        for (final points in const [
          [Offset(18, 8), Offset(31, 21), Offset(30, 30), Offset(22, 27)],
          [Offset(82, 8), Offset(69, 21), Offset(70, 30), Offset(78, 27)],
          [Offset(10, 62), Offset(31, 58), Offset(32, 66), Offset(20, 75)],
          [Offset(90, 62), Offset(69, 58), Offset(68, 66), Offset(80, 75)],
        ]) {
          plate(points);
        }
    }
    // I / II / III division pips sit below the tier silhouette.
    for (var i = 0; i < rank.division; i++) {
      final x = 50.0 + (i - (rank.division - 1) / 2) * 12;
      plate([
        Offset(x, 86),
        Offset(x + 4, 91),
        Offset(x, 96),
        Offset(x - 4, 91),
      ]);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.rank != rank;
}

class RankHeader extends StatelessWidget {
  final AppStore store;
  const RankHeader({super.key, required this.store});
  @override
  Widget build(BuildContext context) {
    final p = RankProgress(store.totalXp),
        color = rankColors[p.current.tierIndex];
    return Semantics(
      button: true,
      label: 'View your rank and rank ladder',
      child: Material(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showRankLadder(context, store.totalXp),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: .25)),
            ),
            child: Row(
              children: [
                RankBadge(rank: p.current, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.current.name,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontSize: 19,
                              ),
                            ),
                          ),
                          Text(
                            '${store.totalXp} XP',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      gap(7),
                      LinearProgressIndicator(
                        value: p.fraction,
                        color: color,
                        backgroundColor: ink,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      gap(5),
                      small(
                        p.next == null
                            ? 'Radiant · highest rank'
                            : '${p.remaining} XP to ${p.next!.name}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RankCard extends StatelessWidget {
  final AppStore store;
  final bool compact;
  const RankCard({super.key, required this.store, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final progress = RankProgress(store.totalXp), rank = progress.current;
    final color = rankColors[rank.tierIndex];
    return box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RankBadge(rank: rank, size: compact ? 54 : 76),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    small('YOUR FORGE RANK'),
                    gap(4),
                    Text(
                      rank.name,
                      style: TextStyle(
                        fontSize: compact ? 23 : 30,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      '${store.totalXp} rank XP',
                      style: const TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          gap(16),
          LinearProgressIndicator(
            value: progress.fraction,
            color: color,
            backgroundColor: ink,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          gap(8),
          Text(
            progress.next == null
                ? 'Radiant reached. Every workout still earns XP.'
                : '${progress.remaining} XP to ${progress.next!.name}',
            style: TextStyle(color: color),
          ),
          gap(8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              const Text(
                'Complete a workout · +60 XP',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              TextButton.icon(
                onPressed: () => showRankLadder(context, store.totalXp),
                icon: const Icon(Icons.leaderboard_outlined, size: 18),
                label: const Text('View all ranks'),
              ),
            ],
          ),
          if (!compact) ...[
            gap(6),
            small('${store.streak(DateTime.now())} day activity streak'),
            gap(8),
            small(
              '${store.earnedXp} earned · ${store.deductedXp} weekly deductions. Rest days can be made up before Sunday ends.',
            ),
            TextButton.icon(
              onPressed: () => openCheckIn(context, store, store.xpToday()),
              icon: const Icon(Icons.insights_outlined, size: 18),
              label: const Text('Daily check-in & weekly XP'),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('How XP works', style: TextStyle(fontSize: 13)),
              children: [
                small(
                  'Completed workout: 60 XP. Meal log: 10 XP per day. Water log: 10 XP per day. Chosen recovery day: 5 XP. Each completed habit: 10 XP per day. Extra food or water earns no extra XP. Completed weeks may deduct XP for missing the saved training and fuel targets, with a 120 XP weekly cap and zero floor. New scoring starts next Monday. See your weekly scorecard for the full rules and recovery-week option. Ranks track your app activity.',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showRankLadder(BuildContext context, int xp) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'The climb to Radiant',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: small('$xp rank XP · 25 ranks to work toward'),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: fitnessRanks.length,
                  itemBuilder: (context, i) {
                    final rank = fitnessRanks[i],
                        current = RankProgress(xp).index == i,
                        unlocked = xp >= rank.minimumXp;
                    return ListTile(
                      selected: current,
                      leading: RankBadge(rank: rank, size: 44),
                      title: Text(
                        rank.name,
                        style: TextStyle(
                          color: unlocked ? rankColors[rank.tierIndex] : muted,
                          fontWeight: current
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text('${rank.minimumXp} XP'),
                      trailing: current
                          ? const Chip(label: Text('YOU'))
                          : Icon(
                              unlocked
                                  ? Icons.check_circle_outline
                                  : Icons.lock_outline,
                              color: muted,
                              size: 19,
                            ),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to FORGE'),
              ),
            ],
          ),
        ),
      ),
    );

Future<void> showWorkoutReward(
  BuildContext context, {
  required int before,
  required int after,
}) {
  final oldRank = RankProgress(before),
      progress = RankProgress(after),
      gained = after - before;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        progress.index > oldRank.index ? 'RANK UP!' : 'Workout complete!',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RankBadge(rank: progress.current, size: 100),
          gap(16),
          Text(
            '+$gained XP',
            style: TextStyle(
              color: rankColors[progress.current.tierIndex],
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          gap(6),
          Text(
            progress.current.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          gap(12),
          Text(
            progress.next == null
                ? 'Radiant reached. Keep building your strength.'
                : '${progress.remaining} XP to ${progress.next!.name}',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep going'),
        ),
      ],
    ),
  );
}
