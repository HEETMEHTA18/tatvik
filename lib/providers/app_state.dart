import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/repository.dart';
import '../models/roadmap.dart';
import '../models/mentor_message.dart';
import '../core/config/app_config.dart';
import '../models/prompt_item.dart';
import '../utils/cookie_manager.dart';
import '../core/utils/web_helper.dart' as web_helper;

class AppState extends ChangeNotifier {
  AppState() {
    initPreferences();
  }

  static const String _githubPromptsOwner = 'HeetMehta18';
  static const String _githubPromptsRepo = 'AutoDevs';

  bool showLinkGitHubPrompt = false;
  bool isPreferencesLoaded = false;
  final ValueNotifier<int> authStateNotifier = ValueNotifier<int>(0);

  Future<void> initPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var storedToken = prefs.getString('auth_token');
      var storedUsername = prefs.getString('github_username');
      var storedDisplayName = prefs.getString('profile_display_name');
      var storedAvatarUrl = prefs.getString('github_avatar_url');
      var storedLoginTimestamp = prefs.getString('login_timestamp');

      if (kIsWeb && (storedToken == null || storedToken.isEmpty)) {
        final cookieToken = getCookie('auth_token');
        if (cookieToken != null && cookieToken.isNotEmpty) {
          storedToken = cookieToken;
          storedUsername = getCookie('github_username');
          storedDisplayName = getCookie('profile_display_name');
          storedAvatarUrl = getCookie('github_avatar_url');
          storedLoginTimestamp = getCookie('login_timestamp');

          // Re-sync back to SharedPreferences
          try {
            await prefs.setString('auth_token', storedToken);
            if (storedUsername != null)
              await prefs.setString('github_username', storedUsername);
            if (storedDisplayName != null)
              await prefs.setString('profile_display_name', storedDisplayName);
            if (storedAvatarUrl != null)
              await prefs.setString('github_avatar_url', storedAvatarUrl);
            if (storedLoginTimestamp != null)
              await prefs.setString('login_timestamp', storedLoginTimestamp);
          } catch (_) {}
        }
      }

      pushNotifications = prefs.getBool('pref_notifications') ?? true;
      aiInsights = prefs.getBool('pref_ai') ?? true;
      weeklyReport = prefs.getBool('pref_report') ?? false;
      shareAnalytics = prefs.getBool('pref_analytics') ?? true;
      twoFactorAuth = prefs.getBool('pref_2fa') ?? false;
      githubUsernameLocked = prefs.getBool('pref_github_locked') ?? false;

      // Immediately load cached GitHub statistics to avoid mock/zero flashes on app reopen
      commits = prefs.getInt('cached_commits') ?? 0;
      stars = prefs.getInt('cached_stars') ?? 0;
      repos = prefs.getInt('cached_repos') ?? 0;
      developerScore = prefs.getDouble('cached_developer_score') ?? 0.0;
      strengths = prefs.getStringList('cached_strengths') ?? [];
      gaps = prefs.getStringList('cached_gaps') ?? [];

      if (storedToken != null && storedToken.isNotEmpty) {
        token = storedToken;
        if (storedUsername != null && storedUsername.isNotEmpty) {
          githubUsername = storedUsername;
        }
        if (storedDisplayName != null && storedDisplayName.isNotEmpty) {
          username = storedDisplayName;
        } else if (githubUsername.isNotEmpty) {
          username = githubUsername;
        }
        if (storedAvatarUrl != null && storedAvatarUrl.isNotEmpty) {
          avatarUrl = storedAvatarUrl;
        }
        sessionLoginTimestamp = storedLoginTimestamp;
        await fetchUserProfile();
        await fetchWhatsNewDigest();
      } else {
        _setGuestProfile();
        _triggerFallbackFetches();
      }
      await fetchWhatsNewDigest();
      try {
        final cachedWhatsNew = prefs.getString('whats_new_digest_cache');
        if (cachedWhatsNew != null) {
          whatsNewDigest = jsonDecode(cachedWhatsNew);
        }
      } catch (_) {}

