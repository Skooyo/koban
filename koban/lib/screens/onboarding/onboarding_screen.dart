import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../theme/koban_theme.dart';
import '../../theme/mon.dart';
import '../../ui/kit.dart';
import '../payment_apps/payment_apps_screen.dart';
import 'onboarding_rules.dart';
import 'onboarding_view_model.dart';

const _stepNames = {
  OnboardingStep.access: 'Notification access',
  OnboardingStep.blocked: 'Notification access',
  OnboardingStep.apps: 'Payment apps',
  OnboardingStep.running: 'Keep it running',
  OnboardingStep.ready: 'Ready',
};

/// First-start flow (`OnboardingScreen.kt` of 0.1.1): welcome, notification access,
/// payment apps, keep-alive settings, ready. Back goes one step back.
/// Back on Welcome and Go to Home store the done flag and show Home.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  OnboardingViewModel? _vm;
  late final AppLifecycleListener _lifecycle;
  var _finishing = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => _vm?.onResume());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm ??= OnboardingViewModel(AppScope.of(context));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _vm?.dispose();
    super.dispose();
  }

  /// Saves the done flag first, then shows the first page. Leaving first could lose the write.
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    try {
      await _vm!.finish();
    } finally {
      _finishing = false;
    }
    if (!mounted || ModalRoute.isCurrentOf(context) != true) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _openAccessSettings() {
    _vm!.openedSettings();
    AppScope.of(context).listener.openAccessSettings();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final step = vm.step;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (vm.step == OnboardingStep.welcome) {
              _finish();
            } else {
              vm.back();
            }
          },
          // The picker keeps its own top bar and Save button.
          child: step == OnboardingStep.apps
              ? PaymentAppsScreen(onSaved: vm.appsSaved, onBack: vm.back)
              : _page(context, vm, step),
        );
      },
    );
  }

  Widget _page(
    BuildContext context,
    OnboardingViewModel vm,
    OnboardingStep step,
  ) {
    final number = OnboardingRules.stepNumber(step);
    final s = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    if (number != null)
                      StepProgress(
                        number: number,
                        total: 4,
                        name: _stepNames[step]!,
                      ),
                    ...switch (step) {
                      OnboardingStep.welcome => _welcome(context),
                      OnboardingStep.access => _access(context),
                      OnboardingStep.blocked => _blocked(context),
                      OnboardingStep.running => _runningStep(context, vm),
                      OnboardingStep.ready => _ready(context),
                      OnboardingStep.apps => const <Widget>[],
                    },
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: switch (step) {
                  OnboardingStep.welcome => [
                    _MainButton('Get started', vm.next),
                  ],
                  OnboardingStep.access => [
                    _MainButton('Open settings', _openAccessSettings),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'In the list, tap Koban, then turn on Allow.',
                        style: _small(context),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  OnboardingStep.blocked => [
                    _MainButton('Open app info', s.device.openAppInfo),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: _openAccessSettings,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Try again'),
                      ),
                    ),
                  ],
                  OnboardingStep.running => [
                    _MainButton('Next', vm.next),
                    Center(
                      child: TextButton(
                        onPressed: vm.next,
                        child: const Text('Skip for now'),
                      ),
                    ),
                  ],
                  OnboardingStep.ready => [_MainButton('Go to Home', _finish)],
                  OnboardingStep.apps => const <Widget>[],
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _small(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  TextStyle _body(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!;

  List<Widget> _welcome(BuildContext context) {
    final theme = Theme.of(context);
    return [
      const Center(child: Mon(MonFace.idle, size: 140)),
      Text(
        'Koban counts your spending for you.',
        style: theme.textTheme.displaySmall,
        textAlign: TextAlign.center,
      ),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 16,
            children: const [
              _InfoRow(
                Icons.notifications_active,
                'Reads payment alerts from the apps you pick.',
              ),
              _InfoRow(
                Icons.touch_app,
                'You check each payment before it counts.',
              ),
              _InfoRow(
                Icons.lock,
                'Nothing leaves the phone. No account needed.',
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _access(BuildContext context) => [
    Text(
      'Let Koban see payment alerts',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    Text(
      'When your bank or e-wallet sends a payment alert, Koban turns it into a payment for you to check.',
      style: _body(context),
    ),
    const _InfoRow(
      Icons.check_circle,
      'Koban reads only the apps you pick next.',
    ),
    const _InfoRow(
      Icons.check_circle,
      'It ignores chats and all other alerts.',
    ),
  ];

  List<Widget> _blocked(BuildContext context) {
    final body = _body(context);
    return [
      const Center(child: Mon(MonFace.worry, size: 64)),
      Text(
        'Android blocked this',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(
        'Koban was installed from a file, so Android wants one more step.',
        style: body,
      ),
      Text('1  Tap Open app info below', style: body),
      Text(
        '2  Tap ⋮ at the top right — Then tap Allow restricted settings',
        style: body,
      ),
      Text('3  Come back and tap Try again', style: body),
      Text(
        'Android shows this item only after it blocks an app once.',
        style: _small(context),
      ),
    ];
  }

  List<Widget> _runningStep(BuildContext context, OnboardingViewModel vm) {
    final rows = vm.running;
    final listener = AppScope.of(context).listener;
    return [
      Text(
        'Keep Koban running',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(
        'Phones stop apps in the background to save battery. These settings keep tracking on.',
        style: _body(context),
      ),
      if (rows != null) ...[
        if (rows.showAlerts)
          _SettingRow(
            title: 'Alerts',
            action: 'Tell me when tracking stops',
            done: rows.alertsAllowed,
            buttonLabel: 'Allow',
            onPressed: vm.allowAlerts,
          ),
        _SettingRow(
          title: 'Battery',
          action: 'No restrictions',
          done: rows.batteryIgnored,
          buttonLabel: 'Open settings',
          onPressed: listener.openBatteryOptimizationSettings,
        ),
        if (rows.xiaomi)
          _SettingRow(
            title: 'Autostart',
            action: 'Start Koban after a restart',
            done: false,
            buttonLabel: 'Open settings',
            onPressed: listener.openBackgroundSettings,
          ),
      ],
      Text(
        'Only the settings your phone needs show here.',
        style: _small(context),
      ),
    ];
  }

  List<Widget> _ready(BuildContext context) => [
    const Center(child: Mon(MonFace.happy, size: 140)),
    Text(
      'Koban is ready',
      style: Theme.of(context).textTheme.headlineMedium,
      textAlign: TextAlign.center,
    ),
    Text(
      'Pay with a card or e-wallet. The payment shows up in Koban within a few seconds.',
      style: _body(context),
      textAlign: TextAlign.center,
    ),
  ];
}

class _MainButton extends StatelessWidget {
  const _MainButton(this.text, this.onPressed);

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    child: Text(text),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      spacing: 16,
      children: [
        Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
      ],
    );
  }
}

/// One row of Keep Koban running: a check icon when done, else a button.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.action,
    required this.done,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String action;
  final bool done;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        spacing: 16,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(
                  action,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (done)
            Icon(
              Icons.check_circle,
              semanticLabel: '$title done',
              color: MoneyColors.of(context).received,
            )
          else
            TonalButton(buttonLabel, onPressed),
        ],
      ),
    );
  }
}
