import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/capture/listener_control.dart';
import 'package:koban/data/database.dart';
import 'package:koban/screens/notification_log/notification_log_screen.dart';
import 'package:koban/screens/notification_log/notification_log_view_model.dart';
import 'package:material_ui/material_ui.dart';

import '../capture/fake_capture_host.dart';
import '../support/harness.dart';

const maybank = 'com.maybank2u.life';
const sample =
    'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.';
const statement = 'Your statement is ready.';
const emptyAll =
    'No notifications captured yet. Make a payment or tap “Scan now” after granting access.';
const emptyFilter = 'No notifications match this filter.';
const postTime = 1761999940000;
const capturedAt = 1761999940500;

/// The time of a row older than today, as the log shows it.
String stamp(int ms) => DateFormat(
  'EEE, d MMM, HH:mm',
  'en_US',
).format(DateTime.fromMillisecondsSinceEpoch(ms));

Map<String, Object?> row(
  String id, {
  String disposition = 'WAITING',
  String event = 'POSTED',
  String body = sample,
  String? title = 'Maybank',
  String? detail = 'RESTORAN CONTOH · RM 15.00',
}) => {
  'id': id,
  'packageName': maybank,
  'title': title,
  'body': body,
  'postTime': postTime,
  'capturedAt': capturedAt,
  'event': event,
  'disposition': disposition,
  'detail': detail,
};

List<Map<String, Object?>> threeRows() => [
  row('a'),
  row('b', disposition: 'SKIPPED_NO_RULE', body: statement, detail: null),
  row('c', disposition: 'INFO_ONLY', event: 'REMOVED', title: null),
];

LoggedNotification logged(String disposition, {String event = 'POSTED'}) =>
    LoggedNotification.fromMap(
      row('x', disposition: disposition, event: event),
    );

FakeChannel logChannel({
  List<Map<String, Object?>>? rows,
  bool connected = true,
  String reconnect = 'ATTEMPTED',
  bool snapshot = true,
}) => FakeChannel(ListenerControl.channelName, {
  'isAccessGranted': true,
  'isConnected': connected,
  'recentNotifications': rows ?? threeRows(),
  'listenerState': {
    'isConnected': connected,
    'lastConnectedAt': postTime,
    'lastDisconnectedAt': null,
    'totalCaptured': 3,
  },
  'reconnect': reconnect,
  'snapshotActive': snapshot,
});

int calls(FakeChannel c, String method) =>
    c.calls.where((x) => x.method == method).length;

