class RoutePaths {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const emailAuth = '/email-auth';
  static const app = '/';
  static const mentor = '/mentor';
  static const memory = '/memory';
  static const pulse = '/pulse';
  static const studio = '/studio';
  static const career = '/career';

  static const tabNames = ['home', 'explore', 'chat', 'roadmap', 'settings'];

  static int tabIndexFromName(String? name) {
    if (name == null) return 0;
    final index = tabNames.indexOf(name.toLowerCase());
    return index >= 0 ? index : 0;
  }

  static String appTab(int index) {
    final name = (index >= 0 && index < tabNames.length)
        ? tabNames[index]
        : tabNames[0];
    return '/?tab=$name';
  }
}
