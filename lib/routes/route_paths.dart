class RoutePaths {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const emailAuth = '/email-auth';
  static const app = '/';
  static const mentor = '/mentor';

  // Tab names used as query parameter values for /?tab=<name>
  static const tabNames = ['home', 'explore', 'prompts', 'roadmap', 'settings'];

  /// Returns the tab index for a given tab name, or 0 (home) if not found.
  static int tabIndexFromName(String? name) {
    if (name == null) return 0;
    final index = tabNames.indexOf(name.toLowerCase());
    return index >= 0 ? index : 0;
  }

  /// Builds a root URL with the tab query parameter.
  static String appTab(int index) {
    final name = (index >= 0 && index < tabNames.length)
        ? tabNames[index]
        : tabNames[0];
    return '/?tab=$name';
  }
}