Future<void> pumpLog(
  WidgetTester tester,
  AppServices s, {
  double textScale = 1,
  Duration reconnectWait = const Duration(seconds: 1),
}) async {
  tester.view.physicalSize = const Size(411, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpKoban(
    tester,
    s,
    home: NotificationLogScreen(reconnectWait: reconnectWait),
    textScale: textScale,
  );
  await tester.pumpAndSettle();
}

/// Waits (in real time) until a card write and its log update are done, then reads the cards.
Future<List<PendingPayment>> settleMark(
  WidgetTester tester,
  AppServices s,
) async {
  final host = s.captureHost as FakeCaptureHost;
  final waiting = await tester.runAsync(() async {
    while (host.logUpdates.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // A wrong second write would land after the first one.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return s.pending.watchWaiting().first;
  });
  await tester.pump();
  return waiting!;
}

Finder card(String id) => find.byKey(ValueKey('log-$id'));

Finder inCard(String id, Finder f) =>
    find.descendant(of: card(id), matching: f);

void main() {
  test('the filters follow the 0.1.1 rules', () {
    final rows = [
      logged('WAITING'),
      logged('PENDING'),
      logged('INFO_ONLY', event: 'REMOVED'),
      logged('SKIPPED_NO_RULE'),
      logged('SKIPPED_ERROR', event: 'ACTIVE_SNAPSHOT'),
      logged('SKIPPED_EMPTY'),
    ];
    expect(filterLog(rows, LogFilter.all), rows);
    expect(filterLog(rows, LogFilter.saved), [rows[0]]);
    expect(filterLog(rows, LogFilter.notPayment), [rows[3], rows[4]]);
    expect(filterLog(rows, LogFilter.noText), [rows[5]]);
  });

  testWidgets('the log shows the status and the rows', (tester) async {
    final s = await testServices(
      listener: logChannel(),
      device: FakeChannel(deviceChannelName, {
        'appLabels': {maybank: 'Maybank'},
      }),
    );
    await pumpLog(tester, s);
    expect(find.text('Notification log'), findsOneWidget);
    expect(find.text('Koban can read notifications'), findsOneWidget);
    // The rows are from 2025, so nothing counts for today.
    expect(find.text('0 seen today · 0 saved · 0 skipped'), findsOneWidget);
    expect(card('a'), findsOneWidget);
    expect(card('b'), findsOneWidget);
    expect(card('c'), findsOneWidget);
    expect(inCard('a', find.text('Waiting in Check payments')), findsOneWidget);
    expect(
      inCard('b', find.text('Skipped: this message has no amount.')),
      findsOneWidget,
    );
    expect(
      inCard('c', find.text('Seen only. Koban did not save it.')),
      findsOneWidget,
    );
    // The app name replaces the package name.
    expect(
      inCard('a', find.text('Maybank · ${stamp(postTime)}')),
      findsOneWidget,
    );
    expect(find.textContaining(maybank), findsNothing);
    expect(inCard('a', find.text(sample)), findsOneWidget);
    // Waiting shows no button; the other two do.
    expect(inCard('a', find.text('Save payment')), findsNothing);
    expect(inCard('b', find.text('Save payment')), findsOneWidget);
    expect(inCard('c', find.text('Save payment')), findsOneWidget);
    expect(find.text('Add as payment'), findsNothing);
    expect(find.text('Snapshot'), findsNothing);
    for (final label in ['All', 'Saved', 'Not a payment', 'No text']) {
      expect(find.widgetWithText(FilterChip, label), findsOneWidget);
    }
    expect(find.widgetWithText(FilterChip, 'Posted'), findsNothing);
    // No filled (gold) button on the screen.
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('today rows say Today and count as seen, saved or skipped', (
    tester,
  ) async {
    final nine = DateTime(2026, 11, 13, 9, 5).millisecondsSinceEpoch;
    Map<String, Object?> today(String id, String disposition) => {
      ...row(id, disposition: disposition),
      'postTime': nine,
      'capturedAt': nine,
    };
    final listener = logChannel(
      rows: [
        today('a', 'WAITING'),
        today('b', 'SKIPPED_NO_RULE'),
        today('c', 'SKIPPED_EMPTY'),
        row('d'),
      ],
    );
    await pumpLog(
      tester,
      await testServices(
        listener: listener,
        device: FakeChannel(deviceChannelName, {
          'appLabels': {maybank: 'Maybank'},
        }),
      ),
    );
    expect(find.text('3 seen today · 1 saved · 2 skipped'), findsOneWidget);
    expect(inCard('a', find.text('Maybank · Today, 09:05')), findsOneWidget);
    expect(
      inCard('c', find.text('Skipped: this message has no text.')),
      findsOneWidget,
    );
    expect(
      inCard('d', find.text('Maybank · ${stamp(postTime)}')),
      findsOneWidget,
    );
  });

  testWidgets('the log shows a card number with its last 2 digits only', (
    tester,
  ) async {
    const text = 'RM 9.00 on your Visa ending 1234 at SHOP CONTOH.';
    await pumpLog(
      tester,
      await testServices(
        listener: logChannel(rows: [row('a', body: text)]),
      ),
    );
    expect(
      inCard(
        'a',
        find.text('RM 9.00 on your Visa ending ••34 at SHOP CONTOH.'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('1234'), findsNothing);
  });

  testWidgets('the status line follows access and connection', (tester) async {
    final listener = logChannel(connected: false);
    listener.answers['isAccessGranted'] = false;
    await pumpLog(tester, await testServices(listener: listener));
    expect(find.text('Notification access not granted'), findsOneWidget);
    listener.answers['isAccessGranted'] = true;
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Access granted, listener not connected'), findsOneWidget);
  });

  testWidgets('a filter shows its rows and the empty texts', (tester) async {
    await pumpLog(tester, await testServices(listener: logChannel()));
    await tester.tap(find.widgetWithText(FilterChip, 'Saved'));
    await tester.pump();
    expect(card('a'), findsOneWidget);
    expect(card('b'), findsNothing);
    expect(card('c'), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'Not a payment'));
    await tester.pump();
    expect(card('b'), findsOneWidget);
    expect(card('a'), findsNothing);
    expect(find.text(emptyFilter), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'No text'));
    await tester.pump();
    expect(card('b'), findsNothing);
    expect(find.text(emptyFilter), findsOneWidget);
  });

  testWidgets('an empty log and an empty filter have their own text', (
    tester,
  ) async {
    final listener = logChannel(rows: []);
    await pumpLog(tester, await testServices(listener: listener));
    expect(find.text(emptyAll), findsOneWidget);
    expect(find.text('0 seen today · 0 saved · 0 skipped'), findsOneWidget);
    listener.answers['recentNotifications'] = [row('a')];
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Not a payment'));
    await tester.pump();
    expect(find.text(emptyFilter), findsOneWidget);
    expect(find.text(emptyAll), findsNothing);
  });

  testWidgets('the log shows new rows while it is open', (tester) async {
    final listener = logChannel();
    await pumpLog(tester, await testServices(listener: listener));
    expect(find.textContaining(stamp(postTime)), findsNWidgets(3));
    listener.answers['recentNotifications'] = [
      ...threeRows(),
      row('d', disposition: 'SKIPPED_ERROR'),
    ];
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(card('d'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(card('d'), findsOneWidget);
    expect(find.textContaining(stamp(postTime)), findsNWidgets(4));
  });

  testWidgets('the poll stops when the screen is hidden or closed', (
    tester,
  ) async {
    final listener = logChannel();
    await pumpLog(tester, await testServices(listener: listener));
    final start = calls(listener, 'recentNotifications');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    final polled = calls(listener, 'recentNotifications');
    expect(polled, start + 1);
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 6));
    expect(calls(listener, 'recentNotifications'), polled);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    // The resume reads once at once, then the poll runs again.
    expect(calls(listener, 'recentNotifications'), polled + 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(calls(listener, 'recentNotifications'), polled + 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    expect(calls(listener, 'recentNotifications'), polled + 2);
  });

  testWidgets('Save payment makes a card and marks the row', (tester) async {
    final listener = logChannel(
      rows: [row('b', disposition: 'SKIPPED_NO_RULE', detail: null)],
    );
    final s = await testServices(listener: listener);
    await pumpLog(tester, s);
    await tester.tap(inCard('b', find.text('Save payment')));
    await tester.pump();
    final waiting = await settleMark(tester, s);
    expect(waiting, hasLength(1));
    expect(waiting.single.rawNotificationText, sample);
    expect((s.captureHost as FakeCaptureHost).logUpdates, [
      ('b', 'WAITING', 'Added as a card. Check it on the Home screen.'),
    ]);
    expect(inCard('b', find.text('Saved as a payment')), findsOneWidget);
    expect(inCard('b', find.text('Save payment')), findsNothing);
  });

  testWidgets('two taps on Save payment in one frame make one card', (
    tester,
  ) async {
    final listener = logChannel(
      rows: [row('b', disposition: 'SKIPPED_NO_RULE', detail: null)],
    );
    final s = await testServices(listener: listener);
    await pumpLog(tester, s);
    final button = inCard('b', find.text('Save payment'));
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    final waiting = await settleMark(tester, s);
    expect(waiting, hasLength(1));
    expect((s.captureHost as FakeCaptureHost).logUpdates, hasLength(1));
  });

  testWidgets(
    'Save payment while a poll read waits makes one card for two taps',
    (tester) async {
      final skipped = [row('b', disposition: 'SKIPPED_NO_RULE', detail: null)];
      var reads = 0;
      final gate = Completer<List<Map<String, Object?>>>();
      final channel = MethodChannel(ListenerControl.channelName);
      final messenger = tester.binding.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final s = await testServices(listener: logChannel(rows: skipped));
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'recentNotifications':
            reads++;
            // The first poll waits at the gate. The fake log keeps the row skipped.
            return reads == 1 ? gate.future : skipped;
          case 'listenerState':
            return {
              'isConnected': true,
              'lastConnectedAt': postTime,
              'lastDisconnectedAt': null,
              'totalCaptured': 1,
            };
          case 'isConnected':
            return true;
        }
        return null;
      });
      final vm = NotificationLogViewModel(s, poll: const Duration(seconds: 1));
      addTearDown(vm.dispose);
      await tester.pump(const Duration(seconds: 1));
      expect(reads, 1);
      final n = LoggedNotification.fromMap(skipped.single);
      await vm.markAsPayment(n);
      gate.complete(skipped);
      await tester.pump();
      await tester.pump();
      await vm.markAsPayment(n);
      expect(
        await tester.runAsync(() => s.pending.watchWaiting().first),
        hasLength(1),
      );
      expect((s.captureHost as FakeCaptureHost).logUpdates, hasLength(1));
    },
  );

  testWidgets(
    'a failed log update keeps one card and hides Save payment on the row',
    (tester) async {
      final listener = logChannel(
        rows: [row('b', disposition: 'SKIPPED_NO_RULE', detail: null)],
      );
      final s = await testServices(listener: listener);
      final host = s.captureHost as FakeCaptureHost;
      host.updateLogError = PlatformException(code: 'NATIVE_ERROR');
      await pumpLog(tester, s);
      await tester.tap(inCard('b', find.text('Save payment')));
      await tester.pump();
      final waiting = await settleMark(tester, s);
      expect(waiting, hasLength(1));
      expect(tester.takeException(), isNull);
      // The log row is still skipped, but the card exists: the row says so and a second tap is not possible.
      expect(inCard('b', find.text('Saved as a payment')), findsOneWidget);
      expect(inCard('b', find.text('Save payment')), findsNothing);
      expect(host.logUpdates, hasLength(1));
    },
  );

  testWidgets(
    'a poll that began before Clear log cannot bring the old rows back',
    (tester) async {
      final rows = threeRows();
      var reads = 0;
      final gate = Completer<List<Map<String, Object?>>>();
      final channel = MethodChannel(ListenerControl.channelName);
      final messenger = tester.binding.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final s = await testServices(listener: logChannel(rows: rows));
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'recentNotifications':
            reads++;
            // The first poll waits at the gate with the old rows.
            return reads == 1 ? gate.future : <Map<String, Object?>>[];
          case 'listenerState':
            return {
              'isConnected': true,
              'lastConnectedAt': postTime,
              'lastDisconnectedAt': null,
              'totalCaptured': 0,
            };
          case 'isConnected':
            return true;
        }
        return null;
      });
      final vm = NotificationLogViewModel(s, poll: const Duration(seconds: 1));
      addTearDown(vm.dispose);
      await tester.pump(const Duration(seconds: 1));
      expect(reads, 1);
      await vm.clearLog();
      gate.complete(rows);
      await tester.pump();
      await tester.pump();
      expect(vm.rows, isEmpty);
      expect(reads, 2);
    },
  );

  testWidgets(
    'a reconnect that throws shows the failed text and can run again',
    (tester) async {
      final listener = logChannel();
      await pumpLog(tester, await testServices(listener: listener));
      listener.answers['reconnect'] = null;
      await tester.tap(find.text('Restart payment tracking'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Reconnect failed — open notification access settings.'),
        findsOneWidget,
      );
      expect(find.text('Reconnecting…'), findsNothing);
      listener.answers['reconnect'] = 'THROTTLED';
      await tester.tap(find.text('Restart payment tracking'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Reconnect already attempted recently.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Save payment for a text with no amount says so', (tester) async {
    final listener = logChannel(
      rows: [row('b', disposition: 'SKIPPED_NO_RULE', body: statement)],
    );
    final s = await testServices(listener: listener);
    await pumpLog(tester, s);
    await tester.tap(inCard('b', find.text('Save payment')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text('No RM amount in this text. Add the payment by hand.'),
      findsOneWidget,
    );
    expect(
      await tester.runAsync(() => s.pending.watchWaiting().first),
      isEmpty,
    );
    expect((s.captureHost as FakeCaptureHost).logUpdates, isEmpty);
  });

  testWidgets('Clear log and Snapshot show their result', (tester) async {
    final listener = logChannel();
    await pumpLog(tester, await testServices(listener: listener));
    await tester.tap(find.text('Scan now'));
    await tester.pump();
    await tester.pump();
    expect(calls(listener, 'snapshotActive'), 1);
    expect(
      find.text('Snapshotted active status-bar notifications'),
      findsOneWidget,
    );
    listener.answers['snapshotActive'] = false;
    await tester.tap(find.text('Scan now'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text(
        'Listener not connected — toggle notification access off/on, then try again',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Clear log'));
    await tester.pump();
    await tester.pump();
    // The rows hide at once. The native log clears when the Undo time ends.
    expect(find.text('Log cleared'), findsOneWidget);
    expect(find.text(emptyAll), findsOneWidget);
    expect(calls(listener, 'clearLog'), 0);
    // The 6 seconds start when the snackbar is in.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(calls(listener, 'clearLog'), 1);
  });

  testWidgets(
    'Reconnect shows Reconnecting and then the result after the wait',
    (tester) async {
      final listener = logChannel();
      await pumpLog(tester, await testServices(listener: listener));
      await tester.tap(find.text('Restart payment tracking'));
      await tester.pump();
      expect(find.text('Reconnecting…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Reconnecting…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text('Listener connected.'), findsOneWidget);
      expect(calls(listener, 'reconnect'), 1);
    },
  );

  testWidgets('a reconnect for a listener that stays down says so', (
    tester,
  ) async {
    await pumpLog(
      tester,
      await testServices(listener: logChannel(connected: false)),
    );
    await tester.tap(find.text('Restart payment tracking'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(
      find.text(
        'Still disconnected — use the alert notification or open notification access settings.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a second Reconnect tap while one waits starts no second timer', (
    tester,
  ) async {
    final listener = logChannel();
    await pumpLog(tester, await testServices(listener: listener));
    await tester.tap(find.text('Restart payment tracking'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Restart payment tracking'));
    await tester.pump();
    expect(calls(listener, 'reconnect'), 1);
    // The result shows 1 s after the first tap, not after the second.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Listener connected.'), findsOneWidget);
    // The next tap works again.
    await tester.tap(find.text('Restart payment tracking'));
    await tester.pump();
    expect(find.text('Reconnecting…'), findsOneWidget);
    expect(calls(listener, 'reconnect'), 2);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  });

  testWidgets('the other reconnect results show their text', (tester) async {
    final listener = logChannel(reconnect: 'THROTTLED');
    await pumpLog(tester, await testServices(listener: listener));
    Future<void> tap() async {
      await tester.tap(find.text('Restart payment tracking'));
      await tester.pump();
      await tester.pump();
    }

    await tap();
    expect(find.text('Reconnect already attempted recently.'), findsOneWidget);
    listener.answers['reconnect'] = 'FAILED';
    await tap();
    expect(
      find.text('Reconnect failed — open notification access settings.'),
      findsOneWidget,
    );
    listener.answers['reconnect'] = 'ACCESS_NOT_GRANTED';
    await tap();
    expect(
      find.text(
        'Notification access was removed — re-enable in system settings.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Settings opens the log', (tester) async {
    tester.view.physicalSize = const Size(411, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final listener = logChannel();
    listener.answers['isBatteryOptimizationIgnored'] = true;
    listener.answers['isXiaomiFamily'] = false;
    final s = await testServices(
      listener: listener,
      device: FakeChannel(deviceChannelName, {'versionName': '0.1.1'}),
    );
    await pumpKoban(tester, s);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Troubleshooting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notification log'));
    await tester.pumpAndSettle();
    expect(find.text('Koban can read notifications'), findsOneWidget);
    expect(card('a'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Koban can read notifications'), findsNothing);
  });

  testWidgets(
    'the log meets the tap target guidelines and works at text scale 1.3',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLog(
        tester,
        await testServices(listener: logChannel()),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );
}
