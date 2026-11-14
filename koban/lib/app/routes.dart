import 'package:material_ui/material_ui.dart';

import '../screens/check/check_payments_screen.dart';
import '../screens/notification_log/notification_log_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/payment/payment_screen.dart';
import '../screens/payment/payment_view_model.dart';
import '../screens/payment_apps/payment_apps_screen.dart';
import '../screens/person/person_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/split/split_editor_screen.dart';

// Screen motion of 0.1.1 (`ExpenseTrackerNavHost.kt`): an opened page slides in
// across the full width while the page below moves 30% left and darkens. Back
// reverses it. The payment page rises like a sheet and the page below stays.
// With animations off in the phone settings, every page shows at once.
const _pushDuration = Duration(milliseconds: 400);
const _sheetOpenDuration = Duration(milliseconds: 450);
const _sheetCloseDuration = Duration(milliseconds: 300);

/// How far the page below moves, as a part of the width, and its opacity over night.
const _parallax = Offset(-0.3, 0);
const _underOpacity = 0.6;

/// Material 3 emphasized decelerate and accelerate curves.
const _emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);
const _emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);

/// Compose runs the easing forward in time on the way out too. A reversed Flutter
/// animation runs the curve backward, so the way out uses the flipped curve.
CurvedAnimation _eased(
  Animation<double> parent,
  Curve inCurve,
  Curve outCurve,
) => CurvedAnimation(
  parent: parent,
  curve: inCurve,
  reverseCurve: outCurve.flipped,
);

/// A full page. It slides in from the right edge. While a [KobanPageRoute]
/// covers it, it moves 30% left and darkens.
class KobanPageRoute<T> extends PageRoute<T> {
  KobanPageRoute({required this.builder, this.animate = true, super.settings});

  final WidgetBuilder builder;

  /// False shows the page and the page below at once.
  final bool animate;

  CurvedAnimation? _push;
  CurvedAnimation? _under;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => animate ? _pushDuration : Duration.zero;

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  /// Only another page moves this page. A sheet leaves it still.
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is KobanPageRoute;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final push = _push ??= _eased(
      animation,
      Curves.fastOutSlowIn,
      Curves.fastOutSlowIn,
    );
    final under = _under ??= _eased(
      secondaryAnimation,
      Curves.fastOutSlowIn,
      Curves.fastOutSlowIn,
    );
    return SlideTransition(
      position: push.drive(Tween(begin: const Offset(1, 0), end: Offset.zero)),
      child: SlideTransition(
        position: under.drive(Tween(begin: Offset.zero, end: _parallax)),
        child: FadeTransition(
          opacity: under.drive(Tween(begin: 1.0, end: _underOpacity)),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _push?.dispose();
    _under?.dispose();
    super.dispose();
  }
}

/// The payment page. It rises from the bottom edge like a sheet.
class KobanSheetRoute<T> extends PageRoute<T> {
  KobanSheetRoute({required this.builder, this.animate = true, super.settings});

  final WidgetBuilder builder;

  /// False shows the sheet at once.
  final bool animate;

  CurvedAnimation? _rise;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration =>
      animate ? _sheetOpenDuration : Duration.zero;

  @override
  Duration get reverseTransitionDuration =>
      animate ? _sheetCloseDuration : Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final rise = _rise ??= _eased(
      animation,
      _emphasizedDecelerate,
      _emphasizedAccelerate,
    );
    return SlideTransition(
      position: rise.drive(Tween(begin: const Offset(0, 1), end: Offset.zero)),
      child: child,
    );
  }

  @override
  void dispose() {
    _rise?.dispose();
    super.dispose();
  }
}

/// Opens [page] as a full page.
Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push(
      KobanPageRoute<T>(
        builder: (_) => page,
        animate: !MediaQuery.disableAnimationsOf(context),
      ),
    );

/// Opens [page] as a sheet.
Future<T?> pushSheet<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push(
      KobanSheetRoute<T>(
        builder: (_) => page,
        animate: !MediaQuery.disableAnimationsOf(context),
      ),
    );

/// Opens Check payments.
Future<void> openCheckPayments(BuildContext context) =>
    pushPage<void>(context, const CheckPaymentsScreen());

/// Opens the payment apps picker.
Future<void> openPaymentApps(BuildContext context) =>
    pushPage<void>(context, const PaymentAppsScreen());

/// Opens onboarding. It closes itself and shows the first page when it ends.
Future<void> openOnboarding(BuildContext context) =>
    pushPage<void>(context, const OnboardingScreen());

/// Opens the notification log.
Future<void> openNotificationLog(BuildContext context) =>
    pushPage<void>(context, const NotificationLogScreen());

/// Opens Settings.
Future<void> openSettings(BuildContext context) =>
    pushPage<void>(context, const SettingsScreen());

/// Opens the sheet that adds a payment.
Future<PaymentResult?> openPaymentNew(BuildContext context) =>
    pushSheet<PaymentResult>(context, const PaymentScreen());

/// Opens the sheet that edits the payment [expenseId].
/// "Split this bill" closes the sheet, then the split editor opens for the payment.
Future<PaymentResult?> openPaymentEdit(
  BuildContext context,
  String expenseId,
) async {
  final result = await pushSheet<PaymentResult>(
    context,
    PaymentScreen(expenseId: expenseId),
  );
  if (result is PaymentOpenSplit && context.mounted) {
    await openSplitNew(context, expenseId: result.expenseId);
  }
  return result;
}

/// Opens the split editor for a new split. With [expenseId], the split links that payment,
/// or the editor shows the split that already has it.
Future<void> openSplitNew(BuildContext context, {String? expenseId}) =>
    pushPage<void>(context, SplitEditorScreen(expenseId: expenseId));

/// Opens the saved split [billId] on its summary.
Future<void> openSplitEdit(BuildContext context, String billId) =>
    pushPage<void>(context, SplitEditorScreen(billId: billId));

/// Opens the page of the person [personId].
Future<void> openPerson(BuildContext context, String personId) =>
    pushPage<void>(context, PersonScreen(personId));
