import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

/// Gives up on a call after [timeout], as the 0.1.1 OkHttp `callTimeout` (20 s for the full call).
/// The limit covers the response headers and the body. Supabase answers are small, so the
/// body is read into memory. At the deadline the call is aborted, as OkHttp cancels it.
class TimeoutClient extends http.BaseClient {
  TimeoutClient(this._inner, {this.timeout = const Duration(seconds: 20)});

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final clock = Stopwatch()..start();
    final abort = Completer<void>();
    final copy =
        http.AbortableStreamedRequest(
            request.method,
            request.url,
            abortTrigger: abort.future,
          )
          ..headers.addAll(request.headers)
          ..contentLength = request.contentLength
          ..followRedirects = request.followRedirects
          ..maxRedirects = request.maxRedirects
          ..persistentConnection = request.persistentConnection;
    // A body error reaches the inner client through the stream of the copy.
    request.finalize().pipe(copy.sink).ignore();
    try {
      final response = await _inner.send(copy).timeout(timeout);
      final body = await response.stream.toBytes().timeout(
        timeout - clock.elapsed,
      );
      return http.StreamedResponse(
        http.ByteStream.fromBytes(body),
        response.statusCode,
        contentLength: body.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } on TimeoutException {
      abort.complete();
      rethrow;
    }
  }

  // No close override: the inner client is the shared client of the app and stays open.
}

/// True when [e] means that the phone did not reach the server.
bool isNoConnection(Object e) =>
    e is SocketException ||
    e is http.ClientException ||
    e is TimeoutException ||
    e is AuthRetryableFetchException;
