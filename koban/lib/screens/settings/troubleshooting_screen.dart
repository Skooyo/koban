import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../ui/kit.dart';
import 'settings_view_model.dart';
import 'settings_widgets.dart';

/// Troubleshooting: the notification log, the restart and the notification test.
class TroubleshootingScreen extends StatefulWidget {
  const TroubleshootingScreen({super.key, required this.vm});

  final SettingsViewModel vm;

  @override
  State<TroubleshootingScreen> createState() => _TroubleshootingScreenState();
}

class _TroubleshootingScreenState extends State<TroubleshootingScreen> {
  final _sample = TextEditingController();

  @override
  void dispose() {
    _sample.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final muted = scheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final reconnect = vm.reconnectMessage;
        return SettingsPage(
          title: 'Troubleshooting',
          children: [
            ListGroup(
              children: [
                KobanRow(
                  title: 'Notification log',
                  subtitle: vm.capturedCount > 0
                      ? '${vm.capturedCount} ${vm.capturedCount == 1 ? 'notification' : 'notifications'} captured'
                      : 'Every notification Koban receives, with the reason it was saved or skipped',
                  leading: const RowIcon(Icons.list),
                  showChevron: true,
                  onTap: () => openNotificationLog(context),
                ),
                KobanRow(
                  title: 'Restart payment tracking',
                  subtitle: reconnect == null
                      ? 'Use this when new payments stop showing up in Koban.'
                      : '$reconnect If an alert appears, tap it or open notification access settings.',
                  subtitleColor: reconnect == null ? null : scheme.primary,
                  leading: const RowIcon(Icons.sync),
                  showChevron: true,
                  onTap: vm.reconnect,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Test a notification', style: text.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Paste a sample notification to check the amount and shop.',
                        style: text.bodyMedium!.copyWith(color: muted),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _sample,
                        minLines: 3,
                        maxLines: null,
                        decoration: const InputDecoration(
                          labelText: 'Notification text',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TonalButton(
                        'Test notification',
                        () => vm.runParserTest(_sample.text),
                      ),
                      if (vm.parserResult != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(vm.parserResult!, style: text.bodyMedium),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
