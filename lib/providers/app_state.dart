import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/repository.dart';
import '../models/roadmap.dart';
import '../models/mentor_message.dart';
import '../core/config/app_config.dart';
import '../models/prompt_item.dart';


class AppState extends ChangeNotifier {
  AppState() {
    initPreferences();
  }

  bool showLinkGitHubPrompt = false;
  bool isPreferencesLoaded = false;

  Future<void> initPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('auth_token');
      final storedUsername = prefs.getString('github_username');
      
      pushNotifications = prefs.getBool('pref_notifications') ?? true;
      aiInsights = prefs.getBool('pref_ai') ?? true;
      weeklyReport = prefs.getBool('pref_report') ?? false;
      shareAnalytics = prefs.getBool('pref_analytics') ?? true;
      twoFactorAuth = prefs.getBool('pref_2fa') ?? false;
      githubUsernameLocked = prefs.getBool('pref_github_locked') ?? false;

      if (storedToken != null && storedToken.isNotEmpty) {
        token = storedToken;
        if (storedUsername != null && storedUsername.isNotEmpty) {
          githubUsername = storedUsername;
        } else {
          githubUsername = 'alexjohnson';
        }
        await fetchUserProfile();
      } else {
        githubUsername = 'alexjohnson';
        _triggerFallbackFetches();
      }
      await loadChatHistory();
    } catch (e) {
      debugPrint('Error restoring shared preferences: $e');
      githubUsername = 'alexjohnson';
      _triggerFallbackFetches();
    } finally {
      isPreferencesLoaded = true;
      notifyListeners();
    }
  }

  void _triggerFallbackFetches() {
    fetchGithubData(githubUsername);
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

  List<Map<String, dynamic>> activityData = List.generate(70, (index) {
    final date = DateTime.now().subtract(Duration(days: 69 - index));
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return {
      'date': dateStr,
      'count': (index % 7 == 0) ? 1 : (index % 3 == 0) ? 2 : (index % 2 == 0) ? 4 : 8
    };
  });
  String selectedActivityYear = 'Last 14 Weeks';
  bool isLoadingActivity = false;

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

  // Resume Review
  int? resumeAtsScore;
  List<String>? resumeMissingTech;
  List<String>? resumeWeakBullets;
  List<String>? resumeProjectImprovements;
  List<String>? resumeMindsetUpgrades;
  List<String>? resumeSkillUpgrades;
  bool isReviewingResume = false;

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
  bool isLoadingWeeklyReport = false;

  // Learning Paths (Duolingo style)
  String? learningPathTitle;
  List<dynamic>? learningPathSteps;
  bool isLoadingLearningPaths = false;

  // Opportunities
  List<dynamic>? techOpportunities;
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


  // Notifications List & Methods
  List<Map<String, dynamic>> notifications = [
    {
      'id': 'welcome',
      'title': 'Welcome to DevMentor Pro',
      'body': 'AI Mentor is initialized and waiting to review your projects.',
      'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
      'isRead': false,
      'type': 'welcome',
    }
  ];

  int get unreadNotificationsCount => notifications.where((n) => n['isRead'] == false).length;

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
  String username = 'Alex Johnson';
  double developerScore = 8.7;
  int stars = 234;
  int commits = 89;
  int repos = 12;
  List<String> strengths = ['Strong coding consistency', 'Well-documented repositories'];
  List<String> gaps = ['Backend experience is holding back your score', 'System design patterns'];

  // Repositories
  List<Repository> allRepositories = [
    Repository(
      name: 'express-api-starter',
      owner: 'node-app',
      description: 'A minimal and flexible Node.js REST API starter with Express and TypeScript.',
      difficulty: 'Beginner',
      impactScore: 92,
      tags: ['TypeScript', 'Express', 'Node.js'],
      whyRecommended: 'Matched to your skill gaps. Curated to build backend experience.',
    ),
    Repository(
      name: 'microservices-demo',
      owner: 'google-cloud',
      description: 'Sample cloud-native application with 10 microservices showcasing best practices.',
      difficulty: 'Advanced',
      impactScore: 88,
      tags: ['Go', 'Kubernetes', 'Docker', 'GRPC'],
      whyRecommended: 'Perfect for understanding distributed systems.',
    ),
    Repository(
      name: 'nestjs-realworld',
      owner: 'nestjs',
      description: 'Exemplary Fullstack Medium.com clone powered by NestJS & React.',
      difficulty: 'Intermediate',
      impactScore: 98,
      tags: ['TypeScript', 'NestJS', 'Backend', 'Fullstack'],
      whyRecommended: 'Builds comprehensive full-stack knowledge.',
    ),
  ];

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

  // Roadmap
  List<RoadmapMilestone> milestones = [
    RoadmapMilestone(
      title: 'Master TypeScript Fundamentals',
      description: 'Completed',
      isCompleted: true,
    ),
    RoadmapMilestone(
      title: 'Build Full-Stack Projects',
      description: 'In Progress',
      isCompleted: false,
    ),
    RoadmapMilestone(
      title: 'Learn System Design',
      description: 'Next — 2 months',
      isCompleted: false,
    ),
  ];

  double get roadmapProgress {
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

  Future<void> fetchRoadmap() async {
    if (token == null) return;
    isLoadingRoadmap = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/roadmap/current'),
        headers: {
          'Authorization': 'Bearer $token',
        },
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
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching roadmap: $e');
    } finally {
      isLoadingRoadmap = false;
      notifyListeners();
    }
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
      content: 'Hello! I am your DevMentor. How can I help you grow today?',
      role: MessageRole.assistant,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  List<Map<String, dynamic>> chatSessions = [];
  String? _currentChatSessionId;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    chatMessages.add(MentorMessage(
      content: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    ));
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/mentor/chat'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['assistant_message'] ?? 'Sorry, I could not generate a response.';
        chatMessages.add(MentorMessage(
          content: reply,
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        ));
      } else {
        chatMessages.add(MentorMessage(
          content: 'Error: Failed to connect to AI Mentor service.',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      chatMessages.add(MentorMessage(
        content: 'Error: $e',
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      ));
    }
    notifyListeners();
    await saveChatHistory();
  }

  /// Saves the current chat messages to SharedPreferences as the active session.
  Future<void> saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Ensure current session has an ID
      _currentChatSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

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
      final idx = chatSessions.indexWhere((s) => s['id'] == _currentChatSessionId);
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
                .map((m) => MentorMessage.fromJson(Map<String, dynamic>.from(m)))
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
        content: 'Hello! I am your DevMentor. How can I help you grow today?',
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
            content: 'Hello! I am your DevMentor. How can I help you grow today?',
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
          content: 'Hello! I am your DevMentor. How can I help you grow today?',
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
    _currentTabIndex = index;
    notifyListeners();
  }

  String _themeModeSetting = 'dark'; // 'dark' is default
  String get themeModeSetting => _themeModeSetting;

  bool get isDarkTheme {
    if (_themeModeSetting == 'system') {
      return ui.PlatformDispatcher.instance.platformBrightness != ui.Brightness.light;
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

  bool isLoading = false;
  String? avatarUrl;
  String? token;

  Future<void> fetchGithubData(String ghUsername) async {
    if (ghUsername.isEmpty) return;
    isLoading = true;
    notifyListeners();

    try {
      final userUri = Uri.parse('https://api.github.com/users/$ghUsername');
      final userResponse = await http.get(userUri);
      
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        username = userData['name'] ?? userData['login'] ?? 'Alex Johnson';
        repos = userData['public_repos'] ?? 0;
        avatarUrl = userData['avatar_url'];
      }

      final reposUri = Uri.parse('https://api.github.com/users/$ghUsername/repos?per_page=100');
      final reposResponse = await http.get(reposUri);
      
      if (reposResponse.statusCode == 200) {
        final List<dynamic> reposData = jsonDecode(reposResponse.body);
        int totalStars = 0;
        List<Repository> newRepos = [];
        Map<String, int> langCounts = {};

        for (var r in reposData) {
          totalStars += (r['stargazers_count'] as num).toInt();
          final String? lang = r['language'];
          if (lang != null && lang.isNotEmpty) {
            langCounts[lang] = (langCounts[lang] ?? 0) + 1;
          }

          newRepos.add(Repository(
            name: r['name'] ?? '',
            owner: r['owner']?['login'] ?? '',
            description: r['description'] ?? 'No description provided.',
            difficulty: (r['stargazers_count'] as num) > 50 ? 'Advanced' : ((r['stargazers_count'] as num) > 5 ? 'Intermediate' : 'Beginner'),
            impactScore: ((r['stargazers_count'] as num) * 5 + 40).clamp(40, 100).toInt(),
            tags: lang != null ? [lang] : ['Repo'],
            whyRecommended: 'Based on your GitHub activity and repository engagement.',
          ));
        }

        stars = totalStars;
        commits = reposData.length * 15; // Estimate commits for prototype

        if (newRepos.isNotEmpty) {
          allRepositories = newRepos;
        }

        // Calculate dynamic Developer Score
        developerScore = double.parse(((totalStars * 0.15 + reposData.length * 0.4 + 5.0).clamp(1.0, 10.0)).toStringAsFixed(1));

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
          if (l == 'typescript' || l == 'javascript' || l == 'html' || l == 'css' || l == 'dart') {
            hasFrontend = true;
          }
          if (l == 'go' || l == 'rust' || l == 'python' || l == 'java' || l == 'c#' || l == 'ruby') {
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
    } catch (e) {
      debugPrint('Error fetching GitHub data: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setGithubUsername(String newUsername) async {
    githubUsername = newUsername.trim().replaceAll('@', '');
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('github_username', githubUsername);
    } catch (_) {}

    await fetchGithubData(githubUsername);
    
    if (token != null) {
      try {
        final response = await http.post(
          Uri.parse('${AppConfig.apiBaseUrl}/github/sync-username'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'username': githubUsername,
          }),
        );
        if (response.statusCode == 200) {
          debugPrint('Backend sync-username succeeded');
          showLinkGitHubPrompt = false;
          notifyListeners();
          
          await fetchActivityData();
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

  void setGithubSession(String username, String sessionToken) async {
    token = sessionToken;
    githubUsername = username.trim().replaceAll('@', '');
    showLinkGitHubPrompt = false;
    githubUsernameLocked = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', sessionToken);
      await prefs.setString('github_username', githubUsername);
      await prefs.setBool('pref_github_locked', true);
    } catch (_) {}

    fetchGithubData(githubUsername);
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

  void setEmailSession(String sessionToken) async {
    token = sessionToken;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', sessionToken);
    } catch (_) {}

    await fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        final String? linkedUsername = userData['username'];
        username = userData['name'] ?? 'Alex Johnson';
        avatarUrl = userData['avatar_url'];

        if (linkedUsername != null && linkedUsername.isNotEmpty) {
          githubUsername = linkedUsername;
          showLinkGitHubPrompt = false;

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('github_username', githubUsername);
          } catch (_) {}

          fetchGithubData(githubUsername);
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
      githubUsername = 'alexjohnson';
      _triggerFallbackFetches();
    }
  }

  Future<void> clearSession() async {
    token = null;
    githubUsername = 'alexjohnson';
    avatarUrl = null;
    showLinkGitHubPrompt = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('github_username');
      await prefs.remove('dna_response_cache');
      await prefs.remove('dna_cache_timestamp');
      await prefs.remove('roast_response_cache');
      await prefs.remove('roast_cache_timestamp');
      await prefs.remove('weekly_report_response_cache');
      await prefs.remove('weekly_report_cache_timestamp');
    } catch (_) {}
  }


  Future<void> fetchActivityData() async {
    isLoadingActivity = true;
    notifyListeners();
    try {
      final String urlString = selectedActivityYear == 'Last 14 Weeks'
          ? '${AppConfig.apiBaseUrl}/github/activity'
          : '${AppConfig.apiBaseUrl}/github/activity?year=$selectedActivityYear';
      final response = await http.get(
        Uri.parse(urlString),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> rawList = data['activity'] ?? [];
        activityData = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
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
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
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
          await prefs.setString('dna_response_cache', bodyText);
          await prefs.setInt('dna_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
        } catch (_) {}

        notifications.insert(0, {
          'id': 'dna_${DateTime.now().millisecondsSinceEpoch}',
          'title': 'DNA Archetype Identified: $dnaArchetype',
          'body': 'Your alignment score is $dnaScore%. Click to inspect details.',
          'timestamp': DateTime.now(),
          'isRead': false,
          'type': 'dna',
          'extraData': data,
        });
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
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final bodyText = response.body;
        final data = jsonDecode(bodyText);
        profileRoast = data['roast'];
        roastTips = List<String>.from(data['tips'] ?? []);

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('roast_response_cache', bodyText);
          await prefs.setInt('roast_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
        } catch (_) {}

        notifications.insert(0, {
          'id': 'roast_${DateTime.now().millisecondsSinceEpoch}',
          'title': 'GitHub Profile Roasted! 🔥',
          'body': 'Brutal review is ready. Click to inspect tips and issues.',
          'timestamp': DateTime.now(),
          'isRead': false,
          'type': 'roast',
          'extraData': data,
        });
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
        resumeMissingTech = List<String>.from(data['missing_technologies'] ?? []);
        resumeWeakBullets = List<String>.from(data['weak_bullet_points'] ?? []);
        resumeProjectImprovements = List<String>.from(data['project_improvements'] ?? []);
        resumeMindsetUpgrades = List<String>.from(data['mindset_upgrades'] ?? []);
        resumeSkillUpgrades = List<String>.from(data['skill_upgrades'] ?? []);
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
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: filename,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        resumeAtsScore = data['ats_score'];
        resumeMissingTech = List<String>.from(data['missing_technologies'] ?? []);
        resumeWeakBullets = List<String>.from(data['weak_bullet_points'] ?? []);
        resumeProjectImprovements = List<String>.from(data['project_improvements'] ?? []);
        resumeMindsetUpgrades = List<String>.from(data['mindset_upgrades'] ?? []);
        resumeSkillUpgrades = List<String>.from(data['skill_upgrades'] ?? []);
      }
    } catch (e) {
      debugPrint('Error uploading resume: $e');
    } finally {
      isReviewingResume = false;
      notifyListeners();
    }
  }

  Future<void> evaluateProject(String title) async {
    isEvaluatingProject = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/advanced/evaluate-project'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'project_title': title}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        evaluatedProjectScore = data['score'];
        evaluatedProjectExplanation = data['explanation'];
        evaluatedProjectUpgradePath = List<String>.from(data['upgrade_path'] ?? []);
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
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final bodyText = response.body;
        final data = jsonDecode(bodyText);
        weeklyExplored = data['repositories_explored'];
        weeklySkills = data['skills_learned'];
        weeklyImprovement = data['improvement_percentage'];
        weeklyChartData = List<int>.from(data['chart_data'] ?? []);

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('weekly_report_response_cache', bodyText);
          await prefs.setInt('weekly_report_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
        } catch (_) {}

        notifications.insert(0, {
          'id': 'weekly_${DateTime.now().millisecondsSinceEpoch}',
          'title': 'AI Weekly Report Ready',
          'body': 'You improved by $weeklyImprovement% this week. Click to check chart.',
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

  Future<void> fetchLearningPaths() async {
    isLoadingLearningPaths = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/advanced/learning-paths'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        learningPathTitle = data['path_title'];
        learningPathSteps = data['steps'];
      }
    } catch (e) {
      debugPrint('Error fetching learning paths: $e');
    } finally {
      isLoadingLearningPaths = false;
      notifyListeners();
    }
  }

  Future<void> fetchOpportunities() async {
    isLoadingOpportunities = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/advanced/opportunities'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        techOpportunities = data['opportunities'];

        if (techOpportunities != null && techOpportunities!.isNotEmpty) {
          final firstOppTitle = techOpportunities!.first['title'] ?? 'AI Trend Project';
          notifications.insert(0, {
            'id': 'opp_${DateTime.now().millisecondsSinceEpoch}',
            'title': 'New Build Opportunity',
            'body': 'Trending: "$firstOppTitle". Click to view recommended stack.',
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
        copilotImplementationPlan = List<String>.from(data['implementation_plan'] ?? []);
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
        body: jsonEncode({
          'personal_goal': goal,
          'preferred_stack': stack,
        }),
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

  Future<void> fetchPromptHistory({String? query, String? workflow}) async {
    isLoadingPromptHistory = true;
    notifyListeners();
    try {
      if (token == null) {
        // Load default mock history
        promptHistory = [
          PromptItem(
            id: '1',
            originalPrompt: 'write a python script to scan files for secrets like api keys using regex',
            refinedPrompt: 'Write a Python script that scans files in a directory for potential secrets (e.g., API keys, passwords, and private keys) using regular expressions.\n\n- Provide a command-line interface where the user can pass a target directory path.\n- Define regex patterns for common secret formats (e.g. AWS Keys, JWTs, generic secrets).\n- Output a clean list of findings including file path, line number, and a masked version of the matched secret.',
            score: 88,
            technologies: ['Python', 'Security'],
            workflow: 'Feature Building',
            projectName: 'secret-scanner',
            createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          ),
          PromptItem(
            id: '2',
            originalPrompt: 'flutter button is not showing centered, how to center it',
            refinedPrompt: 'I have a Flutter ElevatedButton that is not centered. How can I align it in the center of the screen?\n\n- Show examples using Center widget, Column with MainAxisAlignment.center, and Align.\n- Explain when to use each approach.',
            score: 72,
            technologies: ['Flutter', 'Dart'],
            workflow: 'Debugging',
            projectName: 'devmentor-app',
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          PromptItem(
            id: '3',
            originalPrompt: 'optimize sql query select * from users join posts where posts.created_at is recent',
            refinedPrompt: 'Explain how to optimize this SQL query:\n\n```sql\nSELECT * FROM users JOIN posts ON users.id = posts.user_id WHERE posts.created_at >= NOW() - INTERVAL \'7 days\';\n```\n\nProvide recommendations on indexes, query structure, and select fields instead of using `*`.',
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
      if (query != null && query.isNotEmpty) params.add('q=${Uri.encodeComponent(query)}');
      if (workflow != null && workflow.isNotEmpty) params.add('workflow=${Uri.encodeComponent(workflow)}');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        promptHistory = data.map((json) => PromptItem.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching prompt history: $e');
    } finally {
      isLoadingPromptHistory = false;
      notifyListeners();
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
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Refresh prompt history, analytics, and recommendations
        fetchPromptHistory();
        fetchPromptAnalytics();
        fetchPromptRecommendations();
        return data['message'] ?? 'Successfully synchronized prompts from GitHub.';
      } else {
        final data = jsonDecode(response.body);
        final String? msg = data['error']?['message'] ?? data['detail'];
        return 'Sync failed: ${msg ?? 'Server returned error ${response.statusCode}'}';
      }
    } catch (e) {
      return 'Sync failed: $e';
    }
  }

  Future<void> fetchPromptAnalytics() async {
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
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        totalPrompts = data['total_prompts'] ?? 0;
        averagePromptScore = (data['average_score'] as num?)?.toDouble() ?? 0.0;
        promptWorkflowCounts = Map<String, int>.from(data['workflow_counts'] ?? {});
        topPromptTechnologies = List<Map<String, dynamic>>.from(
          (data['top_technologies'] ?? []).map((e) => Map<String, dynamic>.from(e))
        );
        promptScoreHistory = List<Map<String, dynamic>>.from(
          (data['score_history'] ?? []).map((e) => Map<String, dynamic>.from(e))
        );
      }
    } catch (e) {
      debugPrint('Error fetching prompt analytics: $e');
    } finally {
      isLoadingPromptAnalytics = false;
      notifyListeners();
    }
  }

  Future<void> fetchPromptRecommendations() async {
    isLoadingPromptRecommendations = true;
    notifyListeners();
    try {
      if (token == null) {
        // Load mock recommendations
        promptRecommendations = [
          {
            'title': 'Mastering Flutter Layout Constraints',
            'description': 'Based on your debugging prompts about Button alignments, you could benefit from understanding Flutter box constraints layout rules.',
            'tags': ['Flutter', 'Layouts'],
            'url': 'https://flutter.dev/docs/development/ui/layout/constraints'
          },
          {
            'title': 'Security Scanners & Secret Scanning in CI/CD',
            'description': 'You have been writing script prompts to scan files for secrets. Check out how tools like GitGuardian or TruffleHog automate this.',
            'tags': ['DevOps', 'Security'],
            'url': 'https://github.com/trufflesecurity/trufflehog'
          },
        ];
        isLoadingPromptRecommendations = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/prompts/recommendations'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        promptRecommendations = List<dynamic>.from(data['recommendations'] ?? []);
      }
    } catch (e) {
      debugPrint('Error fetching prompt recommendations: $e');
    } finally {
      isLoadingPromptRecommendations = false;
      notifyListeners();
    }
  }

  Future<void> submitPromptEvent(String originalPrompt, {String? projectName, String? fileContext}) async {
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
          refinedPrompt: 'Refined Version of:\n$originalPrompt\n\n- Added context\n- Clearly defined inputs, processing steps, and expected outputs.',
          score: 85,
          technologies: ['Dart', 'General'],
          workflow: 'Feature Building',
          projectName: projectName ?? 'local-project',
          createdAt: DateTime.now(),
        );
        promptHistory.insert(0, newPrompt);
        totalPrompts += 1;
        averagePromptScore = ((averagePromptScore * (totalPrompts - 1) + 85) / totalPrompts);
        
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
}


