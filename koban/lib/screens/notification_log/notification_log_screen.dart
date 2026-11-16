import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../capture/capture_host.dart';
import '../../capture/listener_control.dart';
import '../../rules/card_mask.dart';
import '../../theme/koban_theme.dart';
import '../../ui/date_labels.dart';
import '../../ui/undo_snack_bar.dart';
import 'notification_log_view_model.dart';

/// The notification log: what the listener received and what Koban did with each text.
/// [poll] is the time between two reads of the log. [reconnectWait] is the time from a
/// reconnect to its result. 0.1.1 waits 65 s.
class NotificationLogScreen extends StatefulWidget {
  const NotificationLogScreen({
    super.key,
    this.poll = const Duration(seconds: 2),
    this.reconnectWait = const Duration(seconds: 65),
  });

  final Duration poll;
  final Duration reconnectWait;

  @override
  State<NotificationLogScreen> createState() => _NotificationLogScreenState();
}

class _NotificationLogScreenState extends State<NotificationLogScreen> {
  NotificationLogViewModel? _vm;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _vm?.pausePolling(),
      onResume: () {
        _vm?.resumePolling();
        _vm?.refresh();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vm == null) {
      _vm = NotificationLogViewModel(
        AppScope.of(context),
        poll: widget.poll,
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
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final shown = vm.shown;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
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
                            child: Text(
                              'Notification log',
                              style: text.titleLarge,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: vm.refresh,
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StatusCard(vm: vm),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (f, label) in const [
                            (LogFilter.all, 'All'),
                            (LogFilter.saved, 'Saved'),
                            (LogFilter.notPayment, 'Not a payment'),
                            (LogFilter.noText, 'No text'),
                          ])
                            FilterChip(
                              selected: vm.filter == f,
                              onSelected: (_) => vm.setFilter(f),
                              label: Text(label),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (shown.isEmpty)
                        Text(
                          vm.rows.isEmpty
                              ? 'No notifications captured yet. Make a payment or tap “Scan now” after granting access.'
                              : 'No notifications match this filter.',
                          style: text.bodyMedium!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        for (final n in shown)
                          Padding(
                            key: ValueKey('log-${n.id}'),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _LogCard(
                              n,
                              app: vm.appLabel(n.packageName),
                              marked: vm.isMarked(n.id),
                              onMark: vm.isMarked(n.id)
                                  ? null
                                  : () => vm.markAsPayment(n),
                            ),
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

/// "Today, 19:41" or "Fri, 13 Nov, 19:41".
String _when(int ms, DateTime now) =>
    '${dateLabel(ms, now)}, ${DateFormat('HH:mm', 'en_US').format(DateTime.fromMillisecondsSinceEpoch(ms))}';

/// A card with the rounded surface of the 0.1.1 log.
class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.vm});

  final NotificationLogViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final money = MoneyColors.of(context);
    final healthy = vm.isAccessGranted && vm.isConnected;
    final message = vm.message;
    final (seen, saved, skipped) = vm.todayCounts(AppScope.of(context).now());
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: healthy ? money.received : money.review,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  !vm.isAccessGranted
                      ? 'Notification access not granted'
                      : !vm.isConnected
                      ? 'Access granted, listener not connected'
                      : 'Koban can read notifications',
                  style: text.titleMedium!.copyWith(color: scheme.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$seen seen today · $saved saved · $skipped skipped',
            style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: vm.snapshot,
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Scan now'),
              ),
              TextButton(
                onPressed: vm.reconnect,
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Restart payment tracking'),
              ),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final undo = await vm.clearLog();
                  if (undo != null) {
                    showUndoSnackBar(messenger, 'Log cleared', undo: undo);
                  }
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: scheme.error,
                ),
                child: const Text('Clear log'),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: text.bodySmall!.copyWith(color: scheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard(
    this.n, {
    required this.app,
    required this.marked,
    required this.onMark,
  });

  final LoggedNotification n;
  final String app;

  /// True when Save payment made a card for this row while the screen is open.
  final bool marked;

  /// Null hides Save payment: the row has a card already.
  final VoidCallback? onMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final muted = scheme.onSurfaceVariant;
    final waiting = n.disposition == NotificationDisposition.waiting;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$app · ${_when(n.postTime, AppScope.of(context).now())}',
            style: text.labelMedium!.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Text(
            maskCardDigits(n.body),
            style: text.bodyMedium!.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            marked ? 'Saved as a payment' : _reason(n.disposition),
            style: text.bodyMedium!.copyWith(
              color: waiting && !marked
                  ? MoneyColors.of(context).review
                  : muted,
            ),
          ),
          // Any logged notification the app did not turn into a card: skipped, missed or only seen in the tray.
          if (onMark != null &&
              n.disposition != NotificationDisposition.waiting &&
              n.disposition != NotificationDisposition.pending)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onMark,
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Save payment'),
              ),
            ),
        ],
      ),
    );
  }
}

/// One plain line about what Koban did with the notification.
String _reason(NotificationDisposition d) => switch (d) {
  NotificationDisposition.pending => 'Koban is reading this message.',
  NotificationDisposition.waiting => 'Waiting in Check payments',
  NotificationDisposition.skippedAllowlist =>
    'Skipped: this app is not one of your payment apps.',
  NotificationDisposition.skippedNoRule =>
    'Skipped: this message has no amount.',
  NotificationDisposition.skippedDuplicate =>
    'Skipped: Koban already has this payment.',
  NotificationDisposition.skippedGroupSummary =>
    'Skipped: this is a summary of other notifications.',
  NotificationDisposition.skippedEmpty => 'Skipped: this message has no text.',
  NotificationDisposition.skippedError =>
    'Skipped: Koban could not read this message.',
  NotificationDisposition.infoOnly => 'Seen only. Koban did not save it.',
};
