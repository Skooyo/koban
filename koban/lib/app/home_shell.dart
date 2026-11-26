import 'dart:developer' as developer;

import 'package:material_ui/material_ui.dart';

import '../screens/activity/activity_screen.dart';
import '../screens/groups/groups_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/people/people_screen.dart';
import '../theme/koban_theme.dart';
import '../theme/tokens.dart';
import '../update/update_dialog.dart';
import 'app_services.dart';
import 'auto_open.dart';
import 'routes.dart';

/// The 4 tabs of the tab bar, in the bar order.
enum KobanTab {
  home(Icons.home, 'Home'),
  activity(Icons.receipt_long, 'Activity'),
  people(Icons.person, 'People'),
  groups(Icons.groups, 'Groups');

  const KobanTab(this.icon, this.label);

  final IconData icon;
  final String label;
}

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
  VoidCallback? _stopUpdateWatch;

  /// How many people have an open balance. It drives the badge of the People tab.
  Stream<int>? _openPeople;

  @override
  void initState() {
    super.initState();
    // The group sign-in, the reads and the shared totals sync. The repository starts one time.
    final services = context
        .getInheritedWidgetOfExactType<AppScope>()!
        .services;
    services.online.groups.start();
    // After the first frame: the dialog opens over any page, then the start check runs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _stopUpdateWatch = watchUpdateDialog(context, services.updates);
      services.updates.check(manual: false);
    });
    if (!widget.autoOpen) return;
    // As 0.1.1 on each activity start. A rotation does not restart the activity in Flutter.
    _lifecycle = AppLifecycleListener(onShow: _autoOpen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoOpen());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openPeople ??= AppScope.of(context).people
        .watchPeople()
        .map((people) => people.where((p) => p.hasOpen).length);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _stopUpdateWatch?.call();
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
          top: false,
          bottom: false,
          child: IndexedStack(
            index: _tab.index,
            children: const [
              HomeScreen(),
              ActivityScreen(),
              PeopleScreen(),
              GroupsScreen(),
            ],
          ),
        ),
        // The bar takes its own slot, so the tab pages end above it and their
        // Add buttons and last rows never go under it.
        bottomNavigationBar: StreamBuilder<int>(
          stream: _openPeople,
          initialData: 0,
          builder: (context, snapshot) => KobanTabBar(
            selected: _tab,
            onSelect: select,
            openPeople: snapshot.data ?? 0,
          ),
        ),
      ),
    );
  }
}

/// The floating dark pill of the 4 tabs. Every tab shows its icon with its name under it.
/// The shown tab is a gold pill.
class KobanTabBar extends StatelessWidget {
  const KobanTabBar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.openPeople,
  });

  final KobanTab selected;
  final ValueChanged<KobanTab> onSelect;

  /// The badge count of the People tab. Zero hides the badge.
  final int openPeople;

  @override
  Widget build(BuildContext context) {
    final scene = SceneColors.of(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: ShapeDecoration(
          color: scene.tabBar,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final tab in KobanTab.values)
              Expanded(
                child: _TabItem(
                  tab: tab,
                  selected: tab == selected,
                  badge: tab == KobanTab.people ? openPeople : 0,
                  onTap: () => onSelect(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final KobanTab tab;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scene = SceneColors.of(context);
    final color = selected ? Color(KobanColors.light.onGold) : scene.onTabBar;
    Widget icon = Icon(tab.icon, color: color, size: 22);
    if (badge > 0) {
      icon = Badge(label: Text('$badge'), child: icon);
    }
    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ShapeDecoration(
        color: selected ? MoneyColors.of(context).gold : null,
        shape: const StadiumBorder(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium!.copyWith(color: color),
          ),
        ],
      ),
    );
    Widget target = InkResponse(
      onTap: onTap,
      containedInkWell: true,
      customBorder: const StadiumBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Center(widthFactor: 1, child: face),
      ),
    );
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      onTap: onTap,
      label: [
        if (badge > 0) '$badge open',
        tab.label,
        MaterialLocalizations.of(
          context,
        ).tabLabel(tabIndex: tab.index + 1, tabCount: KobanTab.values.length),
      ].join('\n'),
      excludeSemantics: true,
      child: target,
    );
  }
}
