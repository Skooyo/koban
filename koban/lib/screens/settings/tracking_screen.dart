import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../ui/kit.dart';
import 'settings_view_model.dart';
import 'settings_widgets.dart';

/// Tracking: notification access, the payment apps and the background checks.
class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key, required this.vm});

  final SettingsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final muted = scheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => SettingsPage(
        title: 'Tracking',
        children: [
          ListGroup(
            children: [
              if (!vm.isAccessGranted)
                KobanRow(
                  title: 'Tracking is off',
                  subtitle: 'Koban cannot read notifications.',
                  leading: const RowIcon(Icons.notifications_off),
                  trailing: TextButton(
                    onPressed: vm.openNotificationSettings,
                    child: const Text('Turn on'),
                  ),
                ),
              KobanRow(
                title: 'Payment apps',
                subtitle: switch (vm.paymentAppCount) {
                  0 => 'None chosen. Koban listens to no app.',
                  1 => '1 app chosen',
                  final n => '$n apps chosen',
                },
                leading: const RowIcon(Icons.list_alt),
                showChevron: true,
                onTap: () => openPaymentApps(context),
              ),
              if (vm.isBatteryOptimizationIgnored)
                KobanRow(
                  title: 'Battery optimization',
                  subtitle: 'Off. Good for background tracking.',
                  leading: const RowIcon(Icons.battery_alert),
                  trailing: Icon(
                    Icons.check,
                    semanticLabel: 'Done',
                    color: scheme.primary,
                  ),
                )
              else
                KobanRow(
                  title: 'Battery optimization',
                  subtitle: 'On. Tracking may stop in the background. Tap to turn it off.',
                  subtitleColor: scheme.error,
                  leading: const RowIcon(Icons.battery_alert),
                  showChevron: true,
                  onTap: vm.openBatterySettings,
                  onTapLabel: 'Disable battery optimization',
                ),
              if (vm.isXiaomi) ...[
                KobanRow(
                  title: 'Xiaomi autostart',
                  subtitle:
                      'Autostart and Background autostart are required. '
                      'Do not use “Clear all” in recents: it can revoke notification access.',
                  subtitleColor: scheme.error,
                  leading: const RowIcon(Icons.settings),
                  showChevron: true,
                  onTap: vm.openBackgroundSettings,
                  onTapLabel: 'Open Xiaomi autostart and battery settings',
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final step in xiaomiChecklist)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $step',
                            style: text.bodyMedium!.copyWith(color: muted),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'You do not need to keep the app open. After you allow notification access, '
              'a small notification keeps Android from stopping Koban. '
              'Checklist: allow notification access, allow that notification, then make a payment. '
              'Open Troubleshooting if nothing is saved.',
              style: text.bodySmall!.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
