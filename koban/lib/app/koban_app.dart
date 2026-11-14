import 'package:material_ui/material_ui.dart';

import '../theme/koban_theme.dart';
import 'app_services.dart';
import 'home_shell.dart';
import 'routes.dart';

/// The app root. The stored dark mode setting picks the theme, not the phone setting.
class KobanApp extends StatelessWidget {
  const KobanApp({
    super.key,
    required this.services,
    this.home = const HomeShell(),
  });

  final AppServices services;

  /// The first page. Tests give another page.
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: services.settings.darkMode,
      builder: (context, dark, _) => MaterialApp(
        title: 'Koban',
        debugShowCheckedModeBanner: false,
        theme: kobanTheme(Brightness.light),
        darkTheme: kobanTheme(Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        // The night color under the pages, so the page below darkens toward night.
        builder: (context, navigator) => ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: navigator,
        ),
        onGenerateInitialRoutes: (_) => [KobanPageRoute(builder: (_) => home)],
        // The app has no named routes. A route builder must be set, or the app has no Navigator.
        onGenerateRoute: (_) => null,
      ),
    );
  }
}
