import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Parsed GitHub event for rich activity display.
class GitHubActivityEvent {
  final String id;
  final String type;
  final String actorLogin;
  final String actorAvatarUrl;
  final String repoName;
  final DateTime createdAt;

  // PushEvent specific
  final int? commitCount;
  final List<Map<String, String>> commits; // message, sha
  final String? branch;
  final int? additions;
  final int? deletions;

  // PR specific
  final String? prTitle;
  final int? prNumber;
  final String? prAction; // opened, closed, merged
  final String? prBody;

  // Issue / Comment specific
  final String? issueTitle;
  final int? issueNumber;
  final String? commentBody;

  // Release specific
  final String? releaseTagName;
  final String? releaseName;

  // Fork / Star / Create
  final String? refType; // branch, tag, repository
  final String? ref;

  // AI summary
  final List<String> aiSummaryBullets;

  // Computed
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  String get timeOnly {
    final h = createdAt.toLocal().hour.toString().padLeft(2, '0');
    final m = createdAt.toLocal().minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get actionDescription {
    switch (type) {
      case 'PushEvent':
        final count = commitCount ?? commits.length;
        return 'pushed $count commit${count == 1 ? '' : 's'} to';
      case 'PullRequestEvent':
        if (prAction == 'merged' || prAction == 'closed') {
          return '${prAction ?? 'updated'} PR #${prNumber ?? ''} in';
        }
        return 'opened PR #${prNumber ?? ''} in';
      case 'PullRequestReviewEvent':
        return 'reviewed a PR in';
      case 'CreateEvent':
        return 'created ${refType ?? 'repository'}${ref != null ? ' $ref in' : ''}';
      case 'ForkEvent':
        return 'forked';
      case 'WatchEvent':
        return 'starred';
      case 'ReleaseEvent':
        return 'released ${releaseTagName ?? ''} of';
      case 'IssueCommentEvent':
        return 'commented on #${issueNumber ?? ''} in';
      case 'IssuesEvent':
        return 'opened issue #${issueNumber ?? ''} in';
      case 'DeleteEvent':
        return 'deleted ${refType ?? 'branch'} in';
      default:
        return 'interacted with';
    }
  }

  String get displayTitle {
    if (type == 'PushEvent' && commits.isNotEmpty) {
      return commits.first['message'] ?? 'No commit message';
    }
    if (type == 'PullRequestEvent') return prTitle ?? 'Pull Request';
    if (type == 'IssueCommentEvent' || type == 'IssuesEvent') {
      return issueTitle ?? 'Issue';
    }
    if (type == 'ReleaseEvent') return releaseName ?? releaseTagName ?? 'Release';
    if (type == 'CreateEvent') return ref ?? repoName.split('/').last;
    return repoName.split('/').last;
  }

  GitHubActivityEvent({
    required this.id,
    required this.type,
    required this.actorLogin,
    required this.actorAvatarUrl,
    required this.repoName,
    required this.createdAt,
    this.commitCount,
    this.commits = const [],
    this.branch,
    this.additions,
    this.deletions,
    this.prTitle,
    this.prNumber,
    this.prAction,
    this.prBody,
    this.issueTitle,
    this.issueNumber,
    this.commentBody,
    this.releaseTagName,
    this.releaseName,
    this.refType,
    this.ref,
    this.aiSummaryBullets = const [],
  });

  /// Parse a raw GitHub Events API response item.
  factory GitHubActivityEvent.fromGitHubApi(Map<String, dynamic> raw) {
    final payload = raw['payload'] as Map<String, dynamic>? ?? {};
    final actor = raw['actor'] as Map<String, dynamic>? ?? {};
    final repo = raw['repo'] as Map<String, dynamic>? ?? {};
    final type = raw['type'] as String? ?? 'Unknown';

    List<Map<String, String>> commits = [];
    int? commitCount;
    String? branch;
    int? additions;
    int? deletions;
    String? prTitle;
    int? prNumber;
    String? prAction;
    String? prBody;
    String? issueTitle;
    int? issueNumber;
    String? commentBody;
    String? releaseTagName;
    String? releaseName;
    String? refType;
    String? ref;
    List<String> aiSummary = [];

    switch (type) {
      case 'PushEvent':
        final rawCommits = payload['commits'] as List<dynamic>? ?? [];
        commitCount = payload['size'] as int? ?? rawCommits.length;
        branch = (payload['ref'] as String?)?.replaceFirst('refs/heads/', '');
        commits = rawCommits.map((c) {
          final msg = (c['message'] as String? ?? '').split('\n').first;
          return {
            'message': msg.isNotEmpty ? msg : 'Code update',
            'sha': (c['sha'] as String? ?? '').substring(0, 7.clamp(0, (c['sha'] as String? ?? '').length)),
          };
        }).toList();
        // Generate AI-like summary from commit messages
        for (final c in commits.take(3)) {
          final msg = c['message'] ?? '';
          if (msg.isNotEmpty && msg != 'Code update') {
            aiSummary.add(msg);
          }
        }
        break;

      case 'PullRequestEvent':
        final pr = payload['pull_request'] as Map<String, dynamic>? ?? {};
        prTitle = pr['title'] as String?;
        prNumber = payload['number'] as int? ?? pr['number'] as int?;
        prAction = payload['action'] as String?;
        if (pr['merged'] == true) prAction = 'merged';
        prBody = pr['body'] as String?;
        additions = pr['additions'] as int?;
        deletions = pr['deletions'] as int?;
        break;

      case 'IssueCommentEvent':
        final issue = payload['issue'] as Map<String, dynamic>? ?? {};
        final comment = payload['comment'] as Map<String, dynamic>? ?? {};
        issueTitle = issue['title'] as String?;
        issueNumber = issue['number'] as int?;
        commentBody = comment['body'] as String?;
        break;

      case 'IssuesEvent':
        final issue = payload['issue'] as Map<String, dynamic>? ?? {};
        issueTitle = issue['title'] as String?;
        issueNumber = issue['number'] as int?;
        break;

      case 'ReleaseEvent':
        final release = payload['release'] as Map<String, dynamic>? ?? {};
        releaseTagName = release['tag_name'] as String?;
        releaseName = release['name'] as String?;
        break;

      case 'CreateEvent':
        refType = payload['ref_type'] as String?;
        ref = payload['ref'] as String?;
        break;

      case 'ForkEvent':
        break;

      case 'WatchEvent':
        break;
    }

    DateTime createdAt;
    try {
      createdAt = DateTime.parse(raw['created_at'] as String? ?? '');
    } catch (_) {
      createdAt = DateTime.now();
    }

    return GitHubActivityEvent(
      id: raw['id']?.toString() ?? '',
      type: type,
      actorLogin: actor['login'] as String? ?? 'unknown',
      actorAvatarUrl: actor['avatar_url'] as String? ?? '',
      repoName: repo['name'] as String? ?? 'unknown/repo',
      createdAt: createdAt,
      commitCount: commitCount,
      commits: commits,
      branch: branch,
      additions: additions,
      deletions: deletions,
      prTitle: prTitle,
      prNumber: prNumber,
      prAction: prAction,
      prBody: prBody,
      issueTitle: issueTitle,
      issueNumber: issueNumber,
      commentBody: commentBody,
      releaseTagName: releaseTagName,
      releaseName: releaseName,
      refType: refType,
      ref: ref,
      aiSummaryBullets: aiSummary,
    );
  }

  /// Convert from the existing backend format (followingActivity)
  factory GitHubActivityEvent.fromBackendFormat(Map<String, dynamic> raw) {
    final type = raw['type'] as String? ?? 'PushEvent';
    final actorName = raw['actor_name'] as String? ??
        (raw['actor'] is Map ? raw['actor']['login'] : null) ??
        'Unknown';
    final actorAvatar = raw['actor_avatar'] as String? ??
        (raw['actor'] is Map ? raw['actor']['avatar_url'] : null) ??
        '';
    final repoName = raw['repo_name'] as String? ??
        (raw['repo'] is Map ? raw['repo']['name'] : null) ??
        'Unknown';

    DateTime createdAt;
    try {
      createdAt = DateTime.parse(raw['created_at'] as String? ?? '');
    } catch (_) {
      createdAt = DateTime.now();
    }

    final title = raw['title'] as String? ?? '';
    final body = raw['description'] as String? ?? (raw['body'] as String? ?? '');
    final actionType = raw['action_type'] as String? ?? '';
    final action = raw['action'] as String? ?? '';

    String? prAction;
    String? prTitle;
    int? prNumber;
    String? issueTitle;
    int? issueNumber;
    String? commentBody;
    String? ref;
    String? refType;
    String eventType = type;

    if (actionType == 'pr' || type == 'PullRequestEvent') {
      eventType = 'PullRequestEvent';
      prTitle = title;
      prAction = action;
      final prMatch = RegExp(r'#(\d+)').firstMatch(title);
      if (prMatch != null) prNumber = int.tryParse(prMatch.group(1)!);
    } else if (actionType == 'comment' || type == 'IssueCommentEvent') {
      eventType = 'IssueCommentEvent';
      issueTitle = title;
      commentBody = body;
    } else if (actionType == 'issue' || type == 'IssuesEvent') {
      eventType = 'IssuesEvent';
      issueTitle = title;
    } else if (actionType == 'star' || type == 'WatchEvent') {
      eventType = 'WatchEvent';
    } else if (actionType == 'fork' || type == 'ForkEvent') {
      eventType = 'ForkEvent';
    } else if (actionType == 'create' || type == 'CreateEvent') {
      eventType = 'CreateEvent';
      ref = title;
    } else if (actionType == 'release' || type == 'ReleaseEvent') {
      eventType = 'ReleaseEvent';
    }

    List<String> aiSummary = [];
    if (body.isNotEmpty) {
      // Split body into bullet points if it has them
      final lines = body.split('\n').where((l) => l.trim().isNotEmpty).take(3);
      for (final line in lines) {
        aiSummary.add(line.replaceFirst(RegExp(r'^[-•*]\s*'), ''));
      }
    }

    return GitHubActivityEvent(
      id: raw['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: eventType,
      actorLogin: actorName,
      actorAvatarUrl: actorAvatar,
      repoName: repoName,
      createdAt: createdAt,
      prTitle: prTitle,
      prNumber: prNumber,
      prAction: prAction,
      issueTitle: issueTitle,
      issueNumber: issueNumber,
      commentBody: commentBody,
      ref: ref,
      refType: refType,
      aiSummaryBullets: aiSummary,
    );
  }
}

/// Groups events by date category.
class GroupedEvents {
  final String label; // "Today", "Yesterday", "This Week", "Last Month", "Older"
  final List<GitHubActivityEvent> events;

  GroupedEvents({required this.label, required this.events});

  static List<GroupedEvents> groupByDay(List<GitHubActivityEvent> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    final Map<String, List<GitHubActivityEvent>> grouped = {};

    for (final event in events) {
      final eventDate = DateTime(event.createdAt.year, event.createdAt.month, event.createdAt.day);
      String label;

      if (eventDate == today || eventDate.isAfter(today)) {
        label = 'Today';
      } else if (eventDate == yesterday) {
        label = 'Yesterday';
      } else if (eventDate.isAfter(thisWeekStart)) {
        label = 'This Week';
      } else if (eventDate.isAfter(lastMonthStart)) {
        label = 'This Month';
      } else {
        label = 'Older';
      }

      grouped.putIfAbsent(label, () => []).add(event);
    }

    const order = ['Today', 'Yesterday', 'This Week', 'This Month', 'Older'];
    return order
        .where((label) => grouped.containsKey(label))
        .map((label) => GroupedEvents(label: label, events: grouped[label]!))
        .toList();
  }
}

/// Service for fetching GitHub events directly from GitHub API.
class GitHubEventsService {
  static const String _baseUrl = 'https://api.github.com';

  /// Fetch events for a specific user.
  static Future<List<GitHubActivityEvent>> fetchUserEvents(
    String username, {
    String? token,
    int perPage = 30,
  }) async {
    try {
      final headers = <String, String>{
        'Accept': 'application/vnd.github+json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/users/$username/events?per_page=$perPage'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawEvents = jsonDecode(response.body);
        return rawEvents
            .map((e) => GitHubActivityEvent.fromGitHubApi(e as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('GitHub Events API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching GitHub events: $e');
      return [];
    }
  }

  /// Fetch received events (events from people the user follows).
  static Future<List<GitHubActivityEvent>> fetchReceivedEvents(
    String username, {
    String? token,
    int perPage = 30,
  }) async {
    try {
      final headers = <String, String>{
        'Accept': 'application/vnd.github+json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/users/$username/received_events?per_page=$perPage'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawEvents = jsonDecode(response.body);
        return rawEvents
            .map((e) => GitHubActivityEvent.fromGitHubApi(e as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('GitHub Received Events API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching GitHub received events: $e');
      return [];
    }
  }
}
