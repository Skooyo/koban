import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/update/release_parser.dart';
import 'package:koban/update/update_dialog.dart';
import 'package:koban/update/update_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';

AvailableUpdate update(int size) => AvailableUpdate(
  versionCode: 7,
  versionName: '0.7.0',
  apkUrl: 'https://example.test/koban-7.apk',
  apkSize: size,
  notes: 'Fixes',
);

String release() => jsonEncode({
  'tag_name': 'v0.7.0',
  'body': 'Fixes',
  'assets': [
    {
      'name': 'koban-7.apk',
      'browser_download_url': 'https://example.test/koban-7.apk',
      'size': 5,
    },
  ],
});

/// GitHub gives the release. The APK download gives 3 of 5 bytes, then an error.
http.Client releaseClient() => MockClient.streaming((request, _) async {
  if (request.url.host == 'api.github.com') {
    return http.StreamedResponse(Stream.value(utf8.encode(release())), 200);
  }
  return http.StreamedResponse(Stream.value([1, 2, 3]), 200, contentLength: 5);
});

/// GitHub answers when [githubHold] completes (at once when null).
/// The APK download answers when [downloadHold] completes.
http.Client heldClient({
  Completer<void>? githubHold,
  required Completer<http.StreamedResponse> downloadHold,
}) => MockClient.streaming((request, _) async {
  if (request.url.host == 'api.github.com') {
    await githubHold?.future;
    return http.StreamedResponse(Stream.value(utf8.encode(release())), 200);
  }
  return downloadHold.future;
});

http.StreamedResponse shortApk() =>
    http.StreamedResponse(Stream.value([1, 2, 3]), 200, contentLength: 5);

/// Gives the file and stream work of the download real time to end.
Future<void> untilNotDownloading(WidgetTester tester, AppServices s) async {
  for (var i = 0; i < 100 && s.updates.state.value is UpdateDownloading; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
}

Future<void> pumpContent(
  WidgetTester tester,
  UpdateState state, {
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: UpdateDialogContent(
        state: state,
        onUpdate: () {},
        onDismiss: () {},
      ),
    ),
  ),
);

void main() {
  testWidgets('Update available shows the version, the size and the notes', (
    tester,
  ) async {
    await pumpContent(tester, UpdateAvailable(update(65000000)));
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Koban 0.7.0 is ready (65 MB).'), findsOneWidget);
    expect(find.text('Fixes'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    await pumpContent(tester, UpdateAvailable(update(400000)));
    expect(find.text('Koban 0.7.0 is ready (1 MB).'), findsOneWidget);
  });

  testWidgets('the dialog buttons stay in the screen at text scale 1.3', (
    tester,
  ) async {
    await pumpContent(
      tester,
      UpdateAvailable(update(65000000)),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    for (final label in ['Update', 'Later']) {
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.text(label),
                matching: find.bySubtype<ButtonStyleButton>(),
              ),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
    }
  });

  testWidgets(
    'the start check opens the dialog over any page and Later closes it',
    (tester) async {
      final s = await testServices(
        http: releaseClient(),
        prefs: {'last_update_check': 0},
      );
      await pumpKoban(tester, s);
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
      expect(s.updates.state.value, const UpdateIdle());
    },
  );

  testWidgets('the dialog opens over a page that is open', (tester) async {
    final github = Completer<void>();
    final s = await testServices(
      http: heldClient(
        githubHold: github,
        downloadHold: Completer<http.StreamedResponse>(),
      ),
      prefs: {'last_update_check': 0},
    );
    tester.view.physicalSize = const Size(411, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpKoban(tester, s);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);
    github.complete();
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
  });

  testWidgets('the dialog follows the state to Downloading and to Failed', (
    tester,
  ) async {
    final download = Completer<http.StreamedResponse>();
    final s = await testServices(
      http: heldClient(downloadHold: download),
      prefs: {'last_update_check': 0},
    );
    await pumpKoban(tester, s);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    // The progress bar never settles: pump a set time.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Downloading the update…'), findsOneWidget);
    // The download gives fewer bytes than Content-Length: it ends in a failure.
    download.complete(shortApk());
    await untilNotDownloading(tester, s);
    await tester.pumpAndSettle();
    expect(find.text('Update failed. Try again later.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('Back on Downloading does not close the dialog', (tester) async {
    final download = Completer<http.StreamedResponse>();
    final s = await testServices(
      http: heldClient(downloadHold: download),
      prefs: {'last_update_check': 0},
    );
    await pumpKoban(tester, s);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Downloading the update…'), findsOneWidget);
    expect(s.updates.state.value, const UpdateDownloading());
    // Free the held download so the tear-down ends.
    download.complete(shortApk());
    await untilNotDownloading(tester, s);
    await tester.pumpAndSettle();
  });

  testWidgets('Back on Update available closes the dialog', (tester) async {
    final s = await testServices(
      http: releaseClient(),
      prefs: {'last_update_check': 0},
    );
    await pumpKoban(tester, s);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);
    expect(s.updates.state.value, const UpdateIdle());
  });
}
