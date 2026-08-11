import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class TimelineEventData {
  final String timestamp;
  final String type;
  final String stageId;
  final String agentId;
  final String message;

  const TimelineEventData({
    required this.timestamp,
    this.type = 'info',
    this.stageId = '',
    this.agentId = '',
    required this.message,
  });
}

class PipelineTimeline extends StatelessWidget {
  final List<TimelineEventData> events;
  final int maxItems;

  const PipelineTimeline({
    super.key,
    required this.events,
    this.maxItems = 30,
  });

  Color _eventColor(String type) {
    switch (type) {
      case 'stage_started':
        return AppTheme.accent;
      case 'stage_completed':
        return AppTheme.success;
      case 'agent_status':
        return AppTheme.neonPurple;
      case 'step_completed':
        return AppTheme.neonGreen;
      case 'error':
        return AppTheme.destructive;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'stage_started':
        return Icons.play_arrow_rounded;
      case 'stage_completed':
        return Icons.check_circle_outline;
      case 'agent_status':
        return Icons.smart_toy_outlined;
      case 'step_completed':
        return Icons.task_alt;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.circle;
    }
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Text(
          'No events yet',
          style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 12),
        ),
      );
    }

    final displayEvents = events.length > maxItems
        ? events.sublist(events.length - maxItems)
        : events;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayEvents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final event = displayEvents[index];
        final color = _eventColor(event.type);
        final time = _formatTimestamp(event.timestamp);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                ),
              ),
            ),
            Icon(_eventIcon(event.type), size: 12, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                event.message,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMain.withValues(alpha: 0.85),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}
