class RoadmapMilestone {
  final String title;
  final String description;
  final bool isCompleted;
  final List<String> recommendations;

  RoadmapMilestone({
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.recommendations = const [],
  });
}

class CareerRoadmap {
  final String title;
  final String level;
  final List<RoadmapMilestone> milestones;

  CareerRoadmap({
    required this.title,
    required this.level,
    required this.milestones,
  });
}
