/// FORGE progression uses existing saved activity; no separate balance to drift.
class FitnessRank {
  final String tier;
  final int division, minimumXp, tierIndex;
  const FitnessRank(this.tier, this.division, this.minimumXp, this.tierIndex);
  String get name =>
      division == 0 ? tier : '$tier ${['I', 'II', 'III'][division - 1]}';
}

final fitnessRanks = List<FitnessRank>.unmodifiable(() {
  const tiers = [
    'Iron',
    'Bronze',
    'Silver',
    'Gold',
    'Platinum',
    'Diamond',
    'Ascendant',
    'Immortal',
  ];
  final ranks = <FitnessRank>[];
  var threshold = 0;
  for (var tier = 0; tier < tiers.length; tier++) {
    for (var division = 1; division <= 3; division++) {
      ranks.add(FitnessRank(tiers[tier], division, threshold, tier));
      threshold += 100 + tier * 50;
    }
  }
  ranks.add(FitnessRank('Radiant', 0, threshold, 8));
  return ranks;
}());

class RankProgress {
  final int xp;
  const RankProgress(this.xp);
  int get index => fitnessRanks
      .lastIndexWhere((rank) => xp >= rank.minimumXp)
      .clamp(0, fitnessRanks.length - 1);
  FitnessRank get current => fitnessRanks[index];
  FitnessRank? get next =>
      index + 1 < fitnessRanks.length ? fitnessRanks[index + 1] : null;
  int get remaining =>
      next == null ? 0 : (next!.minimumXp - xp).clamp(0, next!.minimumXp);
  double get fraction => next == null
      ? 1
      : ((xp - current.minimumXp) / (next!.minimumXp - current.minimumXp))
            .clamp(0, 1);
}
