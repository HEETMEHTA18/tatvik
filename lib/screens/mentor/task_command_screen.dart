import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/app_config.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_glass_button.dart';
import '../../widgets/pipeline_flow.dart';
import '../../widgets/agent_status_card.dart';
import '../../widgets/pipeline_timeline.dart';

class TaskCommandScreen extends StatefulWidget {
  const TaskCommandScreen({super.key});

  @override
  State<TaskCommandScreen> createState() => _TaskCommandScreenState();
}

class _TaskCommandScreenState extends State<TaskCommandScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String _priority = 'medium';
  String _deadline = '';
  String _repository = 'HeetMehta18/AutoDevs';

  bool _isCreating = false;
  bool _hasMission = false;

  Map<String, dynamic>? _pipelineData;
  bool _isPolling = false;

  final List<String> _repos = [
    'HeetMehta18/AutoDevs',
    'HeetMehta18/DevMentor',
    'HeetMehta18/Portfolio',
  ];

  final List<String> _priorities = ['low', 'medium', 'high', 'critical'];

  @override
  void initState() {
    super.initState();
    _fetchPipeline();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchPipeline() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/openclaw/pipeline/status'),
        headers: {
          if (appState.token != null) 'Authorization': 'Bearer ${appState.token}',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _pipelineData = data;
          _hasMission = data['pipeline']?['mission']?['title']?.isNotEmpty == true &&
              data['pipeline']?['mission']?['status'] != 'idle';
        });
      }
    } catch (_) {}
  }

  Future<void> _createMission() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isCreating = true);

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/openclaw/missions'),
        headers: {
          'Content-Type': 'application/json',
          if (appState.token != null) 'Authorization': 'Bearer ${appState.token}',
        },
        body: jsonEncode({
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'priority': _priority,
          'deadline': _deadline,
          'repository': 'https://github.com/$_repository',
          'execute': true,
        }),
      );
      if (res.statusCode == 200) {
        setState(() => _hasMission = true);
        _titleController.clear();
        _descController.clear();
        _startPolling();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create mission: $e')),
        );
      }
    }
    setState(() => _isCreating = false);
  }

  void _startPolling() {
    _isPolling = true;
    _pollLoop();
  }

  Future<void> _pollLoop() async {
    while (_isPolling && mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || !_isPolling) break;
      await _fetchPipeline();
    }
  }

  Future<void> _cancelMission() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/openclaw/missions/cancel'),
        headers: {
          if (appState.token != null) 'Authorization': 'Bearer ${appState.token}',
        },
      );
    } catch (_) {}
    _isPolling = false;
    setState(() {
      _hasMission = false;
      _pipelineData = null;
    });
  }

  List<PipelineStageData> _parseStages() {
    final stages = _pipelineData?['pipeline']?['stages'];
    if (stages == null || stages is! List) return [];
    return stages.map<PipelineStageData>((s) {
      final steps = (s['steps'] as List?)?.map<Map<String, String>>((st) {
        return {
          'step': st['step'] ?? '',
          'status': st['status'] ?? '',
          'tool_id': st['tool_id'] ?? '',
        };
      }).toList() ?? [];
      return PipelineStageData(
        id: s['id'] ?? '',
        name: s['name'] ?? '',
        status: s['status'] ?? 'pending',
        progress: (s['progress'] ?? 0).toDouble(),
        message: s['message'] ?? '',
        steps: steps,
      );
    }).toList();
  }

  List<AgentStatusData> _parseAgents() {
    final agents = _pipelineData?['pipeline']?['agents'];
    if (agents == null || agents is! List) return [];
    return agents.map<AgentStatusData>((a) {
      final logs = (a['logs'] as List?)?.map<String>((l) => l.toString()).toList() ?? [];
      return AgentStatusData(
        id: a['id'] ?? '',
        name: a['name'] ?? '',
        role: a['role'] ?? '',
        status: a['status'] ?? 'idle',
        currentTask: a['current_task'] ?? '',
        progress: (a['progress'] ?? 0).toDouble(),
        confidence: (a['confidence'] ?? 0).toDouble(),
        logs: logs,
      );
    }).toList();
  }

  List<TimelineEventData> _parseTimeline() {
    final events = _pipelineData?['pipeline']?['timeline'];
    if (events == null || events is! List) return [];
    return events.map<TimelineEventData>((e) => TimelineEventData(
      timestamp: e['timestamp'] ?? '',
      type: e['type'] ?? 'info',
      stageId: e['stage_id'] ?? '',
      agentId: e['agent_id'] ?? '',
      message: e['message'] ?? '',
    )).toList();
  }

  Map<String, dynamic>? get _mission => _pipelineData?['pipeline']?['mission'];

  @override
  Widget build(BuildContext context) {
    final stages = _parseStages();
    final agents = _parseAgents();
    final timeline = _parseTimeline();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _hasMission ? 'Tatvik Factory' : 'Command Center',
          style: GoogleFonts.spaceMono(
            color: AppTheme.neonPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textMain),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20),
            onPressed: _fetchPipeline,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_hasMission) ...[
              _buildMissionForm(),
            ] else ...[
              _buildMissionHeader(),
              const SizedBox(height: 20),
              _buildPipelineFlow(stages),
              const SizedBox(height: 20),
              _buildAgentGrid(agents),
              const SizedBox(height: 20),
              _buildTimeline(timeline),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMissionForm() {
    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.neonPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.rocket_launch, color: AppTheme.neonPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Mission',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                    ),
                  ),
                  Text(
                    'Define what you want built',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            style: TextStyle(color: AppTheme.textMain),
            decoration: _inputDecoration('Mission Title', 'e.g., Build AI Dashboard'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            maxLines: 3,
            style: TextStyle(color: AppTheme.textMain),
            decoration: _inputDecoration('Description', 'Describe what you want built...'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Priority', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: DropdownButton<String>(
                          value: _priority,
                          isExpanded: true,
                          dropdownColor: AppTheme.surfaceElevated,
                          icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.accent, size: 18),
                          style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                          items: _priorities.map((p) => DropdownMenuItem(
                            value: p,
                            child: Row(
                              children: [
                                Icon(
                                  p == 'critical' ? Icons.warning : Icons.flag,
                                  size: 14,
                                  color: p == 'critical' ? AppTheme.destructive : p == 'high' ? AppTheme.warning : AppTheme.accent,
                                ),
                                const SizedBox(width: 6),
                                Text(p[0].toUpperCase() + p.substring(1)),
                              ],
                            ),
                          )).toList(),
                          onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Repository', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: DropdownButton<String>(
                          value: _repository,
                          isExpanded: true,
                          dropdownColor: AppTheme.surfaceElevated,
                          icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.accent, size: 18),
                          style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                          items: _repos.map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r, style: TextStyle(fontSize: 12)),
                          )).toList(),
                          onChanged: (v) => setState(() => _repository = v ?? _repository),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LiquidGlassButton(
                onPressed: _isCreating ? null : _createMission,
                color: AppTheme.accent,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                child: _isCreating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Launch Mission',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMissionHeader() {
    final mission = _mission;
    if (mission == null) return const SizedBox.shrink();

    final status = mission['status'] ?? 'running';
    final isRunning = status == 'running';
    final isCompleted = status == 'completed';
    final isFailed = status == 'failed';

    Color statusColor = isRunning ? AppTheme.accent : isCompleted ? AppTheme.success : isFailed ? AppTheme.destructive : AppTheme.textSecondary;
    String statusLabel = isRunning ? 'In Progress' : isCompleted ? 'Completed' : isFailed ? 'Failed' : status;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.rocket_launch, color: statusColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission['title'] ?? 'Mission',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    if ((mission['description'] ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          mission['description'],
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isRunning)
                      SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(statusColor)),
                      ),
                    if (isRunning) const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (mission['priority'] != null || mission['repository'] != '') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (mission['priority'] != null && mission['priority'] != '') ...[
                  _metaChip(Icons.flag, mission['priority'], AppTheme.warning),
                  const SizedBox(width: 8),
                ],
                if (mission['repository'] != null && mission['repository'] != '') ...[
                  _metaChip(Icons.folder_open, mission['repository'].toString().split('/').last, AppTheme.neonGreen),
                  const SizedBox(width: 8),
                ],
                if (mission['created_at'] != null && mission['created_at'] != '') ...[
                  _metaChip(Icons.schedule, _formatDate(mission['created_at']), AppTheme.textSecondary),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isRunning)
                LiquidGlassButton(
                  onPressed: _cancelMission,
                  color: AppTheme.destructive.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Cancel', style: TextStyle(fontSize: 12, color: AppTheme.destructive, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label.length > 20 ? '${label.substring(0, 20)}...' : label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineFlow(List<PipelineStageData> stages) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: PipelineFlow(stages: stages, activePhase: _pipelineData?['pipeline']?['phase'] ?? ''),
    );
  }

  Widget _buildAgentGrid(List<AgentStatusData> agents) {
    if (agents.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AGENTS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppTheme.textSecondary),
              ),
              Text(
                '${agents.where((a) => a.status == 'working').length}/${agents.length} active',
                style: TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...agents.map((agent) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AgentStatusCard(agent: agent),
          )),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<TimelineEventData> events) {
    if (events.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TIMELINE',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          PipelineTimeline(events: events, maxItems: 20),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.4), fontSize: 13),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.neonPurple),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
