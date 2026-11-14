/// The build-time online settings. Android gives them from `BuildConfig` over the device channel.
/// The key is the publishable Supabase key. Never log it.
class OnlineConfig {
  const OnlineConfig({
    required this.supabaseUrl,
    required this.supabaseKey,
    required this.googleWebClientId,
  });

  final String supabaseUrl;
  final String supabaseKey;
  final String googleWebClientId;

  /// The address of the Supabase edge function [name].
  Uri function(String name) => Uri.parse('$supabaseUrl/functions/v1/$name');

  /// Synthetic values for tests.
  static const test = OnlineConfig(
    supabaseUrl: 'https://test.supabase.co',
    supabaseKey: 'test-key',
    googleWebClientId: 'test-client',
  );
}
