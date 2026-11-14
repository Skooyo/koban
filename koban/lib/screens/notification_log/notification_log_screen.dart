import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../capture/capture_host.dart';
import '../../capture/listener_control.dart';
import '../../theme/koban_theme.dart';
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
                            (LogFilter.postedOnly, 'Posted'),
                            (LogFilter.waiting, 'Waiting'),
                            (LogFilter.skipped, 'Skipped'),
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
                              ? 'No notifications captured yet. Make a payment or tap “Snapshot active notifications” after granting access.'
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

/// The time of a log row in the local zone, as 0.1.1 shows it.
String _stamp(int ms) => DateFormat(
  'MMM d, HH:mm:ss',
  'en_US',
).format(DateTime.fromMillisecondsSinceEpoch(ms));

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
    final state = vm.listenerState;
    final last = state.lastConnectedAt;
    final message = vm.message;
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
                      : 'Listener active',
                  style: text.titleMedium!.copyWith(color: scheme.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Captured ${vm.rows.length} · ${state.isConnected ? 'listener connected' : 'listener not connected'}'
            '${last == null ? '' : ' · last connected ${_stamp(last)}'}',
            style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton(
                onPressed: vm.reconnect,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Reconnect listener'),
              ),
              OutlinedButton(
                onPressed: vm.snapshot,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Snapshot'),
              ),
              TextButton(
                onPressed: vm.clearLog,
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
  const _LogCard(this.n, {required this.onMark});

  final LoggedNotification n;

  /// Null hides Add as payment: the row has a card already.
  final VoidCallback? onMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final muted = scheme.onSurfaceVariant;
    final color = _dispositionColor(context, n.disposition);
    final title = n.title;
    final detail = n.detail;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${n.packageName} · ${_eventLabel(n.event)} · ${_stamp(n.capturedAt)}',
                  style: text.labelMedium!.copyWith(color: muted),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: color),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  _dispositionLabel(n.disposition),
                  style: text.labelSmall!.copyWith(color: color),
                ),
              ),
            ],
          ),
          if (title != null) ...[
            const SizedBox(height: 4),
            Text(
              title,
              style: text.titleMedium!.copyWith(color: scheme.onSurface),
            ),
          ],
          const SizedBox(height: 4),
          Text(n.body, style: text.bodyMedium!.copyWith(color: muted)),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail, style: text.bodySmall!.copyWith(color: muted)),
          ],
          const SizedBox(height: 4),
          Text(
            'Posted ${_stamp(n.postTime)}',
            style: text.labelSmall!.copyWith(color: muted),
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
                label: const Text('Add as payment'),
              ),
            ),
        ],
      ),
    );
  }
}

String _eventLabel(CaptureEvent e) => switch (e) {
  CaptureEvent.posted => 'Posted',
  CaptureEvent.removed => 'Removed',
  CaptureEvent.activeSnapshot => 'Active',
};

String _dispositionLabel(NotificationDisposition d) => switch (d) {
  NotificationDisposition.pending => 'Pending',
  NotificationDisposition.waiting => 'Waiting for check',
  NotificationDisposition.skippedAllowlist => 'Not a payment app',
  NotificationDisposition.skippedNoRule => 'No rule matched',
  NotificationDisposition.skippedDuplicate => 'Duplicate',
  NotificationDisposition.skippedGroupSummary => 'Group',
  NotificationDisposition.skippedEmpty => 'Empty',
  NotificationDisposition.skippedError => 'Error',
  NotificationDisposition.infoOnly => 'Info',
};

Color _dispositionColor(BuildContext context, NotificationDisposition d) {
  final scheme = Theme.of(context).colorScheme;
  return switch (d) {
    NotificationDisposition.waiting => MoneyColors.of(context).review,
    NotificationDisposition.skippedNoRule ||
    NotificationDisposition.skippedError => scheme.error,
    NotificationDisposition.pending => scheme.primary,
    _ => scheme.onSurfaceVariant,
  };
}
