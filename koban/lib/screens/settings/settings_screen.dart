import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../app/routes.dart';
import '../../theme/koban_theme.dart';
import '../../ui/kit.dart';
import '../../ui/listener_status_banner.dart';
import '../../ui/undo_snack_bar.dart';
import 'settings_view_model.dart';

/// Makes the typed text upper case.
class _UpperCase extends TextInputFormatter {
  const _UpperCase();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Settings: tracking, appearance, categories, online features, background and about.
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
  final _newCategory = TextEditingController();
  final _code = TextEditingController();
  final _parserInput = TextEditingController();

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
    _newCategory.dispose();
    _code.dispose();
    _parserInput.dispose();
    super.dispose();
  }

  Future<void> _deleteCategory(
    SettingsViewModel vm,
    String id,
    String name,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final undo = await vm.deleteCategory(id);
    if (undo != null) {
      showUndoSnackBar(messenger, 'Category deleted: $name', undo: undo);
    }
  }

  void _addCategory() {
    _vm!.addCategory(_newCategory.text);
    setState(_newCategory.clear);
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final muted = scheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final online = vm.onlineFeatures;
        final reconnect = vm.reconnectMessage;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Semantics(
                            header: true,
                            child: Text('Settings', style: text.titleLarge),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (vm.loadError case final error?) ...[
                        WarningRow(error),
                        const SizedBox(height: 8),
                      ],
                      const SectionHeading('Tracking'),
                      ListenerStatusBanner(
                        isAccessGranted: vm.isAccessGranted,
                        onEnable: vm.openNotificationSettings,
                      ),
                      const SizedBox(height: 8),
                      ListGroup(
                        children: [
                          KobanRow(
                            title: 'Payment apps',
                            subtitle: switch (vm.paymentAppCount) {
                              0 => 'None chosen. Koban listens to no app.',
                              1 => '1 app chosen',
                              final n => '$n apps chosen',
                            },
                            leading: const Icon(Icons.list_alt),
                            showChevron: true,
                            onTap: () => openPaymentApps(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SectionHeading('Troubleshooting'),
                      ListGroup(
                        children: [
                          KobanRow(
                            title: 'Notification log',
                            subtitle: vm.capturedCount > 0
                                ? '${vm.capturedCount} ${vm.capturedCount == 1 ? 'notification' : 'notifications'} captured'
                                : 'Every notification the listener receives, with save and skip reasons',
                            leading: const Icon(Icons.list),
                            showChevron: true,
                            onTap: () => openNotificationLog(context),
                          ),
                          KobanRow(
                            title: 'Restart payment tracking',
                            subtitle: reconnect == null
                                ? 'Use this when new payments stop showing up in Koban.'
                                : '$reconnect If an alert appears, tap it or open notification access settings.',
                            subtitleColor: reconnect == null
                                ? null
                                : scheme.primary,
                            leading: const Icon(Icons.sync),
                            showChevron: true,
                            onTap: vm.reconnect,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SectionHeading('Appearance'),
                      ListGroup(
                        children: [
                          _SwitchRow(
                            title: 'Dark mode',
                            subtitle: 'Use the dark theme across the app',
                            icon: Icons.palette,
                            value: vm.darkMode,
                            onChanged: vm.setDarkMode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SectionHeading('Categories'),
                      if (vm.categories.isNotEmpty)
                        ListGroup(
                          children: [
                            if (vm.categories.any((c) => c.isDefault))
                              KobanRow(
                                title:
                                    '${vm.categories.where((c) => c.isDefault).length} built-in categories',
                                subtitle: [
                                  for (final c in vm.categories)
                                    if (c.isDefault) c.name,
                                ].join(', '),
                              ),
                            for (final c in vm.categories.where(
                              (c) => !c.isDefault,
                            ))
                              KobanRow(
                                key: ValueKey(c.id),
                                title: c.name,
                                subtitle: 'Your own',
                                leading: CategoryDot(
                                  categoryColor(context, c.id),
                                ),
                                trailing: IconButton(
                                  onPressed: () =>
                                      _deleteCategory(vm, c.id, c.name),
                                  tooltip: 'Remove category ${c.name}',
                                  icon: const Icon(Icons.delete),
                                ),
                              ),
                          ],
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newCategory,
                                onChanged: (_) => setState(() {}),
                                maxLines: 1,
                                decoration: const InputDecoration(
                                  labelText: 'New category',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TonalButton(
                              'Add',
                              _newCategory.text.trim().isEmpty
                                  ? null
                                  : _addCategory,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Categories and notes are saved on this phone only.',
                          style: text.bodySmall!.copyWith(color: muted),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SectionHeading('Online'),
                      ListGroup(
                        children: [
                          _SwitchRow(
                            title: 'Online features',
                            subtitle: online
                                ? 'On: groups and reading receipts with Claude can use the internet.'
                                : 'Off: Koban makes no network calls. Groups and reading receipts with Claude stop.',
                            icon: Icons.cloud,
                            value: online,
                            onChanged: vm.setOnlineFeatures,
                          ),
                          if (vm.hasDeviceToken)
                            KobanRow(
                              title: 'Invite code',
                              subtitle: "Accepted. Receipts are read by Claude on Koban's server.",
                              leading: const Icon(Icons.lock),
                              trailing: TextButton(
                                onPressed: vm.removeDeviceToken,
                                child: const Text('Remove'),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Invite code', style: text.titleMedium),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Enter an invite code from Koban's owner to read receipts with Claude. "
                                    'Everything else works without one.',
                                    style: text.bodyMedium!.copyWith(
                                      color: muted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _code,
                                    onChanged: (_) => setState(() {}),
                                    maxLines: 1,
                                    autocorrect: false,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: const [_UpperCase()],
                                    decoration: InputDecoration(
                                      labelText: 'XXXX-XXXX',
                                      errorText: vm.inviteMessage,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TonalButton(
                                      vm.inviteBusy ? 'Checking…' : 'Use code',
                                      _code.text.trim().isEmpty || vm.inviteBusy
                                          ? null
                                          : () =>
                                                vm.enterInviteCode(_code.text),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SectionHeading('Background'),
                      ListGroup(
                        children: [
                          if (vm.isBatteryOptimizationIgnored)
                            KobanRow(
                              title: 'Battery optimization',
                              subtitle: 'Off. Good for background tracking.',
                              leading: const Icon(Icons.battery_alert),
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
                              leading: const Icon(Icons.battery_alert),
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
                              leading: const Icon(Icons.settings),
                              showChevron: true,
                              onTap: vm.openBackgroundSettings,
                              onTapLabel:
                                  'Open Xiaomi autostart and battery settings',
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
                                        style: text.bodyMedium!.copyWith(
                                          color: muted,
                                        ),
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
                          'You do not need to keep the app open. After you grant notification access, a small '
                          'persistent notification keeps Android from stopping the listener. '
                          'Checklist: enable Notification access, allow that notification, then make a payment. '
                          'Check the notification log if nothing is saved.',
                          style: text.bodySmall!.copyWith(color: muted),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SectionHeading('About'),
                      ListGroup(
                        children: [
                          KobanRow(
                            title: 'App version ${vm.versionName}',
                            subtitle: !online
                                ? 'Turn on Online features to check for updates.'
                                : vm.upToDate
                                ? 'Koban is up to date.'
                                : null,
                            leading: const Icon(Icons.info),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: TextButton(
                                onPressed: online ? vm.checkForUpdates : null,
                                child: const Text('Check for updates'),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Parser test tool',
                                  style: text.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Paste a sample notification to check amount and shop extraction.',
                                  style: text.bodyMedium!.copyWith(
                                    color: muted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _parserInput,
                                  minLines: 3,
                                  maxLines: null,
                                  decoration: const InputDecoration(
                                    labelText: 'Notification text',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TonalButton(
                                  'Test parse',
                                  () => vm.runParserTest(_parserInput.text),
                                ),
                                if (vm.parserResult != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      vm.parserResult!,
                                      style: text.bodyMedium,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A row with a switch. The whole row takes the tap. The switch only shows the state.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      toggled: value,
      child: KobanRow(
        title: title,
        subtitle: subtitle,
        leading: Icon(icon),
        trailing: ExcludeSemantics(
          child: IgnorePointer(
            child: Switch(value: value, onChanged: (_) {}),
          ),
        ),
        onTap: () => onChanged(!value),
      ),
    ),
  );
}
