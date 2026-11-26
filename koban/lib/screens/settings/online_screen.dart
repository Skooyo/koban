import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/kit.dart';
import 'settings_view_model.dart';
import 'settings_widgets.dart';

/// Makes the typed text upper case.
class _UpperCase extends TextInputFormatter {
  const _UpperCase();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Online features: the switch and the invite code.
class OnlineScreen extends StatefulWidget {
  const OnlineScreen({super.key, required this.vm});

  final SettingsViewModel vm;

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final online = vm.onlineFeatures;
        return SettingsPage(
          title: 'Online features',
          children: [
            ListGroup(
              children: [
                SwitchRow(
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
                    leading: const RowIcon(Icons.lock),
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
                          style: text.bodyMedium!.copyWith(color: muted),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _code,
                          onChanged: (_) => setState(() {}),
                          maxLines: 1,
                          autocorrect: false,
                          textCapitalization: TextCapitalization.characters,
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
                                : () => vm.enterInviteCode(_code.text),
                          ),
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
