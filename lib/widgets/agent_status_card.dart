import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class AgentStatusData {
  final String id;
  final String name;
  final String role;
  final String status;
  final String currentTask;
  final double progress;
  final double confidence;
  final List<String> logs;

  const AgentStatusData({
    required this.id,
    required this.name,
    required this.role,
    this.status = 'idle',
    this.currentTask = '',
    this.progress = 0.0,
    this.confidence = 0.0,
    this.logs = const [],
  });
}

class AgentStatusCard extends StatelessWidget {
  final AgentStatusData agent;
  final bool compact;

  const AgentStatusCard({
    super.key,
    required this.agent,
    this.compact = false,
  });

  Color _statusColor() {
    switch (agent.status) {
      case 'working':
        return AppTheme.accent;
      case 'done':
        return AppTheme.success;
      case 'failed':
        return AppTheme.destructive;
      default:
        return AppTheme.textSecondary.withValues(alpha: 0.4);
    }
  }

  String _statusLabel() {
    switch (agent.status) {
      case 'working':
        return 'Working';
      case 'done':
        return 'Done';
      case 'failed':
        return 'Failed';
      default:
        return 'Idle';
    }
  }

  IconData _roleIcon() {
    switch (agent.role.toLowerCase()) {
      case 'planner':
      case 'goal decomposition & workflow planning':
        return Icons.account_tree_rounded;
      case 'architect':
      case 'system architecture & design':
        return Icons.account_tree_outlined;
      case 'designer':
      case 'ui/ux design & component generation':
        return Icons.palette_outlined;
      case 'frontend':
      case 'react/flutter code generation':
        return Icons.code;
      case 'backend':
      case 'api & database generation':
        return Icons.dns_outlined;
      case 'qa':
      case 'testing & quality assurance':
        return Icons.bug_report_outlined;
      case 'devops':
      case 'build & deployment':
        return Icons.rocket_launch_outlined;
      default:
        return Icons.smart_toy_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: agent.status == 'working' ? 0.1 : 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: agent.status == 'working' ? 0.4 : 0.12),
          width: agent.status == 'working' ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_roleIcon(), size: compact ? 14 : 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  agent.name,
                  style: TextStyle(
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusLabel(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (!compact && agent.currentTask.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              agent.currentTask,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (agent.status == 'working' && !compact) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: agent.progress / 100,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 3,
              ),
            ),
          ],
          if (!compact && agent.confidence > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Confidence',
                  style: TextStyle(fontSize: 9, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                ),
                const Spacer(),
                Text(
                  '${agent.confidence.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: agent.confidence > 80
                        ? AppTheme.success
                        : agent.confidence > 50
                            ? AppTheme.warning
                            : AppTheme.destructive,
                  ),
                ),
              ],
            ),
          ],
          if (!compact && agent.logs.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...agent.logs.reversed.take(2).map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '> $log',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
