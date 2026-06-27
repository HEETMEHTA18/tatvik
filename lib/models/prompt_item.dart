class PromptItem {
  final String id;
  final String originalPrompt;
  final String refinedPrompt;
  final int score;
  final List<String> technologies;
  final String workflow;
  final String? projectName;
  final DateTime createdAt;

  PromptItem({
    required this.id,
    required this.originalPrompt,
    required this.refinedPrompt,
    required this.score,
    required this.technologies,
    required this.workflow,
    this.projectName,
    required this.createdAt,
  });

  factory PromptItem.fromJson(Map<String, dynamic> json) {
    return PromptItem(
      id: json['id'] ?? '',
      originalPrompt: json['original_prompt'] ?? '',
      refinedPrompt: json['refined_prompt'] ?? '',
      score: json['score'] ?? 0,
      technologies: List<String>.from(json['technologies'] ?? []),
      workflow: json['workflow'] ?? 'Development',
      projectName: json['project_name'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
