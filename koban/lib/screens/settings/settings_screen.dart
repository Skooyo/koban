import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../app/routes.dart';
import '../../theme/koban_theme.dart';
import '../../ui/kit.dart';
import '../../ui/scene_band.dart';
import 'categories_screen.dart';
import 'online_screen.dart';
import 'settings_view_model.dart';
import 'settings_widgets.dart';
import 'tracking_screen.dart';
import 'troubleshooting_screen.dart';

/// Settings: a short list. Each section opens its own page.
/// [reconnectWait] is the time from a reconnect to its result. 0.1.1 waits 65 s.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.reconnectWait = const Duration(seconds: 65),
  });

  final Duration reconnectWait;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsViewModel? _vm;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => _vm?.refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vm == null) {
      _vm = SettingsViewModel(
        AppScope.of(context),
        reconnectWait: widget.reconnectWait,
      );
      _vm!.refresh();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final online = vm.onlineFeatures;
        final apps = switch (vm.paymentAppCount) {
          0 => 'no app chosen',
          1 => '1 app chosen',
          final n => '$n apps chosen',
        };
        final limits = vm.limits.length;
        return Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              const TaskHeader(title: 'Settings'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (vm.loadError case final error?) ...[
                      WarningRow(error),
                      const SizedBox(height: 8),
                    ],
                    ListGroup(
                      children: [
                        KobanRow(
                          title: 'Tracking',
                          subtitle: vm.isAccessGranted
                              ? 'On · $apps'
                              : 'Off · Koban cannot read notifications',
                          subtitleColor: vm.isAccessGranted
                              ? null
                              : Theme.of(context).colorScheme.error,
                          leading: const RowIcon(Icons.notifications),
                          showChevron: true,
                          onTap: () =>
                              pushPage<void>(context, TrackingScreen(vm: vm)),
                        ),
                        KobanRow(
                          title: 'Categories and budgets',
                          subtitle:
                              '${vm.categories.length} categories · '
                              '$limits monthly ${limits == 1 ? 'limit' : 'limits'}',
                          leading: const RowIcon(Icons.category),
                          showChevron: true,
                          onTap: () =>
                              pushPage<void>(context, CategoriesScreen(vm: vm)),
                        ),
                        KobanRow(
                          title: 'Online features',
                          subtitle: !online
                              ? 'Off'
                              : vm.hasDeviceToken
                              ? 'On · invite code accepted'
                              : 'On · no invite code',
                          leading: const RowIcon(Icons.cloud),
                          showChevron: true,
                          onTap: () =>
                              pushPage<void>(context, OnlineScreen(vm: vm)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListGroup(
                      children: [
                        SwitchRow(
                          title: 'Dark mode',
                          icon: Icons.palette,
                          value: vm.darkMode,
                          onChanged: vm.setDarkMode,
                        ),
                        KobanRow(
                          title: 'Check for updates',
                          subtitle: !online
                              ? 'Turn on Online features to check for updates.'
                              : vm.upToDate
                              ? 'Koban is up to date.'
                              : null,
                          leading: const RowIcon(Icons.system_update),
                          showChevron: online,
                          onTap: online ? vm.checkForUpdates : null,
                        ),
                        KobanRow(
                          title: 'Troubleshooting',
                          subtitle: 'Notification log, restart tracking, test a notification',
                          leading: const RowIcon(Icons.build),
                          showChevron: true,
                          onTap: () => pushPage<void>(
                            context,
                            TroubleshootingScreen(vm: vm),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Koban ${vm.versionName}',
                      textAlign: TextAlign.center,
                      style: tabular(text.bodySmall!.copyWith(color: muted)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
