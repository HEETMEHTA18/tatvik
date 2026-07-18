import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class PipelineStageData {
  final String id;
  final String name;
  final String status;
  final double progress;
  final String message;
  final List<Map<String, String>> steps;

  const PipelineStageData({
    required this.id,
    required this.name,
    required this.status,
    this.progress = 0.0,
    this.message = '',
    this.steps = const [],
  });
}

class PipelineFlow extends StatefulWidget {
  final List<PipelineStageData> stages;
  final String activePhase;

  const PipelineFlow({
    super.key,
    required this.stages,
    this.activePhase = '',
  });

  @override
  State<PipelineFlow> createState() => _PipelineFlowState();
}

class _PipelineFlowState extends State<PipelineFlow>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'running':
        return AppTheme.accent;
      case 'done':
        return AppTheme.success;
      case 'failed':
        return AppTheme.destructive;
      default:
        return AppTheme.textSecondary.withValues(alpha: 0.4);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'running':
        return Icons.play_circle_filled;
      case 'done':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stages.isEmpty) {
      return Center(
        child: Text(
          'No active pipeline',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PIPELINE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.stages.length,
            separatorBuilder: (_, _) => _buildConnector(),
            itemBuilder: (context, index) {
              final stage = widget.stages[index];
              return _buildStage(stage, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConnector() {
    return AnimatedBuilder(
      listenable: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 28,
          alignment: Alignment.center,
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: AppTheme.textSecondary.withValues(alpha: _pulseAnimation.value * 0.5),
          ),
        );
      },
    );
  }

  Widget _buildStage(PipelineStageData stage, int index) {
    final color = _statusColor(stage.status);
    final isRunning = stage.status == 'running';

    return AnimatedBuilder(
      listenable: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isRunning ? 0.15 : 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: isRunning ? 0.6 : 0.2),
              width: isRunning ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _statusIcon(stage.status),
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      stage.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: stage.progress / 100,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                stage.message.isNotEmpty
                    ? stage.message
                    : stage.status == 'pending'
                        ? 'Awaiting...'
                        : stage.status == 'done'
                            ? 'Complete'
                            : stage.status == 'failed'
                                ? 'Failed'
                                : '${stage.progress.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => builder(context, null);
}
