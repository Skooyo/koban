import 'dart:developer' as developer;

import 'package:material_ui/material_ui.dart';

import '../screens/activity/activity_screen.dart';
import '../screens/home/home_screen.dart';
import 'app_services.dart';
import 'auto_open.dart';
import 'online_placeholder.dart';
import 'routes.dart';

/// The 4 tabs of the tab bar, in the bar order.
enum KobanTab { home, activity, people, groups }

/// The 4 tabs over the tab bar. A tab switch shows the new tab at once,
/// and each tab keeps its state.
/// After the first frame and each time the app comes to the front, it opens
/// onboarding, the payment apps picker or Check payments when one is due ([AutoOpen]).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.autoOpen = true});

  /// False turns off the auto-open. Tests that start on Home use it.
  final bool autoOpen;

  static HomeShellState of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>()!;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  KobanTab _tab = KobanTab.home;
  AppLifecycleListener? _lifecycle;
  var _autoOpening = false;

  @override
  void initState() {
    super.initState();
    if (!widget.autoOpen) return;
    // As 0.1.1 on each activity start. A rotation does not restart the activity in Flutter.
    _lifecycle = AppLifecycleListener(onShow: _autoOpen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoOpen());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  /// Opens the due page when Home is the top page. One check at a time,
  /// so the first frame and a show at the same moment open one page.
  Future<void> _autoOpen() async {
    if (_autoOpening || !mounted) return;
    _autoOpening = true;
    try {
      final target = await AutoOpen(AppScope.of(context)).decide();
      if (target == null ||
          !mounted ||
          ModalRoute.isCurrentOf(context) != true) {
        return;
      }
      switch (target) {
        case AutoOpenTarget.onboarding:
          openOnboarding(context);
        case AutoOpenTarget.paymentApps:
          openPaymentApps(context);
        case AutoOpenTarget.checkPayments:
          openCheckPayments(context);
      }
    } catch (e, s) {
      developer.log(
        'Auto-open check failed',
        name: 'HomeShell',
        error: e,
        stackTrace: s,
      );
    } finally {
      _autoOpening = false;
    }
  }

  /// The tab that shows.
  KobanTab get tab => _tab;

  /// Shows [tab], as a tap on the tab bar does.
  void select(KobanTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    // As in 0.1.1, Back on another tab shows Home at once. Back on Home closes the app.
    return PopScope(
      canPop: _tab == KobanTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) select(KobanTab.home);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tab.index,
            children: const [
              HomeScreen(),
              ActivityScreen(),
              SizedBox.shrink(), // People: plan 4c.
              OnlinePlaceholder(OnlineFeature.groups),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (i) => select(KobanTab.values[i]),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(
              icon: Icon(Icons.receipt_long),
              label: 'Activity',
            ),
            NavigationDestination(icon: Icon(Icons.people), label: 'People'),
            NavigationDestination(icon: Icon(Icons.groups), label: 'Groups'),
          ],
        ),
      ),
    );
  }
}
