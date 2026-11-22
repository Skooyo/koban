import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/koban_theme.dart';
import 'app_services.dart';
import 'home_shell.dart';
import 'routes.dart';

/// The system bars follow the theme: the navigation bar has the page color, as the
/// pill tab bar floats on the page,
/// and the icons of both bars are light on dark and dark on light.
SystemUiOverlayStyle systemBarStyle(ThemeData theme) {
  final icons = theme.brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    statusBarIconBrightness: icons,
    systemNavigationBarColor: theme.scaffoldBackgroundColor,
    systemNavigationBarDividerColor: const Color(0x00000000),
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: false,
  );
}

/// The app root. The stored dark mode setting picks the theme, not the phone setting.
/// While the app is in front, it looks for cards of the capture engine.
/// When the app goes to the background, it commits a held swipe of Check payments at once.
class KobanApp extends StatefulWidget {
  const KobanApp({
    super.key,
    required this.services,
    this.home = const HomeShell(),
  });

  final AppServices services;

  /// The first page. Tests give another page.
  final Widget home;

  @override
  State<KobanApp> createState() => _KobanAppState();
}

class _KobanAppState extends State<KobanApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final s = widget.services;
    final writes = s.externalWrites;
    // The app is in front when it starts. Later starts come from onResume.
    writes.start();
    _lifecycle = AppLifecycleListener(
      onResume: writes.start,
      onHide: () {
        writes.stop();
        // As 0.1.1 `MainActivity.onStop`: a swipe in the Undo window must not wait on a hidden app.
        s.paymentChecks.flushHold();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.services.externalWrites.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.home;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.services.settings.darkMode,
      builder: (context, dark, _) => MaterialApp(
        title: 'Koban',
        debugShowCheckedModeBanner: false,
        theme: kobanTheme(Brightness.light),
        darkTheme: kobanTheme(Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        // The night color under the pages, so the page below darkens toward night.
        builder: (context, navigator) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemBarStyle(Theme.of(context)),
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            // The status bar is see-through and every page starts with a scene band, so a
            // band-colored strip keeps scrolled content out from under the clock.
            child: Stack(
              children: [
                navigator!,
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.paddingOf(context).top,
                  child: ColoredBox(color: SceneColors.of(context).band),
                ),
              ],
            ),
          ),
        ),
        onGenerateInitialRoutes: (_) => [KobanPageRoute(builder: (_) => home)],
        // The app has no named routes. A route builder must be set, or the app has no Navigator.
        onGenerateRoute: (_) => null,
      ),
    );
  }
}
