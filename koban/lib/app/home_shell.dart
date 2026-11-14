import 'package:material_ui/material_ui.dart';

import '../screens/activity/activity_screen.dart';
import '../screens/home/home_screen.dart';
import 'online_placeholder.dart';

/// The 4 tabs of the tab bar, in the bar order.
enum KobanTab { home, activity, people, groups }

/// The 4 tabs over the tab bar. A tab switch shows the new tab at once,
/// and each tab keeps its state.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static HomeShellState of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>()!;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  KobanTab _tab = KobanTab.home;

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