      // Load cached activity data
      try {
        final cachedActivity = prefs.getString(
          'activity_data_cache_$selectedActivityYear',
        );
        if (cachedActivity != null) {
          final List<dynamic> rawList = jsonDecode(cachedActivity);
          activityData = rawList
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}

      // Load cached following activity
      try {
        if (githubUsername.isNotEmpty) {
          final cachedFollowing = prefs.getString(
            'following_activity_cache_$githubUsername',
          );
          if (cachedFollowing != null) {
            final List<dynamic> rawEvents = jsonDecode(cachedFollowing);
            followingActivity = rawEvents
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
      } catch (_) {}

      // Load cached learning paths
      try {
        final cachedLearningPaths = prefs.getString('learning_paths_cache');
        if (cachedLearningPaths != null) {
          final data = jsonDecode(cachedLearningPaths);
          learningPathTitle = data['roadmap_title'] ?? 'Developer Career Path';
          final String rawPathText = data['learning_path'] ?? '';
          _parseAndSetLearningPath(rawPathText);
        }
      } catch (_) {}

      // Load cached opportunities
      try {
        final cachedOpps = prefs.getString('opportunities_cache');
        if (cachedOpps != null) {
          final data = jsonDecode(cachedOpps);
          techOpportunities = data['opportunities'];
        }
      } catch (_) {}

      // Load cached roadmap
      try {
        final cachedRoadmap = prefs.getString('roadmap_cache');
        if (cachedRoadmap != null) {
          final data = jsonDecode(cachedRoadmap);
          _parseAndSetRoadmap(data);
        }
      } catch (_) {}

      // Load cached prompt history
      try {
        final cachedPromptHistory = prefs.getString('prompt_history_cache__');
        if (cachedPromptHistory != null) {
          final List<dynamic> data = jsonDecode(cachedPromptHistory);
          promptHistory = data
              .map((json) => PromptItem.fromJson(json))
              .toList();
        }
      } catch (_) {}

      // Load cached prompt analytics
      try {
        final cachedPromptAnalytics = prefs.getString('prompt_analytics_cache');
        if (cachedPromptAnalytics != null) {
          final data = jsonDecode(cachedPromptAnalytics);
          _parseAndSetPromptAnalytics(data);
        }
      } catch (_) {}

      // Load cached prompt recommendations
      try {
        final cachedPromptRecommendations = prefs.getString(
          'prompt_recommendations_cache',
        );
        if (cachedPromptRecommendations != null) {
          final data = jsonDecode(cachedPromptRecommendations);
          promptRecommendations = List<dynamic>.from(
            data['recommendations'] ?? [],
          );
        }
      } catch (_) {}

      await loadCachedGithubPromptsMarkdown();
      await loadPromptRepoSources();
      await loadChatHistory();
    } catch (e) {
      debugPrint('Error restoring shared preferences: $e');
      _setGuestProfile();
      _triggerFallbackFetches();
    } finally {
      isPreferencesLoaded = true;
      notifyListeners();
      authStateNotifier.value++;
    }
  }

  void _setGuestProfile() {
    token = null;
    // Preserve any real username/avatar that was restored from cache/cookie
    // Only fall back to a placeholder if there's no cached identity at all
    if (username.isEmpty) username = 'Developer';
    if (githubUsername.isEmpty) githubUsername = '';
    avatarUrl = avatarUrl;
    sessionLoginTimestamp = null;
    showLinkGitHubPrompt = false;
  }

  Future<void> _saveCachedGithubStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cached_commits', commits);
      await prefs.setInt('cached_stars', stars);
      await prefs.setInt('cached_repos', repos);
      await prefs.setDouble('cached_developer_score', developerScore);
      await prefs.setStringList('cached_strengths', strengths);
      await prefs.setStringList('cached_gaps', gaps);
    } catch (_) {}
  }

  Future<void> _persistSessionSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token != null && token!.isNotEmpty) {
        await prefs.setString('auth_token', token!);
        saveCookie('auth_token', token!);
      }
      await prefs.setString('github_username', githubUsername);
      saveCookie('github_username', githubUsername);
      await prefs.setString('profile_display_name', username);
      saveCookie('profile_display_name', username);
      final ts = sessionLoginTimestamp ?? DateTime.now().toIso8601String();
      await prefs.setString('login_timestamp', ts);
      saveCookie('login_timestamp', ts);
      if (avatarUrl != null && avatarUrl!.isNotEmpty) {
        await prefs.setString('github_avatar_url', avatarUrl!);
        saveCookie('github_avatar_url', avatarUrl!);
      } else {
        await prefs.remove('github_avatar_url');
        deleteCookie('github_avatar_url');
      }
    } catch (_) {}
  }

  Future<void> loadCachedGithubPromptsMarkdown({
    String? owner,
    String? repo,
  }) async {
    final searchOwner = owner ?? selectedRepoOwner;
    final searchRepo = repo ?? selectedRepoName;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedMarkdown = prefs.getString(
        'github_prompts_markdown_cache_${searchOwner}_$searchRepo',
      );
      final cachedUpdatedAt = prefs.getInt(
        'github_prompts_markdown_updated_at_${searchOwner}_$searchRepo',
      );
      if (cachedMarkdown != null && cachedMarkdown.isNotEmpty) {
        githubPromptsMarkdown = cachedMarkdown;
        if (cachedUpdatedAt != null) {
          githubPromptsMarkdownUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
            cachedUpdatedAt,
          );
        }
      } else {
        // Fallback to old key if it is the default repo
        if (searchOwner == 'HeetMehta18' && searchRepo == 'AutoDevs') {
          final oldMarkdown = prefs.getString('github_prompts_markdown_cache');
          final oldUpdatedAt = prefs.getInt(
            'github_prompts_markdown_updated_at',
          );
          if (oldMarkdown != null && oldMarkdown.isNotEmpty) {
            githubPromptsMarkdown = oldMarkdown;
            if (oldUpdatedAt != null) {
              githubPromptsMarkdownUpdatedAt =
                  DateTime.fromMillisecondsSinceEpoch(oldUpdatedAt);
            }
            return;
          }
        }
        githubPromptsMarkdown = '';
        githubPromptsMarkdownUpdatedAt = null;
      }
    } catch (e) {
      debugPrint('Error loading cached prompts.md: $e');
    }
  }

  Future<void> loadPromptRepoSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('prompt_repo_sources');
      if (raw == null || raw.isEmpty) {
        promptRepoSources = [
          {'owner': _githubPromptsOwner, 'name': _githubPromptsRepo},
        ];
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final sources = <Map<String, String>>[];
        for (final item in decoded) {
          if (item is Map) {
            final owner = (item['owner'] ?? '').toString().trim();
            final name = (item['name'] ?? '').toString().trim();
            if (owner.isNotEmpty && name.isNotEmpty) {
              sources.add({'owner': owner, 'name': name});
            }
          }
        }
        promptRepoSources = sources.isEmpty
            ? [
                {'owner': _githubPromptsOwner, 'name': _githubPromptsRepo},
              ]
            : sources;
      }
    } catch (e) {
      debugPrint('Error loading prompt repo sources: $e');
      promptRepoSources = [
        {'owner': _githubPromptsOwner, 'name': _githubPromptsRepo},
      ];
    }
  }

  Future<void> savePromptRepoSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'prompt_repo_sources',
        jsonEncode(promptRepoSources),
      );
    } catch (_) {}
    notifyListeners();
  }

  void addPromptRepoSource(String owner, String name) {
    final normalizedOwner = owner.trim();
    final normalizedName = name.trim();
    if (normalizedOwner.isEmpty || normalizedName.isEmpty) {
      return;
    }

    final exists = promptRepoSources.any(
      (repo) =>
          repo['owner'] == normalizedOwner && repo['name'] == normalizedName,
    );
    if (!exists) {
      promptRepoSources = [
        ...promptRepoSources,
        {'owner': normalizedOwner, 'name': normalizedName},
      ];
      savePromptRepoSources();
    }

    selectedRepoOwner = normalizedOwner;
    selectedRepoName = normalizedName;
    loadCachedGithubPromptsMarkdown(
      owner: normalizedOwner,
      repo: normalizedName,
    ).then((_) {
      refreshGithubPromptsMarkdown(
        owner: normalizedOwner,
        repo: normalizedName,
        force: true,
      );
    });
  }

  void removePromptRepoSource(int index) {
    if (index < 0 || index >= promptRepoSources.length) {
      return;
    }

    promptRepoSources = List<Map<String, String>>.from(promptRepoSources)
      ..removeAt(index);
    if (promptRepoSources.isEmpty) {
      promptRepoSources = [
        {'owner': _githubPromptsOwner, 'name': _githubPromptsRepo},
      ];
    }
    savePromptRepoSources();
  }

  String selectedRepoOwner = 'HeetMehta18';
  String selectedRepoName = 'AutoDevs';
  bool isPushingPrompts = false;

  Future<String> refreshGithubPromptsMarkdown({
    String? owner,
    String? repo,
    bool force = false,
  }) async {
    if (isLoadingGithubPromptsMarkdown) {
      return 'prompts.md is already syncing.';
    }

    if (owner != null && repo != null) {
      selectedRepoOwner = owner;
      selectedRepoName = repo;
    }

    if (token == null) {
      // Offline/Mock mode content simulator
      githubPromptsMarkdown =
          '''# Prompts for $selectedRepoName

This is simulated offline prompts.md content.

- [$selectedRepoName] Implement Apple Liquid Glass Navigation
- [$selectedRepoName] Fix Touch responsiveness of Bottom Nav Bar on iOS PWA
- [$selectedRepoName] Setup GitHub .autodevs/prompts.md sync pipelines
''';
      githubPromptsMarkdownUpdatedAt = DateTime.now();
      notifyListeners();
      return 'Mock Mode: Simulated prompts.md loading.';
    }

    final now = DateTime.now();
    if (!force &&
        githubPromptsMarkdownUpdatedAt != null &&
        now.difference(githubPromptsMarkdownUpdatedAt!).inMinutes < 30) {
      return 'Using recent prompts.md cache.';
    }

    isLoadingGithubPromptsMarkdown = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.apiBaseUrl}/github/file-content?owner=$selectedRepoOwner&repo=$selectedRepoName',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final markdownText = data['content'] as String? ?? '';
        if (markdownText.isEmpty) {
          return 'GitHub returned an empty prompts.md file.';
        }

        githubPromptsMarkdown = markdownText;
        githubPromptsMarkdownUpdatedAt = now;

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'github_prompts_markdown_cache_${selectedRepoOwner}_$selectedRepoName',
            markdownText,
          );
          await prefs.setInt(
            'github_prompts_markdown_updated_at_${selectedRepoOwner}_$selectedRepoName',
            now.millisecondsSinceEpoch,
          );
        } catch (_) {}

        return 'prompts.md synced from GitHub.';
      }

      return 'Failed to load prompts.md: ${response.statusCode}';
    } catch (e) {
      debugPrint('Error syncing prompts.md: $e');
      return 'Failed to load prompts.md: $e';
    } finally {
      isLoadingGithubPromptsMarkdown = false;
      notifyListeners();
    }
  }

  Future<String> pushUpgradedPromptsToGithub(
    String projectName,
    String owner,
    String repo,
  ) async {
    isPushingPrompts = true;
    notifyListeners();

    try {
      if (token == null) {
        // Mock success
        await Future.delayed(const Duration(seconds: 2));
        isPushingPrompts = false;
        notifyListeners();
        return 'Successfully pushed prompts to GitHub (Mock Mode).';
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/prompts/push-github'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'project_name': projectName,
          'owner': owner,
          'name': repo,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        isPushingPrompts = false;
        notifyListeners();
        return data['message'] ?? 'Successfully pushed prompts to GitHub.';
      } else {
        isPushingPrompts = false;
        notifyListeners();
        final String? msg = data['error']?['message'] ?? data['detail'];
        return 'Push failed: ${msg ?? 'Server returned error ${response.statusCode}'}';
      }
    } catch (e) {
      isPushingPrompts = false;
      notifyListeners();
      return 'Push failed: $e';
    }
  }

  void _triggerFallbackFetches() {
    if (githubUsername.isNotEmpty) {
      fetchGithubData(githubUsername);
      fetchFollowingActivity();
    }
    if (token == null) return;
    fetchActivityData();
    fetchDeveloperDna();
    fetchProfileRoast();
    fetchWeeklyReport();
    fetchLearningPaths();
    fetchOpportunities();
    fetchPromptHistory();
    fetchPromptAnalytics();
    fetchPromptRecommendations();
    fetchRoadmap();
  }

  // Prompt Intelligence Platform
  List<PromptItem> promptHistory = [];
  int totalPrompts = 0;
  double averagePromptScore = 0.0;
  Map<String, int> promptWorkflowCounts = {};
  List<Map<String, dynamic>> topPromptTechnologies = [];
  List<Map<String, dynamic>> promptScoreHistory = [];
  List<dynamic> promptRecommendations = [];
  bool isLoadingPromptHistory = false;
  bool isLoadingPromptAnalytics = false;
  bool isLoadingPromptRecommendations = false;
  bool isSubmittingPromptEvent = false;
  bool isLoadingGithubPromptsMarkdown = false;
  String? githubPromptsMarkdown;
  DateTime? githubPromptsMarkdownUpdatedAt;
  List<Map<String, String>> promptRepoSources = [
    {'owner': _githubPromptsOwner, 'name': _githubPromptsRepo},
  ];

  List<Map<String, dynamic>> activityData = List.generate(70, (index) {
    final date = DateTime.now().subtract(Duration(days: 69 - index));
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return {
      'date': dateStr,
      'count': (index % 7 == 0)
          ? 1
          : (index % 3 == 0)
          ? 2
          : (index % 2 == 0)
          ? 4
          : 8,
    };
  });
  String selectedActivityYear = '2026';
  bool isLoadingActivity = false;

  List<Map<String, dynamic>> followingActivity = [];
  bool isLoadingFollowingActivity = false;

  // Developer DNA
  String? dnaArchetype;
  int? dnaScore;
  String? dnaDescription;
  List<String>? dnaStrengths;
  List<String>? dnaWeaknesses;
  bool isLoadingDna = false;

  // Profile Roast
  String? profileRoast;
  List<String>? roastTips;
  bool isLoadingRoast = false;

  // Resume Review & Tailoring
  int? resumeAtsScore;
  List<String>? resumeMissingTech;
  List<String>? resumeWeakBullets;
  List<String>? resumeProjectImprovements;
  List<String>? resumeMindsetUpgrades;
  List<String>? resumeSkillUpgrades;
  bool isReviewingResume = false;
  String? lastUploadedResumeText;
  String? lastUploadedResumeFileName;

  // Tailored Resume Generation
  bool isGeneratingResume = false;
  String? generatedResumeText;
  List<String>? generatedResumeOptimizations;
  int? generatedResumeAtsForecast;
  Map<String, dynamic>? googleDriveSyncInfo;

  // Google Drive Integration Status
  bool isGoogleDriveConnected = false;
  String? googleDriveEmail;
  bool isCheckingGoogleDriveStatus = false;

  // Project Evaluator
  int? evaluatedProjectScore;
  String? evaluatedProjectExplanation;
  List<String>? evaluatedProjectUpgradePath;
  bool isEvaluatingProject = false;

  // Battle Mode
  int? battleMatchScore;
  List<String>? battleMissingSkills;
  int? battleCodeQuality;
  int? battleScale;
  int? battleArchitecture;
  bool isBattling = false;

  // Weekly Growth Report
  int? weeklyExplored;
  int? weeklySkills;
  int? weeklyImprovement;
  List<int>? weeklyChartData;
  String? weeklyAchievements;
  List<String>? weeklyNextSteps;
  bool isLoadingWeeklyReport = false;

  // Learning Paths (Duolingo style)
  String? learningPathTitle;
  List<dynamic>? learningPathSteps;
  bool isLoadingLearningPaths = false;

  // Opportunities
  List<dynamic>? techOpportunities;
  bool isLoadingAwesomeLists = false;
  List<Map<String, dynamic>> awesomeLists = [];
  bool isLoadingOpportunities = false;

  // Open Source Copilot
  String? copilotIssueExplanation;
  String? copilotCodebaseExplanation;
  List<String>? copilotFilesToEdit;
  List<String>? copilotImplementationPlan;
  bool isCopilotRunning = false;

  // Developer Memory
  String personalGoal = "Become Full Stack AI Engineer";
  String preferredStack = "Flutter, FastAPI, PostgreSQL";
  bool isSavingMemory = false;

  // Research Layer State
  bool isResearching = false;
  String? researchError;
  Map<String, dynamic>? researchResult;
  bool isRateLimited = false;

  // Weekly Tech News Digest Cache
  String? weeklyTechDigest;
  bool isLoadingTechDigest = false;

  // 24/7 Research Agent Whats New
  Map<String, dynamic>? whatsNewDigest;
  bool isLoadingWhatsNewDigest = false;

  // Notifications List & Methods
  List<Map<String, dynamic>> notifications = [
    {
      'id': 'welcome',
      'title': 'Welcome to Tatvik Pro',
      'body': 'AI Mentor is initialized and waiting to review your projects.',
      'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
      'isRead': false,
      'type': 'welcome',
    },
  ];

  int get unreadNotificationsCount =>
      notifications.where((n) => n['isRead'] == false).length;

  void markAllNotificationsAsRead() {
    for (var n in notifications) {
      n['isRead'] = true;
    }
    notifyListeners();
  }

  void markNotificationAsRead(String id) {
    for (var n in notifications) {
      if (n['id'] == id) {
        n['isRead'] = true;
      }
    }
    notifyListeners();
  }

  void clearNotifications() {
    notifications.clear();
    notifyListeners();
  }

  // User Data
  String username = '';
  double developerScore = 0.0;
  int stars = 0;
  int commits = 0;
  int repos = 0;
  List<String> strengths = [];
  List<String> gaps = [];

  // Repositories — populated from real GitHub data
  List<Repository> allRepositories = [];

  String _repoFilter = 'All';
  String get repoFilter => _repoFilter;

  void setRepoFilter(String filter) {
    _repoFilter = filter;
    notifyListeners();
  }

  List<Repository> get filteredRepositories {
    if (_repoFilter == 'All') return allRepositories;
    return allRepositories.where((r) => r.difficulty == _repoFilter).toList();
  }

  // Roadmap — populated dynamically from GitHub language analysis
  List<RoadmapMilestone> milestones = [];

  double get roadmapProgress {
    if (milestones.isEmpty) return 0.0;
    int completed = milestones.where((m) => m.isCompleted).length;
    return (completed / milestones.length);
  }

  void toggleMilestone(int index) {
    // In a real app, this would be more complex (toggling subtasks)
    // For this prototype, we'll just toggle the main milestone
    final m = milestones[index];
    milestones[index] = RoadmapMilestone(
      title: m.title,
      description: m.description,
      isCompleted: !m.isCompleted,
    );
    notifyListeners();
  }

  bool isLoadingRoadmap = false;
  String roadmapTitle = "Senior Developer Career Path";

  Future<void> fetchRoadmap({bool force = false}) async {
    if (token == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt('roadmap_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && (now - lastTime) < 14400000) {
        // 4 hours
        final cachedRaw = prefs.getString('roadmap_cache');
        if (cachedRaw != null) {
          final data = jsonDecode(cachedRaw);
          _parseAndSetRoadmap(data);
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error reading roadmap cache: $e');
    }

    isLoadingRoadmap = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/roadmap/current'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _parseAndSetRoadmap(data);

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('roadmap_cache', response.body);
          await prefs.setInt(
            'roadmap_timestamp',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error fetching roadmap: $e');
    } finally {
      isLoadingRoadmap = false;
      notifyListeners();
    }
  }

  void _parseAndSetRoadmap(Map<String, dynamic> data) {
    roadmapTitle = data['title'] ?? 'Senior Developer Career Path';
    final List<dynamic> miles = data['milestones'] ?? [];
    milestones = miles.map((m) {
      return RoadmapMilestone(
        title: m['title'] ?? '',
        description: m['description'] ?? '',
        isCompleted: m['isCompleted'] ?? false,
        recommendations:
            (m['recommendations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
    }).toList();
  }

  Future<void> regenerateRoadmap() async {
    if (token == null) return;
    isLoadingRoadmap = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/roadmap/generate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'goal': personalGoal,
          'preferred_stack': preferredStack,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        roadmapTitle = data['title'] ?? 'Senior Developer Career Path';
        final List<dynamic> miles = data['milestones'] ?? [];
        milestones = miles.map((m) {
          return RoadmapMilestone(
            title: m['title'] ?? '',
            description: m['description'] ?? '',
            isCompleted: m['isCompleted'] ?? false,
            recommendations:
                (m['recommendations'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const [],
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error regenerating roadmap: $e');
    } finally {
      isLoadingRoadmap = false;
      notifyListeners();
    }
  }

  // Chat
  List<MentorMessage> chatMessages = [
    MentorMessage(
      content: 'Hello! I am your Tatvik. How can I help you grow today?',
      role: MessageRole.assistant,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  List<Map<String, dynamic>> chatSessions = [];
  String? _currentChatSessionId;
  bool isMentorTyping = false;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    chatMessages.add(
      MentorMessage(
        content: text,
        role: MessageRole.user,
        timestamp: DateTime.now(),
      ),
    );
    isMentorTyping = true;
    notifyListeners();

    // Build conversation history (everything except the message we just added)
    // Limit to last 10 turns (20 messages) to stay within token limits
    final historyMessages = chatMessages.length > 1
        ? chatMessages
              .sublist(0, chatMessages.length - 1)
              .reversed
              .take(20)
              .toList()
              .reversed
              .map(
                (m) => {
                  'role': m.role == MessageRole.user ? 'user' : 'assistant',
                  'content': m.content,
                },
              )
              .toList()
        : <Map<String, String>>[];

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/mentor/chat'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': text,
          'history': historyMessages,
          if (lastUploadedResumeText != null &&
              lastUploadedResumeText!.isNotEmpty)
            'resume_context': lastUploadedResumeText,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply =
            data['assistant_message'] ??
            'Sorry, I could not generate a response.';
        final openclawTask = data['openclaw_task'] as Map<String, dynamic>?;
        chatMessages.add(
          MentorMessage(
            content: reply,
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
            openclawTask: openclawTask,
          ),
        );
      } else {
        chatMessages.add(
          MentorMessage(
            content: 'Error: Failed to connect to AI Mentor service.',
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      chatMessages.add(
        MentorMessage(
          content: 'Error: $e',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      isMentorTyping = false;
    }
    notifyListeners();
    await saveChatHistory();
  }

  Future<void> sendPdfMessage(List<int> fileBytes, String filename) async {
    chatMessages.add(
      MentorMessage(
        content: '📄 Uploaded PDF: $filename',
        role: MessageRole.user,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiBaseUrl}/advanced/resume-upload'),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: filename),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final extractedText = data['extracted_text'] ?? '';

        chatMessages.add(
          MentorMessage(
            content:
                'I have parsed your PDF resume. Here is a quick summary of my analysis:\n\n'
                '• **ATS Alignment Score**: ${data['ats_score']}/100\n'
                '• **Missing Key Technologies**: ${List<String>.from(data['missing_technologies'] ?? []).join(', ')}\n'
                '• **Weak Bullet Points**: ${List<String>.from(data['weak_bullet_points'] ?? []).join(', ')}\n\n'
                'How would you like to improve this resume? You can ask me to re-write any weak bullet points, suggest new projects, or help practice for interviews based on these requirements!',
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
          ),
        );
        lastUploadedResumeText = extractedText;
        lastUploadedResumeFileName = filename;
      } else {
        chatMessages.add(
          MentorMessage(
            content:
                'Failed to process the PDF resume. Please make sure it is a valid PDF file.',
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      chatMessages.add(
        MentorMessage(
          content: 'Error processing PDF: $e',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        ),
      );
    }
    notifyListeners();
    await saveChatHistory();
  }

  /// Saves the current chat messages to SharedPreferences as the active session.
  Future<void> saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Ensure current session has an ID
      _currentChatSessionId ??= DateTime.now().millisecondsSinceEpoch
          .toString();

      // Derive a title from the first user message, or use a default
      String title = 'New Chat';
      for (final msg in chatMessages) {
        if (msg.role == MessageRole.user) {
          title = msg.content.length > 40
              ? '${msg.content.substring(0, 40)}...'
              : msg.content;
          break;
        }
      }

      // Build the session map
      final session = {
        'id': _currentChatSessionId,
        'title': title,
        'startedAt': chatMessages.isNotEmpty
            ? chatMessages.first.timestamp.toIso8601String()
            : DateTime.now().toIso8601String(),
        'messages': chatMessages.map((m) => m.toJson()).toList(),
      };

      // Update or insert in chatSessions list
      final idx = chatSessions.indexWhere(
        (s) => s['id'] == _currentChatSessionId,
      );
      if (idx >= 0) {
        chatSessions[idx] = session;
      } else {
        chatSessions.insert(0, session);
      }

      // Persist
      await prefs.setString('chat_sessions', jsonEncode(chatSessions));
      await prefs.setString('current_chat_session_id', _currentChatSessionId!);
    } catch (e) {
      debugPrint('Error saving chat history: $e');
    }
  }

  /// Loads chat history from SharedPreferences on app start.
  Future<void> loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getString('chat_sessions');
      final lastSessionId = prefs.getString('current_chat_session_id');

      if (sessionsJson != null) {
        final decoded = jsonDecode(sessionsJson) as List<dynamic>;
        chatSessions = decoded.cast<Map<String, dynamic>>();

        // Restore the last active session
        if (lastSessionId != null) {
          final session = chatSessions.firstWhere(
            (s) => s['id'] == lastSessionId,
            orElse: () => <String, dynamic>{},
          );
          if (session.isNotEmpty && session['messages'] != null) {
            final msgs = (session['messages'] as List<dynamic>)
                .map(
                  (m) => MentorMessage.fromJson(Map<String, dynamic>.from(m)),
                )
                .toList();
            if (msgs.isNotEmpty) {
              chatMessages = msgs;
              _currentChatSessionId = lastSessionId;
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  /// Returns the list of saved chat sessions (id, title, startedAt).
  List<Map<String, dynamic>> getChatSessions() {
    return chatSessions;
  }

  /// Saves the current chat and starts a fresh conversation.
  Future<void> startNewChat() async {
    // Save the current conversation if it has user messages
    if (chatMessages.any((m) => m.role == MessageRole.user)) {
      await saveChatHistory();
    }

    // Reset to a fresh chat
    _currentChatSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    chatMessages = [
      MentorMessage(
        content: 'Hello! I am your Tatvik. How can I help you grow today?',
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      ),
    ];
    notifyListeners();
  }

  /// Loads a specific chat session by its ID.
  Future<void> loadChatSession(String sessionId) async {
    try {
      // Save current chat first if it has content
      if (chatMessages.any((m) => m.role == MessageRole.user)) {
        await saveChatHistory();
      }

      final session = chatSessions.firstWhere(
        (s) => s['id'] == sessionId,
        orElse: () => <String, dynamic>{},
      );

      if (session.isNotEmpty && session['messages'] != null) {
        final msgs = (session['messages'] as List<dynamic>)
            .map((m) => MentorMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        chatMessages = msgs;
        _currentChatSessionId = sessionId;

        // Persist the switch
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_chat_session_id', sessionId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading chat session: $e');
    }
  }

  /// Deletes a specific chat session by its ID.
  Future<void> deleteChatSession(String sessionId) async {
    try {
      chatSessions.removeWhere((s) => s['id'] == sessionId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_sessions', jsonEncode(chatSessions));

      // If the deleted session was the active one, start a new chat
      if (_currentChatSessionId == sessionId) {
        _currentChatSessionId = null;
        chatMessages = [
          MentorMessage(
            content: 'Hello! I am your Tatvik. How can I help you grow today?',
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
          ),
        ];
        await prefs.remove('current_chat_session_id');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting chat session: $e');
    }
  }

  /// Clears all saved chat history and resets to a fresh chat.
  Future<void> clearAllChatHistory() async {
    try {
      chatSessions.clear();
      _currentChatSessionId = null;
      chatMessages = [
        MentorMessage(
          content: 'Hello! I am your Tatvik. How can I help you grow today?',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        ),
      ];

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('chat_sessions');
      await prefs.remove('current_chat_session_id');
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing chat history: $e');
    }
  }

  // Preferences
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  void setTabIndex(int index) {
    setSelectedTab(index);
  }

  void setSelectedTab(int index) {
    if (_currentTabIndex != index) {
      _currentTabIndex = index;
      notifyListeners();
    }
  }

  String _themeModeSetting = 'dark'; // 'dark' is default
  String get themeModeSetting => _themeModeSetting;

  bool get isDarkTheme {
    if (_themeModeSetting == 'system') {
      return ui.PlatformDispatcher.instance.platformBrightness !=
          ui.Brightness.light;
    }
    return _themeModeSetting == 'dark';
  }

  void setThemeMode(String mode) {
    if (mode == 'dark' || mode == 'light' || mode == 'system') {
      _themeModeSetting = mode;
      notifyListeners();
    }
  }

  void toggleTheme() {
    if (isDarkTheme) {
      _themeModeSetting = 'light';
    } else {
      _themeModeSetting = 'dark';
    }
    notifyListeners();
  }

  String githubUsername = 'alexjohnson';
  bool pushNotifications = true;
  bool aiInsights = true;
  bool weeklyReport = false;
  bool shareAnalytics = true;
  bool twoFactorAuth = false;
  bool githubUsernameLocked = false;
  String? sessionLoginTimestamp;

  bool isLoading = false;
  String? avatarUrl;
  String? token;

  Future<void> fetchGithubData(String ghUsername, {bool force = false}) async {
    if (ghUsername.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime =
          prefs.getInt('github_data_response_timestamp_$ghUsername') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && (now - lastTime) < 1800000) {
        // 30 minutes cache
        final cachedRaw = prefs.getString(
          'github_data_response_cache_$ghUsername',
        );
        if (cachedRaw != null) {
          final data = jsonDecode(cachedRaw);
          _parseGithubData(data, ghUsername);
          debugPrint('GitHub stats successfully restored from cache.');
          return;
        }
      }
    } catch (e) {
      debugPrint('Error reading GitHub stats cache: $e');
    }

    isLoading = true;
    notifyListeners();

    try {
      // 1. Try to fetch through backend public-stats proxy to bypass client-side CORS issues
      try {
        final backendUri = Uri.parse(
          '${AppConfig.apiBaseUrl}/github/public-stats/$ghUsername',
        );
        final response = await http.get(backendUri);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _parseGithubData(data, ghUsername);

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'github_data_response_cache_$ghUsername',
              response.body,
            );
            await prefs.setInt(
              'github_data_response_timestamp_$ghUsername',
              DateTime.now().millisecondsSinceEpoch,
            );
          } catch (_) {}

          isLoading = false;
          await _saveCachedGithubStats();
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint(
          'Backend public-stats proxy failed, using direct fallback: $e',
        );
      }

      // 2. Fallback to direct HTTP calls (works on mobile/desktop, fails gracefully on Web)
      int commitsCount = 0;
      if (!kIsWeb) {
        final commitsUri = Uri.parse(
          'https://api.github.com/search/commits?q=author:$ghUsername',
        );
        try {
          final commitsResponse = await http.get(
            commitsUri,
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'Tatvik-App',
            },
          );
          if (commitsResponse.statusCode == 200) {
            final commitsData = jsonDecode(commitsResponse.body);
            commitsCount = commitsData['total_count'] ?? 0;
          }
        } catch (e) {
          debugPrint('Error fetching commits count: $e');
        }
      }

      final userUri = Uri.parse('https://api.github.com/users/$ghUsername');
      final userResponse = await http.get(userUri);

      String userDisplayName = username;
      int publicRepos = 0;
      String? userAvatarUrl;
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        userDisplayName = userData['name'] ?? userData['login'] ?? username;
        publicRepos = userData['public_repos'] ?? 0;
        userAvatarUrl = userData['avatar_url'];
      }

      final reposUri = Uri.parse(
        'https://api.github.com/users/$ghUsername/repos?per_page=100',
      );
      final reposResponse = await http.get(reposUri);

      if (reposResponse.statusCode == 200) {
        final List<dynamic> reposData = jsonDecode(reposResponse.body);
        int totalStars = 0;
        for (var r in reposData) {
          totalStars += (r['stargazers_count'] as num).toInt();
        }

        final Map<String, dynamic> proxyLikeMap = {
          'name': userDisplayName,
          'login': ghUsername,
          'public_repos': publicRepos,
          'avatar_url': userAvatarUrl,
          'total_stars': totalStars,
          'total_commits': commitsCount > 0
              ? commitsCount
              : (reposData.length * 15),
          'repos': reposData,
        };

        _parseGithubData(proxyLikeMap, ghUsername);

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'github_data_response_cache_$ghUsername',
            jsonEncode(proxyLikeMap),
          );
          await prefs.setInt(
            'github_data_response_timestamp_$ghUsername',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error fetching GitHub data: $e');
    } finally {
      isLoading = false;
      await _saveCachedGithubStats();
      notifyListeners();
    }
  }

  void _parseGithubData(Map<String, dynamic> data, String ghUsername) {
    username = data['name'] ?? data['login'] ?? username;
    repos = data['public_repos'] ?? 0;
    avatarUrl = data['avatar_url'];
    final int totalStars = data['total_stars'] ?? 0;
    final int commitsCount = data['total_commits'] ?? 0;
    final List<dynamic> reposData = data['repos'] ?? [];

    List<Repository> newRepos = [];
    Map<String, int> langCounts = {};

    for (var r in reposData) {
      final String? lang = r['language'];
      if (lang != null && lang.isNotEmpty) {
        langCounts[lang] = (langCounts[lang] ?? 0) + 1;
      }

      newRepos.add(
        Repository(
          name: r['name'] ?? '',
          owner: r['owner'] is Map
              ? (r['owner']['login'] ?? '')
              : (r['owner'] ?? ''),
          description: r['description'] ?? 'No description provided.',
          difficulty: (r['stargazers_count'] as num) > 50
              ? 'Advanced'
              : ((r['stargazers_count'] as num) > 5
                    ? 'Intermediate'
                    : 'Beginner'),
          impactScore: ((r['stargazers_count'] as num) * 5 + 40)
              .clamp(40, 100)
              .toInt(),
          tags: lang != null ? [lang] : ['Repo'],
          whyRecommended:
              'Based on your GitHub activity and repository engagement.',
        ),
      );
    }

    stars = totalStars;
    commits = commitsCount;

    if (newRepos.isNotEmpty) {
      allRepositories = newRepos;
    }

    // Calculate dynamic Developer Score with real commits
    developerScore = double.parse(
      ((totalStars * 0.2 + reposData.length * 0.3 + commits * 0.01 + 3.0).clamp(
        1.0,
        10.0,
      )).toStringAsFixed(1),
    );

    // Determine strengths and gaps dynamically
    strengths = [];
    gaps = [];

    if (totalStars > 10) {
      strengths.add('Popular repositories (Total stars: $totalStars)');
    } else {
      gaps.add('Increase repo visibility and stargazers');
    }

    bool hasBackend = false;
    bool hasFrontend = false;
    for (var lang in langCounts.keys) {
      final l = lang.toLowerCase();
      if (l == 'typescript' ||
          l == 'javascript' ||
          l == 'html' ||
          l == 'css' ||
          l == 'dart') {
        hasFrontend = true;
      }
      if (l == 'go' ||
          l == 'rust' ||
          l == 'python' ||
          l == 'java' ||
          l == 'c#' ||
          l == 'ruby') {
        hasBackend = true;
      }
    }

    if (hasBackend) {
      strengths.add('Solid backend development knowledge');
    } else {
      gaps.add('Backend experience is holding back your score');
    }

    if (hasFrontend) {
      strengths.add('Strong UI/frontend development foundation');
    } else {
      gaps.add('Lack of frontend/UI application projects');
    }

    if (strengths.isEmpty) {
      strengths.add('Clean repository setup');
    }
    if (gaps.isEmpty) {
      gaps.add('Learn system architecture & cloud deployment');
    }

    // Dynamically update milestones based on languages
    if (langCounts.isNotEmpty) {
      final sortedLangs = langCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final primaryLang = sortedLangs.first.key;

      milestones = [
        RoadmapMilestone(
          title: 'Master $primaryLang Core & Patterns',
          description: 'Completed',
          isCompleted: true,
        ),
        RoadmapMilestone(
          title: 'Build Distributed Systems with $primaryLang',
          description: 'In Progress',
          isCompleted: false,
        ),
        RoadmapMilestone(
          title: 'CI/CD Pipelines & Automated Testing',
          description: 'Next — 1 month',
          isCompleted: false,
        ),
        RoadmapMilestone(
          title: 'System Design & Scalability',
          description: 'Next — 3 months',
          isCompleted: false,
        ),
        RoadmapMilestone(
          title: 'Deploy to Cloud & Production Monitoring',
          description: 'Next — 5 months',
          isCompleted: false,
        ),
      ];
    }
  }

  Future<void> setGithubUsername(String newUsername) async {
    githubUsername = newUsername.trim().replaceAll('@', '');
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('github_username', githubUsername);
    } catch (_) {}

    sessionLoginTimestamp ??= DateTime.now().toIso8601String();
    await _persistSessionSnapshot();

    await fetchGithubData(githubUsername);

    if (token != null) {
      try {
        final response = await http.post(
          Uri.parse('${AppConfig.apiBaseUrl}/github/sync-username'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'username': githubUsername}),
        );
        if (response.statusCode == 200) {
          debugPrint('Backend sync-username succeeded');
          showLinkGitHubPrompt = false;

          // Parse real GitHub metrics from backend sync response
          try {
            final syncData = jsonDecode(response.body);
            final details = syncData['details'] ?? {};
            if (details['total_stars'] != null) {
              stars = (details['total_stars'] as num).toInt();
            }
            if (details['total_commits'] != null) {
              commits = (details['total_commits'] as num).toInt();
            }
            if (details['repos_count'] != null) {
              repos = (details['repos_count'] as num).toInt();
            }
            if (details['developer_score'] != null) {
              developerScore = (details['developer_score'] as num).toDouble();
            }
            debugPrint(
              'Real GitHub metrics: stars=$stars, commits=$commits, repos=$repos, score=$developerScore',
            );
          } catch (parseError) {
            debugPrint('Error parsing sync response: $parseError');
          }

          await _saveCachedGithubStats();
          notifyListeners();

          await fetchActivityData();
          await fetchFollowingActivity();
          await fetchDeveloperDna();
          await fetchProfileRoast();
          await fetchWeeklyReport();
          await fetchLearningPaths();
          await fetchOpportunities();
          await fetchPromptHistory();
          await fetchPromptAnalytics();
          await fetchPromptRecommendations();
          await fetchRoadmap();
        } else {
          debugPrint('Backend sync-username failed: ${response.body}');
        }
      } catch (e) {
        debugPrint('Error syncing username to backend: $e');
      }
    }
  }

  Future<void> setGithubSession(
    String username,
    String sessionToken, {
    String? displayName,
    String? avatar,
  }) async {
    token = sessionToken;
    githubUsername = username.trim().replaceAll('@', '');
    this.username = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : githubUsername;
    avatarUrl = avatar;
    sessionLoginTimestamp = DateTime.now().toIso8601String();
    showLinkGitHubPrompt = false;
    githubUsernameLocked = true;
    notifyListeners();
    authStateNotifier.value++;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', sessionToken);
      await prefs.setString('github_username', githubUsername);
      await prefs.setString('profile_display_name', username);
      await prefs.setString('login_timestamp', sessionLoginTimestamp!);
      if (avatarUrl != null && avatarUrl!.isNotEmpty) {
        await prefs.setString('github_avatar_url', avatarUrl!);
      }
      await prefs.setBool('pref_github_locked', true);
    } catch (_) {}

    await _persistSessionSnapshot();

    await fetchGithubData(githubUsername);

    // Sync through backend to get authoritative real data
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/github/sync-username'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'username': githubUsername}),
      );
      if (response.statusCode == 200) {
        try {
          final syncData = jsonDecode(response.body);
          final details = syncData['details'] ?? {};
          if (details['total_stars'] != null) {
            stars = (details['total_stars'] as num).toInt();
          }
          if (details['total_commits'] != null) {
            commits = (details['total_commits'] as num).toInt();
          }
          if (details['repos_count'] != null) {
            repos = (details['repos_count'] as num).toInt();
          }
          if (details['developer_score'] != null) {
            developerScore = (details['developer_score'] as num).toDouble();
          }
          debugPrint(
            'OAuth sync metrics: stars=$stars, commits=$commits, repos=$repos, score=$developerScore',
          );
        } catch (parseError) {
          debugPrint('Error parsing OAuth sync response: $parseError');
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error in OAuth backend sync: $e');
    }

    fetchActivityData();
    fetchFollowingActivity();
    fetchDeveloperDna();
    fetchProfileRoast();
    fetchWeeklyReport();
    fetchLearningPaths();
    fetchOpportunities();
    fetchPromptHistory();
    fetchPromptAnalytics();
    fetchPromptRecommendations();
    fetchRoadmap();
  }

  void setEmailSession(String sessionToken) async {
    token = sessionToken;
    notifyListeners();
    authStateNotifier.value++;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', sessionToken);
    } catch (_) {}

    await _persistSessionSnapshot();

    await fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        final String? linkedUsername = userData['username'];
        username = userData['name'] ?? userData['login'] ?? username;
        avatarUrl = userData['avatar_url'] ?? avatarUrl;
        sessionLoginTimestamp = DateTime.now().toIso8601String();

        if (linkedUsername != null && linkedUsername.isNotEmpty) {
          githubUsername = linkedUsername;
          showLinkGitHubPrompt = false;

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('github_username', githubUsername);
            await prefs.setString('profile_display_name', username);
            await prefs.setString('login_timestamp', sessionLoginTimestamp!);
            if (avatarUrl != null && avatarUrl!.isNotEmpty) {
              await prefs.setString('github_avatar_url', avatarUrl!);
            }
          } catch (_) {}

          await _persistSessionSnapshot();

          await fetchGithubData(githubUsername);

          // Sync through backend for real metrics
          try {
            final syncResponse = await http.post(
              Uri.parse('${AppConfig.apiBaseUrl}/github/sync-username'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'username': githubUsername}),
            );
            if (syncResponse.statusCode == 200) {
              final syncData = jsonDecode(syncResponse.body);
              final details = syncData['details'] ?? {};
              if (details['total_stars'] != null) {
                stars = (details['total_stars'] as num).toInt();
              }
              if (details['total_commits'] != null) {
                commits = (details['total_commits'] as num).toInt();
              }
              if (details['repos_count'] != null) {
                repos = (details['repos_count'] as num).toInt();
              }
              if (details['developer_score'] != null) {
                developerScore = (details['developer_score'] as num).toDouble();
              }
              debugPrint(
                'Profile sync metrics: stars=$stars, commits=$commits, repos=$repos, score=$developerScore',
              );
              await _saveCachedGithubStats();
              notifyListeners();
            }
          } catch (syncErr) {
            debugPrint('Error in profile backend sync: $syncErr');
          }

          fetchActivityData();
          fetchFollowingActivity();
          fetchDeveloperDna();
          fetchProfileRoast();
          fetchWeeklyReport();
          fetchLearningPaths();
          fetchOpportunities();
          fetchPromptHistory();
          fetchPromptAnalytics();
          fetchPromptRecommendations();
          fetchRoadmap();
        } else {
          githubUsername = '';
          showLinkGitHubPrompt = true;
          notifyListeners();
        }
      } else if (response.statusCode == 401) {
        // Token is expired or invalid — auto-logout
        debugPrint('Auth token expired (401) — clearing session automatically');
        await clearSession();
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      if (token != null) {
        await _persistSessionSnapshot();
        _triggerFallbackFetches();
      }
    } finally {
      await checkGoogleDriveStatus();
    }
  }

  Future<void> clearSession() async {
    _setGuestProfile();
    // Clear in-memory cached stats as well
    commits = 0;
    stars = 0;
    repos = 0;
    developerScore = 0.0;
    strengths = [];
    gaps = [];
    notifyListeners();
    authStateNotifier.value++;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('github_username');
      await prefs.remove('profile_display_name');
      await prefs.remove('github_avatar_url');
      await prefs.remove('login_timestamp');
      await prefs.remove('github_prompts_markdown_cache');
      await prefs.remove('github_prompts_markdown_updated_at');
      await prefs.remove('dna_response_cache');
      await prefs.remove('dna_cache_timestamp');
      await prefs.remove('roast_response_cache');
      await prefs.remove('roast_cache_timestamp');
      await prefs.remove('weekly_report_response_cache');
      await prefs.remove('weekly_report_cache_timestamp');
      await prefs.remove('cached_commits');
      await prefs.remove('cached_stars');
      await prefs.remove('cached_repos');
      await prefs.remove('cached_developer_score');
      await prefs.remove('cached_strengths');
      await prefs.remove('cached_gaps');

      deleteCookie('auth_token');
      deleteCookie('github_username');
      deleteCookie('profile_display_name');
      deleteCookie('github_avatar_url');
      deleteCookie('login_timestamp');
    } catch (_) {}
  }

  Future<void> fetchActivityData({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime =
          prefs.getInt('activity_data_timestamp_$selectedActivityYear') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && (now - lastTime) < 3600000) {
        // 1 hour
        final cachedRaw = prefs.getString(
          'activity_data_cache_$selectedActivityYear',
        );
        if (cachedRaw != null) {
          final List<dynamic> rawList = jsonDecode(cachedRaw);
          activityData = rawList
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error reading activity data cache: $e');
    }

    isLoadingActivity = true;
    notifyListeners();
    try {
      final String urlString =
          '${AppConfig.apiBaseUrl}/github/activity?year=$selectedActivityYear';
      final response = await http.get(
        Uri.parse(urlString),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> rawList = data['activity'] ?? [];
        activityData = rawList
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'activity_data_cache_$selectedActivityYear',
            jsonEncode(rawList),
          );
          await prefs.setInt(
            'activity_data_timestamp_$selectedActivityYear',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error fetching activity data: $e');
    } finally {
      isLoadingActivity = false;
      notifyListeners();
    }
  }

  void setActivityYear(String year) {
    selectedActivityYear = year;
    fetchActivityData();
  }

  Future<void> fetchFollowingActivity({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime =
          prefs.getInt('following_activity_timestamp_$githubUsername') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && (now - lastTime) < 1800000) {
        // 30 minutes
        final cachedRaw = prefs.getString(
          'following_activity_cache_$githubUsername',
        );
        if (cachedRaw != null) {
          final List<dynamic> rawEvents = jsonDecode(cachedRaw);
          followingActivity = rawEvents
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error reading following activity cache: $e');
    }

    isLoadingFollowingActivity = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.apiBaseUrl}/github/following-activity?username=$githubUsername',
        ),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> rawEvents = data['events'] ?? [];
        followingActivity = rawEvents
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'following_activity_cache_$githubUsername',
            jsonEncode(rawEvents),
          );
          await prefs.setInt(
            'following_activity_timestamp_$githubUsername',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}
      } else {
        debugPrint('Failed to load following activity: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching following activity: $e');
    } finally {
      isLoadingFollowingActivity = false;
      notifyListeners();
    }
  }

  Future<void> fetchDeveloperDna({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('dna_response_cache');
      final cachedTime = prefs.getInt('dna_cache_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (!force && cachedJson != null && (now - cachedTime) < 604800000) {
        final data = jsonDecode(cachedJson);
        dnaArchetype = data['archetype'];
        dnaScore = data['score'];
        dnaDescription = data['description'];
        dnaStrengths = List<String>.from(data['strengths'] ?? []);
        dnaWeaknesses = List<String>.from(data['weaknesses'] ?? []);
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Error reading DNA cache: $e');
    }

    isLoadingDna = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/advanced/dna'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final bodyText = response.body;
        final data = jsonDecode(bodyText);
        dnaArchetype = data['archetype'];
        dnaScore = data['score'];
        dnaDescription = data['description'];
        dnaStrengths = List<String>.from(data['strengths'] ?? []);
        dnaWeaknesses = List<String>.from(data['weaknesses'] ?? []);

        try {
          final prefs = await SharedPreferences.getInstance();
          final lastDna = prefs.getString('last_dna_archetype');
          if (dnaArchetype != lastDna) {
            await prefs.setString('last_dna_archetype', dnaArchetype!);
            notifications.insert(0, {
              'id': 'dna_${DateTime.now().millisecondsSinceEpoch}',
              'title': 'DNA Archetype Identified: $dnaArchetype',
              'body':
                  'Your alignment score is $dnaScore%. Click to inspect details.',
              'timestamp': DateTime.now(),
              'isRead': false,
              'type': 'dna',
              'extraData': data,
            });
          }
          await prefs.setString('dna_response_cache', bodyText);
          await prefs.setInt(
            'dna_cache_timestamp',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error fetching DNA: $e');
    } finally {
      isLoadingDna = false;
      notifyListeners();
    }
  }

  Future<void> fetchProfileRoast({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('roast_response_cache');
      final cachedTime = prefs.getInt('roast_cache_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (!force && cachedJson != null && (now - cachedTime) < 604800000) {
        final data = jsonDecode(cachedJson);
        profileRoast = data['roast'];
        roastTips = List<String>.from(data['tips'] ?? []);
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Error reading roast cache: $e');
    }

    isLoadingRoast = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/advanced/roast'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final bodyText = response.body;
        final data = jsonDecode(bodyText);
        profileRoast = data['roast'];
        roastTips = List<String>.from(data['tips'] ?? []);

        try {
          final prefs = await SharedPreferences.getInstance();
          final lastRoast = prefs.getString('last_roast_response');
          if (profileRoast != lastRoast) {
            await prefs.setString('last_roast_response', profileRoast!);
            notifications.insert(0, {
              'id': 'roast_${DateTime.now().millisecondsSinceEpoch}',
              'title': 'GitHub Profile Roasted! 🔥',
              'body':
                  'Brutal review is ready. Click to inspect tips and issues.',
              'timestamp': DateTime.now(),
              'isRead': false,
              'type': 'roast',
              'extraData': data,
            });
          }
          await prefs.setString('roast_response_cache', bodyText);
          await prefs.setInt(
            'roast_cache_timestamp',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error fetching roast: $e');
    } finally {
      isLoadingRoast = false;
      notifyListeners();
    }
  }

  Future<void> reviewResume(String resumeText) async {
    isReviewingResume = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/advanced/resume-review'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'resume_text': resumeText}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        resumeAtsScore = data['ats_score'];
        resumeMissingTech = List<String>.from(
          data['missing_technologies'] ?? [],
        );
        resumeWeakBullets = List<String>.from(data['weak_bullet_points'] ?? []);
        resumeProjectImprovements = List<String>.from(
          data['project_improvements'] ?? [],
        );
        resumeMindsetUpgrades = List<String>.from(
          data['mindset_upgrades'] ?? [],
        );
        resumeSkillUpgrades = List<String>.from(data['skill_upgrades'] ?? []);
        lastUploadedResumeText = resumeText;
      }
    } catch (e) {
      debugPrint('Error reviewing resume: $e');
    } finally {
      isReviewingResume = false;
      notifyListeners();
    }
  }

  Future<void> uploadResume(List<int> fileBytes, String filename) async {
    isReviewingResume = true;
    notifyListeners();
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiBaseUrl}/advanced/resume-upload'),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: filename),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        resumeAtsScore = data['ats_score'];
        resumeMissingTech = List<String>.from(
          data['missing_technologies'] ?? [],
        );
        resumeWeakBullets = List<String>.from(data['weak_bullet_points'] ?? []);
        resumeProjectImprovements = List<String>.from(
          data['project_improvements'] ?? [],
        );
        resumeMindsetUpgrades = List<String>.from(
          data['mindset_upgrades'] ?? [],
        );
        resumeSkillUpgrades = List<String>.from(data['skill_upgrades'] ?? []);
        lastUploadedResumeText = data['extracted_text'];
        lastUploadedResumeFileName = filename;
      }
    } catch (e) {
      debugPrint('Error uploading resume: $e');
    } finally {
      isReviewingResume = false;
      notifyListeners();
    }
  }

  Future<void> generateTailoredResume({
    required String resumeText,
    required String jobTitle,
    required String jobDescription,
  }) async {
    isGeneratingResume = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/advanced/resume-generate'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'resume_text': resumeText,
          'job_title': jobTitle,
          'job_description': jobDescription,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        generatedResumeText = data['tailored_resume'];
        generatedResumeOptimizations = List<String>.from(
          data['applied_optimizations'] ?? [],
        );
        generatedResumeAtsForecast = data['ats_match_forecast'];
        googleDriveSyncInfo = Map<String, dynamic>.from(
          data['google_drive_sync'] ?? {},
        );
      }
    } catch (e) {
      debugPrint('Error generating resume: $e');
    } finally {
      isGeneratingResume = false;
      notifyListeners();
    }
  }

  Future<void> checkGoogleDriveStatus() async {
    if (token == null) return;
    isCheckingGoogleDriveStatus = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/google/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        isGoogleDriveConnected = data['connected'] ?? false;
        googleDriveEmail = data['email'];
      }
    } catch (e) {
      debugPrint('Error checking Google Drive status: $e');
    } finally {
      isCheckingGoogleDriveStatus = false;
      notifyListeners();
    }
  }

  String getGoogleDriveAuthorizeUrl() {
    return '${AppConfig.apiBaseUrl}/auth/google/authorize?token=$token';
  }

  Future<void> generateAndSyncResumeFromChat({
    required String jobTitle,
    required String jobDescription,
  }) async {
    if (lastUploadedResumeText == null || lastUploadedResumeText!.isEmpty) {
      chatMessages.add(
        MentorMessage(
          content: "Error: Please upload a PDF resume first before tailoring.",
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
      return;
    }

    chatMessages.add(
      MentorMessage(
        content:
            "Tailor my resume for $jobTitle:\n\n**Job Description:**\n$jobDescription",
        role: MessageRole.user,
        timestamp: DateTime.now(),
      ),
    );

    // Add a loading message
    final loadingMsgIndex = chatMessages.length;
    chatMessages.add(
      MentorMessage(
        content: "⏳ Tailoring resume and syncing with Google Drive...",
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      await generateTailoredResume(
        resumeText: lastUploadedResumeText!,
        jobTitle: jobTitle,
        jobDescription: jobDescription,
      );

      if (generatedResumeText != null) {
        String syncMsg = "";
        if (googleDriveSyncInfo != null) {
          final status = googleDriveSyncInfo!['status'];
          final fileName = googleDriveSyncInfo!['file_name'] ?? '';
          final webLink = googleDriveSyncInfo!['web_view_link'];

          if (status == 'success') {
            syncMsg =
                "✅ **Successfully Synced to Google Drive!**\n"
                "• **File Name**: `$fileName`\n"
                "• **Link**: [Open Google Drive File]($webLink)";
          } else {
            final msg =
                googleDriveSyncInfo!['message'] ?? 'Saved to local workspace.';
            final localPath = googleDriveSyncInfo!['file_path'] ?? '';
            syncMsg =
                "⚠️ **Saved to Local Workspace Only**\n"
                "• *Reason*: $msg\n"
                "• *File path*: `$localPath`\n"
                "• *Action*: Please link Google Drive in the status bar/input area to sync automatically next time.";
          }
        }

        chatMessages[loadingMsgIndex] = MentorMessage(
          content:
              "### 📄 Tailored Resume Generated!\n\n"
              "• **Target Role**: $jobTitle\n"
              "• **ATS Forecast Score**: ${generatedResumeAtsForecast ?? 0}%\n\n"
              "#### **Applied Optimizations:**\n"
              "${(generatedResumeOptimizations ?? []).map((o) => '• $o').join('\n')}\n\n"
              "$syncMsg",
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        );
      } else {
        chatMessages[loadingMsgIndex] = MentorMessage(
          content:
              "Error: Failed to generate tailored resume. Please try again.",
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      chatMessages[loadingMsgIndex] = MentorMessage(
        content: "Error: $e",
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      );
    } finally {
      notifyListeners();
      await saveChatHistory();
    }
  }

  Future<void> evaluateProject(String title) async {
    isEvaluatingProject = true;
    isRateLimited = false;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/research/project-analysis'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'project_idea': title}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final analysis = data['analysis'] ?? '';

        // Parse score from analysis text or use a robust fallback (e.g. 8/10)
        int score = 8;
        final scoreReg = RegExp(
          r'(Score|Rating|Value Score|ATS Score):\s*(\d+)/10',
          caseSensitive: false,
        );
        final match = scoreReg.firstMatch(analysis);
        if (match != null) {
          score = int.tryParse(match.group(2) ?? '8') ?? 8;
        } else {
          // Alternative search for single digit score
          final matchAlt = RegExp(r'\b([56789]|10)/10\b').firstMatch(analysis);
          if (matchAlt != null) {
            score = int.tryParse(matchAlt.group(1) ?? '8') ?? 8;
          }
        }

        evaluatedProjectScore = score;
        evaluatedProjectExplanation = analysis;

        // Split milestones/recommendations to populate a 4-step upgrade path
        List<String> path = [];
        final lines = analysis.split('\n');
        for (var line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('-') ||
              trimmed.startsWith('•') ||
              RegExp(r'^\d+\.').hasMatch(trimmed)) {
            final cleaned = trimmed
                .replaceFirst(RegExp(r'^[-•\d+\.\s]+'), '')
                .trim();
            if (cleaned.length > 10 && path.length < 4) {
              path.add(cleaned);
            }
          }
        }

        if (path.length < 4) {
          // Provide sensible default/extracted steps if text-parsing was sparse
          path = [
            'Analyze similar open-source templates for design patterns',
            'Draft clear interface specs and outline primary database models',
            'Develop core operational logic and integrate unit tests',
            'Establish automated deployment pipeline & track analytics',
          ];
        }

        evaluatedProjectUpgradePath = path;
      } else if (response.statusCode == 429) {
        handleRateLimit();
      }
    } catch (e) {
      debugPrint('Error evaluating project: $e');
    } finally {
      isEvaluatingProject = false;
      notifyListeners();
    }
  }

  Future<void> battleTarget(String targetRole) async {
    isBattling = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/advanced/battle'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'target': targetRole}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        battleMatchScore = data['match_score'];
        battleMissingSkills = List<String>.from(data['missing_skills'] ?? []);
        final metrics = data['metrics'] ?? {};
        battleCodeQuality = metrics['code_quality'];
        battleScale = metrics['scale'];
        battleArchitecture = metrics['system_architecture'];
      }
    } catch (e) {
      debugPrint('Error in battle: $e');
    } finally {
      isBattling = false;
      notifyListeners();
    }
  }

  Future<void> fetchWeeklyReport({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('weekly_report_response_cache');
      final cachedTime = prefs.getInt('weekly_report_cache_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (!force && cachedJson != null && (now - cachedTime) < 604800000) {
        final data = jsonDecode(cachedJson);
        weeklyExplored = data['repositories_explored'];
        weeklySkills = data['skills_learned'];
        weeklyImprovement = data['improvement_percentage'];
        weeklyChartData = List<int>.from(data['chart_data'] ?? []);
        weeklyAchievements = data['achievements'];
        weeklyNextSteps = data['next_steps'] != null
            ? List<String>.from(data['next_steps'])
            : null;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Error reading weekly report cache: $e');
    }

    isLoadingWeeklyReport = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/advanced/weekly-report'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final bodyText = response.body;
        final data = jsonDecode(bodyText);
        weeklyExplored = data['repositories_explored'];
        weeklySkills = data['skills_learned'];
        weeklyImprovement = data['improvement_percentage'];
        weeklyChartData = List<int>.from(data['chart_data'] ?? []);
        weeklyAchievements = data['achievements'];
        weeklyNextSteps = data['next_steps'] != null
            ? List<String>.from(data['next_steps'])
            : null;

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('weekly_report_response_cache', bodyText);
          await prefs.setInt(
            'weekly_report_cache_timestamp',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}

        notifications.insert(0, {
          'id': 'weekly_${DateTime.now().millisecondsSinceEpoch}',
          'title': 'AI Weekly Report Ready',
          'body':
              'You improved by $weeklyImprovement% this week. Click to check chart.',
          'timestamp': DateTime.now(),
          'isRead': false,
          'type': 'weekly_report',
          'extraData': data,
        });
      }
    } catch (e) {
      debugPrint('Error fetching weekly report: $e');
    } finally {
      isLoadingWeeklyReport = false;
      notifyListeners();
    }
  }

  Future<void> fetchLearningPaths({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt('learning_paths_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && (now - lastTime) < 14400000) {
        // 4 hours
        final cachedRaw = prefs.getString('learning_paths_cache');
        if (cachedRaw != null) {
          final data = jsonDecode(cachedRaw);
          learningPathTitle = data['roadmap_title'] ?? 'Developer Career Path';
          final String rawPathText = data['learning_path'] ?? '';
          _parseAndSetLearningPath(rawPathText);
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error reading learning paths cache: $e');
    }

    isLoadingLearningPaths = true;
    isRateLimited = false;
    notifyListeners();
    try {
      // Split preferred stack tags or default to a standard set
      final techs = preferredStack.isNotEmpty
          ? preferredStack
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : ['Flutter', 'Python', 'FastAPI'];

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/research/learning-path'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'role': personalGoal.isNotEmpty
              ? personalGoal
              : 'Full Stack Developer',
          'target_technologies': techs,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        learningPathTitle = data['roadmap_title'] ?? 'Developer Career Path';
        final String rawPathText = data['learning_path'] ?? '';

        _parseAndSetLearningPath(rawPathText);

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('learning_paths_cache', response.body);
          await prefs.setInt(
            'learning_paths_timestamp',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}
      } else if (response.statusCode == 429) {
        handleRateLimit();
      }
    } catch (e) {
      debugPrint('Error fetching learning paths: $e');
    } finally {
      isLoadingLearningPaths = false;
      notifyListeners();
    }
  }

  void _parseAndSetLearningPath(String rawPathText) {
    // Parse the markdown string into 5 Duolingo-style steps
    final List<Map<String, dynamic>> parsedSteps = [];
    final regex = RegExp(
      r'(?:^|\n)(?:Step\s+\d+|Milestone\s+\d+|###?\s+\d+)\b',
      caseSensitive: false,
    );
    final parts = rawPathText.split(regex);

    int stepIdx = 1;
    for (var part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      // Try to extract a repository name from the text
      String repoName = 'GitHub Reference';
      final repoMatch = RegExp(
        r'\b([a-zA-Z0-9\-_]+/[a-zA-Z0-9\-_.]+)\b',
      ).firstMatch(trimmed);
      if (repoMatch != null) {
        repoName = repoMatch.group(1)!;
      } else {
        // Pick a reasonable fallback name if none found
        if (stepIdx == 1) {
          repoName = 'flutter/flutter';
        } else if (stepIdx == 2) {
          repoName = 'tiangolo/fastapi';
        } else if (stepIdx == 3) {
          repoName = 'docker/cli';
        } else {
          repoName = 'open-source/project';
        }
      }

      // Extract description and task
      String desc = trimmed;
      String task =
          'Inspect typical project configuration and package dependency tree.';

      final taskMatch = RegExp(
        r'(?:Task|Actionable\s+Task|Action):\s*(.*)',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (taskMatch != null) {
        task = taskMatch.group(1)!.trim();
        desc = trimmed.substring(0, taskMatch.start).trim();
      } else {
        // Split by double newline to find a task-like ending
        final paragraphs = trimmed.split('\n\n');
        if (paragraphs.length > 1) {
          task = paragraphs.last.trim();
          desc = paragraphs
              .sublist(0, paragraphs.length - 1)
              .join('\n\n')
              .trim();
        }
      }

      parsedSteps.add({
        'step_num': stepIdx++,
        'repo_name': repoName,
        'description': desc,
        'task': task,
        'is_completed':
            stepIdx == 2, // first step marked completed for UI matchup
      });
    }

    // If parsing didn't produce any items, fallback or create structured steps
    if (parsedSteps.isEmpty) {
      final lines = rawPathText
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      for (var i = 0; i < lines.length && i < 5; i++) {
        parsedSteps.add({
          'step_num': i + 1,
          'repo_name': i == 0 ? 'flutter/flutter' : 'git/git',
          'description': lines[i]
              .replaceFirst(RegExp(r'^[-•\d+\.\s]+'), '')
              .trim(),
          'task': 'Examine repository code structure and main files.',
          'is_completed': i == 0,
        });
      }
    }

    learningPathSteps = parsedSteps;
  }

  Future<void> fetchOpportunities({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt('opportunities_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && (now - lastTime) < 14400000) {
        // 4 hours
        final cachedRaw = prefs.getString('opportunities_cache');
        if (cachedRaw != null) {
          final data = jsonDecode(cachedRaw);
          techOpportunities = data['opportunities'];
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error reading opportunities cache: $e');
    }

    isLoadingOpportunities = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/advanced/opportunities'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        techOpportunities = data['opportunities'];

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('opportunities_cache', response.body);
          await prefs.setInt(
            'opportunities_timestamp',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}

        if (techOpportunities != null && techOpportunities!.isNotEmpty) {
          final firstOppTitle =
              techOpportunities!.first['title'] ?? 'AI Trend Project';
          notifications.insert(0, {
            'id': 'opp_${DateTime.now().millisecondsSinceEpoch}',
            'title': 'New Build Opportunity',
            'body':
                'Trending: "$firstOppTitle". Click to view recommended stack.',
            'timestamp': DateTime.now(),
            'isRead': false,
            'type': 'opportunity',
            'extraData': techOpportunities,
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching opportunities: $e');
    } finally {
      isLoadingOpportunities = false;
      notifyListeners();
    }
  }

  Future<void> runCopilot(String title, String desc, String repo) async {
    isCopilotRunning = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/advanced/copilot'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'issue_title': title,
          'issue_description': desc,
          'repo_name': repo,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        copilotIssueExplanation = data['issue_explanation'];
        copilotCodebaseExplanation = data['codebase_explanation'];
        copilotFilesToEdit = List<String>.from(data['files_to_edit'] ?? []);
        copilotImplementationPlan = List<String>.from(
          data['implementation_plan'] ?? [],
        );
      }
    } catch (e) {
      debugPrint('Error running copilot: $e');
    } finally {
      isCopilotRunning = false;
      notifyListeners();
    }
  }

  Future<void> saveDeveloperMemory(String goal, String stack) async {
    isSavingMemory = true;
    personalGoal = goal;
    preferredStack = stack;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/users/memory'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'personal_goal': goal, 'preferred_stack': stack}),
      );
      if (response.statusCode == 200) {
        // Force refresh all AI features to match the new goals
        fetchDeveloperDna(force: true);
        fetchProfileRoast(force: true);
        fetchWeeklyReport(force: true);
        fetchLearningPaths();
        regenerateRoadmap();
      }
    } catch (e) {
      debugPrint('Error saving developer memory: $e');
    } finally {
      isSavingMemory = false;
      notifyListeners();
    }
  }

  void togglePreference(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == 'notifications') {
      pushNotifications = !pushNotifications;
      await prefs.setBool('pref_notifications', pushNotifications);
      if (pushNotifications) {
        web_helper.requestNotificationPermission();
      }
    }
    if (key == 'ai') {
      aiInsights = !aiInsights;
      await prefs.setBool('pref_ai', aiInsights);
    }
    if (key == 'report') {
      weeklyReport = !weeklyReport;
      await prefs.setBool('pref_report', weeklyReport);
    }
    if (key == 'analytics') {
      shareAnalytics = !shareAnalytics;
      await prefs.setBool('pref_analytics', shareAnalytics);
    }
    if (key == '2fa') {
      twoFactorAuth = !twoFactorAuth;
      await prefs.setBool('pref_2fa', twoFactorAuth);
    }
    if (key == 'github_lock') {
      githubUsernameLocked = !githubUsernameLocked;
      await prefs.setBool('pref_github_locked', githubUsernameLocked);
    }
    notifyListeners();
  }

  Future<void> fetchPromptHistory({
    String? query,
    String? workflow,
    bool force = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'prompt_history_cache_${query ?? ""}_${workflow ?? ""}';
      final timestampKey =
          'prompt_history_timestamp_${query ?? ""}_${workflow ?? ""}';
      final lastTime = prefs.getInt(timestampKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && (now - lastTime) < 900000) {
        // 15 minutes cache
        final cachedRaw = prefs.getString(cacheKey);
        if (cachedRaw != null) {
          final List<dynamic> data = jsonDecode(cachedRaw);
          promptHistory = data
              .map((json) => PromptItem.fromJson(json))
              .toList();
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error reading prompt history cache: $e');
    }

    isLoadingPromptHistory = true;
    notifyListeners();
    try {
      if (token == null) {
        // Load default mock history
        promptHistory = [
          PromptItem(
            id: '1',
            originalPrompt:
                'write a python script to scan files for secrets like api keys using regex',
            refinedPrompt:
                'Write a Python script that scans files in a directory for potential secrets (e.g., API keys, passwords, and private keys) using regular expressions.\n\n- Provide a command-line interface where the user can pass a target directory path.\n- Define regex patterns for common secret formats (e.g. AWS Keys, JWTs, generic secrets).\n- Output a clean list of findings including file path, line number, and a masked version of the matched secret.',
            score: 88,
            technologies: ['Python', 'Security'],
            workflow: 'Feature Building',
            projectName: 'secret-scanner',
            createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          ),
          PromptItem(
            id: '2',
            originalPrompt:
                'flutter button is not showing centered, how to center it',
            refinedPrompt:
                'I have a Flutter ElevatedButton that is not centered. How can I align it in the center of the screen?\n\n- Show examples using Center widget, Column with MainAxisAlignment.center, and Align.\n- Explain when to use each approach.',
            score: 72,
            technologies: ['Flutter', 'Dart'],
            workflow: 'Debugging',
            projectName: 'tatvik-app',
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          PromptItem(
            id: '3',
            originalPrompt:
                'optimize sql query select * from users join posts where posts.created_at is recent',
            refinedPrompt:
                'Explain how to optimize this SQL query:\n\n```sql\nSELECT * FROM users JOIN posts ON users.id = posts.user_id WHERE posts.created_at >= NOW() - INTERVAL \'7 days\';\n```\n\nProvide recommendations on indexes, query structure, and select fields instead of using `*`.',
            score: 82,
            technologies: ['SQL', 'PostgreSQL'],
            workflow: 'Refactoring',
            projectName: 'backend-service',
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ];
        isLoadingPromptHistory = false;
        notifyListeners();
        return;
      }

      String url = '${AppConfig.apiBaseUrl}/prompts/history';
      List<String> params = [];
      if (query != null && query.isNotEmpty)
        params.add('q=${Uri.encodeComponent(query)}');
      if (workflow != null && workflow.isNotEmpty)
        params.add('workflow=${Uri.encodeComponent(workflow)}');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        promptHistory = data.map((json) => PromptItem.fromJson(json)).toList();

        try {
          final prefs = await SharedPreferences.getInstance();
          final cacheKey =
              'prompt_history_cache_${query ?? ""}_${workflow ?? ""}';
          final timestampKey =
              'prompt_history_timestamp_${query ?? ""}_${workflow ?? ""}';
          await prefs.setString(cacheKey, response.body);
          await prefs.setInt(
            timestampKey,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error fetching prompt history: $e');
    } finally {
      isLoadingPromptHistory = false;
      notifyListeners();
    }
  }

  Future<String> refinePrompt(String promptId) async {
    if (token == null) {
      // Mock Refinement
      await Future.delayed(const Duration(seconds: 1));
      final index = promptHistory.indexWhere((p) => p.id == promptId);
      if (index != -1) {
        final current = promptHistory[index];
        promptHistory[index] = PromptItem(
          id: current.id,
          originalPrompt: current.originalPrompt,
          refinedPrompt:
              '// Refined with AI:\n${current.originalPrompt}\n\n1. Enhanced readability\n2. Clear intent/context parameters',
          score: 85,
          technologies: current.technologies.isEmpty
              ? ['Flutter', 'Dart']
              : current.technologies,
          workflow: current.workflow == 'Development'
              ? 'Feature Building'
              : current.workflow,
          projectName: current.projectName,
          createdAt: current.createdAt,
        );
        notifyListeners();
      }
      return 'Success';
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/prompts/$promptId/refine'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final index = promptHistory.indexWhere((p) => p.id == promptId);
        if (index != -1) {
          promptHistory[index] = PromptItem(
            id: data['id']?.toString() ?? '',
            originalPrompt: data['original_prompt'] ?? '',
            refinedPrompt: data['refined_prompt'] ?? '',
            score: data['score'] ?? 0,
            technologies: data['technologies'] != null
                ? List<String>.from(data['technologies'])
                : <String>[],
            workflow: data['workflow'] ?? 'Development',
            projectName: data['project_name'],
            createdAt: data['created_at'] != null
                ? DateTime.parse(data['created_at'])
                : DateTime.now(),
          );
          notifyListeners();
        }
        fetchPromptAnalytics(force: true);
        return 'Success';
      } else {
        final data = jsonDecode(response.body);
        final String? msg = data['error']?['message'] ?? data['detail'];
        return msg ?? 'Server returned error ${response.statusCode}';
      }
    } catch (e) {
      return '$e';
    }
  }

  Future<String> syncGithubPrompts() async {
    if (token == null) {
      return 'Mock Mode: Cannot sync GitHub prompts without authentication.';
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/prompts/sync-github'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'github_username': githubUsername,
          'repo_sources': promptRepoSources,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Refresh prompt history, analytics, and recommendations bypassing the cache
        fetchPromptHistory(force: true);
        fetchPromptAnalytics(force: true);
        fetchPromptRecommendations(force: true);
        return data['message'] ??
            'Successfully synchronized prompts from GitHub.';
      } else {
        final data = jsonDecode(response.body);
        final String? msg = data['error']?['message'] ?? data['detail'];
        return 'Sync failed: ${msg ?? 'Server returned error ${response.statusCode}'}';
      }
    } catch (e) {
      return 'Sync failed: $e';
    }
  }

  Future<void> fetchPromptAnalytics({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt('prompt_analytics_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && (now - lastTime) < 900000) {
        // 15 minutes cache
        final cachedRaw = prefs.getString('prompt_analytics_cache');
        if (cachedRaw != null) {
          final data = jsonDecode(cachedRaw);
          _parseAndSetPromptAnalytics(data);
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error reading prompt analytics cache: $e');
    }

    isLoadingPromptAnalytics = true;
    notifyListeners();
    try {
      if (token == null) {
        // Load default mock analytics
        totalPrompts = 24;
        averagePromptScore = 80.5;
        promptWorkflowCounts = {
          'Feature Building': 12,
          'Debugging': 6,
          'Refactoring': 4,
          'Testing': 2,
        };
        topPromptTechnologies = [
          {'name': 'Python', 'count': 8},
          {'name': 'Flutter', 'count': 6},
          {'name': 'FastAPI', 'count': 5},
          {'name': 'Dart', 'count': 4},
          {'name': 'SQL', 'count': 3},
        ];
        promptScoreHistory = [
          {'date': '05-28', 'score': 74},
          {'date': '05-29', 'score': 78},
          {'date': '06-01', 'score': 82},
          {'date': '06-02', 'score': 80},
          {'date': '06-04', 'score': 88},
        ];
        isLoadingPromptAnalytics = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/prompts/analytics'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _parseAndSetPromptAnalytics(data);

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('prompt_analytics_cache', response.body);
          await prefs.setInt(
            'prompt_analytics_timestamp',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error fetching prompt analytics: $e');
    } finally {
      isLoadingPromptAnalytics = false;
      notifyListeners();
    }
  }

  void _parseAndSetPromptAnalytics(Map<String, dynamic> data) {
    totalPrompts = data['total_prompts'] ?? 0;
    averagePromptScore = (data['average_score'] as num?)?.toDouble() ?? 0.0;
    promptWorkflowCounts = Map<String, int>.from(data['workflow_counts'] ?? {});
    topPromptTechnologies = List<Map<String, dynamic>>.from(
      (data['top_technologies'] ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    promptScoreHistory = List<Map<String, dynamic>>.from(
      (data['score_history'] ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<void> fetchPromptRecommendations({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt('prompt_recommendations_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && (now - lastTime) < 3600000) {
        // 1 hour cache
        final cachedRaw = prefs.getString('prompt_recommendations_cache');
        if (cachedRaw != null) {
          final data = jsonDecode(cachedRaw);
          promptRecommendations = List<dynamic>.from(
            data['recommendations'] ?? [],
          );
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error reading prompt recommendations cache: $e');
    }

    isLoadingPromptRecommendations = true;
    notifyListeners();
    try {
      if (token == null) {
        // Load mock recommendations
        promptRecommendations = [
          {
            'title': 'Mastering Flutter Layout Constraints',
            'description':
                'Based on your debugging prompts about Button alignments, you could benefit from understanding Flutter box constraints layout rules.',
            'tags': ['Flutter', 'Layouts'],
            'url': 'https://flutter.dev/docs/development/ui/layout/constraints',
          },
          {
            'title': 'Security Scanners & Secret Scanning in CI/CD',
            'description':
                'You have been writing script prompts to scan files for secrets. Check out how tools like GitGuardian or TruffleHog automate this.',
            'tags': ['DevOps', 'Security'],
            'url': 'https://github.com/trufflesecurity/trufflehog',
          },
        ];
        isLoadingPromptRecommendations = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/prompts/recommendations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        promptRecommendations = List<dynamic>.from(
          data['recommendations'] ?? [],
        );

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('prompt_recommendations_cache', response.body);
          await prefs.setInt(
            'prompt_recommendations_timestamp',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error fetching prompt recommendations: $e');
    } finally {
      isLoadingPromptRecommendations = false;
      notifyListeners();
    }
  }

  Future<void> submitPromptEvent(
    String originalPrompt, {
    String? projectName,
    String? fileContext,
  }) async {
    if (originalPrompt.trim().isEmpty) return;
    isSubmittingPromptEvent = true;
    notifyListeners();
    try {
      if (token == null) {
        // Mock prompt generation locally
        await Future.delayed(const Duration(seconds: 2));
        final newPrompt = PromptItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          originalPrompt: originalPrompt,
          refinedPrompt:
              'Refined Version of:\n$originalPrompt\n\n- Added context\n- Clearly defined inputs, processing steps, and expected outputs.',
          score: 85,
          technologies: ['Dart', 'General'],
          workflow: 'Feature Building',
          projectName: projectName ?? 'local-project',
          createdAt: DateTime.now(),
        );
        promptHistory.insert(0, newPrompt);
        totalPrompts += 1;
        averagePromptScore =
            ((averagePromptScore * (totalPrompts - 1) + 85) / totalPrompts);

        notifications.insert(0, {
          'id': 'prompt_${DateTime.now().millisecondsSinceEpoch}',
          'title': 'Prompt Telemetry Synced! 🚀',
          'body': 'Prompt scored 85/100. Check the Refined Prompt version.',
          'timestamp': DateTime.now(),
          'isRead': false,
          'type': 'prompt_intelligence',
        });

        isSubmittingPromptEvent = false;
        notifyListeners();
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/prompts/event'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'original_prompt': originalPrompt,
          'project_name': projectName,
          'file_context': fileContext,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newItem = PromptItem.fromJson(data);
        promptHistory.insert(0, newItem);

        // Refresh analytics & recommendations to update profile dna
        await fetchPromptAnalytics();
        await fetchPromptRecommendations();

        notifications.insert(0, {
          'id': 'prompt_${newItem.id}',
          'title': 'New CLI Prompt Recorded 🚀',
          'body': 'Scored ${newItem.score}/100. Open Prompt Hub to inspect.',
          'timestamp': DateTime.now(),
          'isRead': false,
          'type': 'prompt_intelligence',
        });
      }
    } catch (e) {
      debugPrint('Error submitting prompt event: $e');
    } finally {
      isSubmittingPromptEvent = false;
      notifyListeners();
    }
  }

  void handleRateLimit() {
    isRateLimited = true;
    notifications.insert(0, {
      'id': 'rate_limit_${DateTime.now().millisecondsSinceEpoch}',
      'title': 'Rate Limit Warning ⚠️',
      'body': 'Please wait a moment before initiating more research queries.',
      'timestamp': DateTime.now(),
      'isRead': false,
      'type': 'security',
    });
    notifyListeners();
  }

  void clearRateLimit() {
    isRateLimited = false;
    notifyListeners();
  }

  void addSystemMessageToChat(String text) {
    chatMessages.add(
      MentorMessage(
        content: text,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
    saveChatHistory();
  }

  Future<void> fetchWeeklyTechDigest({bool force = false}) async {
    isLoadingTechDigest = true;
    isRateLimited = false;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/research/digest?topic=general'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        weeklyTechDigest = data['digest'];

        final prefs = await SharedPreferences.getInstance();
        final lastDigest = prefs.getString('last_weekly_digest');
        if (weeklyTechDigest != null &&
            weeklyTechDigest!.isNotEmpty &&
            weeklyTechDigest != lastDigest) {
          await prefs.setString('last_weekly_digest', weeklyTechDigest!);
          notifications.insert(0, {
            'id': 'digest_${DateTime.now().millisecondsSinceEpoch}',
            'title': 'New Technical Digest Available',
            'body':
                'Your Deep Research Agent has compiled the latest tech news.',
            'timestamp': DateTime.now(),
            'isRead': false,
            'type': 'digest',
          });
        }
      } else if (response.statusCode == 429) {
        handleRateLimit();
      }
    } catch (e) {
      debugPrint('Error fetching weekly tech digest: $e');
    } finally {
      isLoadingTechDigest = false;
      notifyListeners();
    }
  }

  Future<void> fetchResearchData(
    String tool,
    Map<String, dynamic> payload,
  ) async {
    isResearching = true;
    researchError = null;
    researchResult = null;
    isRateLimited = false;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/research/$tool'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        researchResult = jsonDecode(response.body);
      } else if (response.statusCode == 429) {
        handleRateLimit();
      } else {
        final errData = jsonDecode(response.body);
        researchError = errData['detail'] ?? 'Research request failed.';
      }
    } catch (e) {
      debugPrint('Error performing research query: $e');
      researchError = e.toString();
    } finally {
      isResearching = false;
      notifyListeners();
    }
  }

  Future<void> fetchWhatsNewDigest({bool force = false}) async {
    isLoadingWhatsNewDigest = true;
    notifyListeners();

    // 1. Immediately serve from cached data so UI never shows empty
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRaw = prefs.getString('whats_new_digest_cache');
      final lastTime = prefs.getInt('last_whats_new_time') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (cachedRaw != null) {
        whatsNewDigest = jsonDecode(cachedRaw);
        notifyListeners();
        if (!force && (nowMs - lastTime) < 43200000) {
          // 12 hours
          isLoadingWhatsNewDigest = false;
          notifyListeners();
          return;
        }
      }
    } catch (_) {}

    // 2. Fetch fresh digest from backend (no token required — endpoint is public)
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/research/whats-new'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        try {
          final ghRes = await http.get(
            Uri.parse(
              'https://api.github.com/search/repositories?q=stars:>50+created:>2026-06-01&sort=stars&order=desc',
            ),
          );
          if (ghRes.statusCode == 200) {
            final ghData = jsonDecode(ghRes.body);
            final items = ghData['items'] as List?;
            if (items != null && items.isNotEmpty) {
              data['github'] = items
                  .take(5)
                  .map(
                    (item) => {
                      "name": item['name'] ?? "",
                      "owner": item['owner']?['login'] ?? "",
                      "description": item['description'] ?? "No description",
                      "stars": item['stargazers_count'] ?? 0,
                      "url": item['html_url'] ?? "",
                    },
                  )
                  .toList();
            }
          }
        } catch (_) {}

        whatsNewDigest = data;

        final digestText = data['digest'] ?? '';
        final prefs = await SharedPreferences.getInstance();
        final lastDigest = prefs.getString('last_whats_new_digest');
        final lastTime = prefs.getInt('last_whats_new_time') ?? 0;
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        // Limit to max twice daily (12 hours = 43200000 ms)
        if (digestText.isNotEmpty &&
            digestText != lastDigest &&
            (nowMs - lastTime) > 43200000) {
          await prefs.setString('last_whats_new_digest', digestText);
          await prefs.setInt('last_whats_new_time', nowMs);

          // Add to local notifications list
          notifications.insert(0, {
            'id': 'whats_new_${DateTime.now().millisecondsSinceEpoch}',
            'title': 'New GitHub & YouTube Digest',
            'body': 'Your 24/7 Agent found new trends. Click to view.',
            'timestamp': DateTime.now(),
            'isRead': false,
            'type': 'whats_new',
            'extraData': data,
          });

          // Show browser notification if supported
          web_helper.showBrowserNotification(
            'New GitHub & YouTube Digest',
            'Your 24/7 Agent found new trends. Click to view.',
          );
        }

        // Cache the latest response in SharedPreferences
        await prefs.setString('whats_new_digest_cache', jsonEncode(data));
      }
    } catch (e) {
      debugPrint('Error fetching whats new digest: $e');
    } finally {
      isLoadingWhatsNewDigest = false;
      notifyListeners();
    }
  }

  Future<void> fetchAwesomeLists() async {
    isLoadingAwesomeLists = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/search/repositories?q=topic:awesome&sort=stars&order=desc',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List?;
        if (items != null && items.isNotEmpty) {
          awesomeLists = items
              .take(20)
              .map(
                (item) => {
                  "name": item['name'] ?? "",
                  "owner": item['owner']?['login'] ?? "",
                  "description": item['description'] ?? "No description",
                  "stars": item['stargazers_count'] ?? 0,
                  "url": item['html_url'] ?? "",
                },
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching awesome lists: $e');
    } finally {
      isLoadingAwesomeLists = false;
      notifyListeners();
    }
  }
}
