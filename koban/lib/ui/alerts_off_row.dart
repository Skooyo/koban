import 'dart:developer' as developer;

import 'package:material_ui/material_ui.dart';

import '../device/device_control.dart';
import '../theme/koban_theme.dart';
import 'kit.dart';

/// True when Android blocks Koban's own notifications. A failed check counts as allowed,
/// so no false warning shows.
Future<bool> alertsBlocked(DeviceControl device) async {
  try {
    return !await device.notificationsAllowed();
  } catch (e, s) {
    developer.log('Alerts not read', name: 'Alerts', error: e, stackTrace: s);
    return false;
  }
}

/// Asks Android for the notification permission again. After two denials Android
/// shows no dialog, so then it opens Koban's notification settings.
Future<void> turnOnAlerts(DeviceControl device) async {
  try {
    if (await device.requestNotificationPermission()) return;
    if (!await device.shouldShowNotificationRationale()) {
      await device.openAppNotificationSettings();
    }
  } catch (e, s) {
    developer.log('Alerts not asked', name: 'Alerts', error: e, stackTrace: s);
  }
}

/// "Koban notifications are off" with a Turn on button.
class AlertsOffRow extends StatelessWidget {
  const AlertsOffRow({super.key, required this.onTurnOn});

  final VoidCallback onTurnOn;

  @override
  Widget build(BuildContext context) => ListGroup(
    children: [
      KobanRow(
        title: 'Koban notifications are off',
        subtitle: 'You do not get told about new payments to check.',
        leading: Icon(
          Icons.notifications_off,
          color: MoneyColors.of(context).review,
        ),
        trailing: TextButton(onPressed: onTurnOn, child: const Text('Turn on')),
      ),
    ],
  );
}
