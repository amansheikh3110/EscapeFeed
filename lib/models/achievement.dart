enum AchievementId { firstStep, ironWill, digitalMonk, earlyBird, problemSolver }

class Achievement {
  final AchievementId id;
  final String name;
  final String description;
  final String emoji;
  final bool unlocked;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.unlocked,
  });

  static const List<Achievement> catalog = [
    Achievement(
      id: AchievementId.firstStep,
      name: 'First Step',
      description: 'Stay within all limits for one full day.',
      emoji: '🌱',
      unlocked: false,
    ),
    Achievement(
      id: AchievementId.ironWill,
      name: 'Iron Will',
      description: 'Reach a 7-day streak without breaking any limit.',
      emoji: '🔥',
      unlocked: false,
    ),
    Achievement(
      id: AchievementId.digitalMonk,
      name: 'Digital Monk',
      description: 'Maintain your streak for 30 consecutive days.',
      emoji: '🧘',
      unlocked: false,
    ),
    Achievement(
      id: AchievementId.earlyBird,
      name: 'Early Bird',
      description: 'Check in before noon while on a streak.',
      emoji: '🌅',
      unlocked: false,
    ),
    Achievement(
      id: AchievementId.problemSolver,
      name: 'Problem Solver',
      description: 'Earn extra time by completing a mindfulness exercise.',
      emoji: '🧩',
      unlocked: false,
    ),
  ];

  Achievement copyWith({bool? unlocked}) => Achievement(
        id: id,
        name: name,
        description: description,
        emoji: emoji,
        unlocked: unlocked ?? this.unlocked,
      );
}
