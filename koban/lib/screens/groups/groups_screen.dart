import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../app/routes.dart';
import '../../online/group_repository.dart';
import '../../online/receipt_cloud_client.dart';
import '../../theme/koban_theme.dart';
import '../../theme/mon.dart';
import '../../theme/tokens.dart';
import '../../ui/kit.dart';
import '../../ui/scene_band.dart';
import 'group_dialogs.dart';
import 'groups_view_model.dart';

const _tall = Size(0, 48);

({MonFace face, String line, String? detail}) _monSay(
  GroupsState state, {
  required bool signedIn,
}) {
  if (!state.online) {
    return (
      face: MonFace.worry,
      line: 'Online features are off',
      detail: 'Groups need online features. While they are off, Koban makes no network calls.',
    );
  }
  if (!signedIn) {
    return (
      face: MonFace.worry,
      line: 'Sign in to see your groups.',
      detail: null,
    );
  }
  return (
    face: MonFace.idle,
    line: 'Nobody sees your shops.',
    detail: 'Only category totals are shared.',
  );
}

/// The Groups tab: Online features off, the sign-in page or the groups list,
/// and the Account menu. A port of the 0.1.1 `GroupsScreen.kt` `GroupsScreen`.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  GroupsViewModel? _vm;

  /// True while a pull-down refresh runs. The pull shows its own indicator.
  var _pulling = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm ??= GroupsViewModel(AppScope.of(context));
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Shows the message of the view model one time.
  void _showMessage() {
    final m = _vm!.message;
    if (m == null) return;
    _vm!.messageShown();
    _snack(m);
  }

  /// True while a group page is open over the tab. The page shows the messages
  /// itself: the tab drops them, so one message does not show two times.
  var _groupOpen = false;

  /// True while the first-sign-in name step shows.
  var _askingName = false;

  Future<void> _openGroup(String id, {String? madeName}) async {
    if (!_current) return;
    _groupOpen = true;
    try {
      await openGroup(context, id, madeName: madeName);
    } finally {
      _groupOpen = false;
    }
  }

  /// True when no dialog or page is over the tab. A second fast tap opens no second dialog.
  bool get _current => ModalRoute.of(context)?.isCurrent ?? true;

  Future<void> _askAndRun({
    required String title,
    required String label,
    required String start,
    required String confirm,
    required int max,
    required Future<String?> Function(GroupRepository r, String text) action,
    VoidCallback? onOk,
    String? helper,
    String Function(String)? transform,
  }) async {
    if (!_current) return;
    await askNameAndRun(
      context,
      _vm!,
      title: title,
      label: label,
      start: start,
      confirm: confirm,
      max: max,
      action: action,
      onOk: onOk,
      helper: helper,
      transform: transform,
    );
  }

  /// Makes the group, then opens its page with the group code on top.
  Future<void> _make() {
    String? id;
    String? name;
    return _askAndRun(
      title: 'Make a group',
      label: 'Group name',
      start: '',
      confirm: 'Make group',
      max: 40,
      action: (r, typed) {
        name = typed;
        return r.makeGroup(typed, onMade: (made) => id = made);
      },
      onOk: () {
        final made = id;
        if (made != null && mounted) _openGroup(made, madeName: name);
      },
    );
  }

  Future<void> _join() => _askAndRun(
    title: 'Join a group',
    label: 'Group code',
    helper: 'Like GRP-7KQ2',
    // Capitals as you type. A pasted share message gives the code in it.
    transform: (v) {
      final up = v.toUpperCase();
      return RegExp(r'GRP-[A-Z0-9]{4}').firstMatch(up)?.group(0) ?? up;
    },
    start: '',
    confirm: 'Ask to join',
    max: 8,
    action: (r, code) => r.askToJoin(code),
    onOk: () =>
        _snack('Request sent. You join when the group owner approves it.'),
  );

  /// The invite check before the Google sign-in: trades the code for a device token.
  Future<void> _inviteCode() async {
    if (!_current) return;
    final s = AppScope.of(context);
    await showTextDialog(
      context,
      title: 'Enter invite code',
      label: 'Invite code',
      helper: 'Like ABCD-2345',
      transform: (v) => v.toUpperCase(),
      start: '',
      confirm: 'Use code',
      max: 9,
      submit: (code) async {
        try {
          return switch (await s.online.receiptCloud.register(code)) {
            RegistrationOk(:final deviceToken) =>
              await s.online.secrets
                  .setDeviceToken(deviceToken)
                  .then((_) => (worked: true, error: null)),
            RegistrationFailed(:final message) => (
              worked: false,
              error: message,
            ),
          };
        } catch (e) {
          // ONLINE LOGS rule R1: the type only.
          debugPrint('Koban: invite code check failed (${e.runtimeType})');
          return (
            worked: false,
            error: "Koban's server had a problem. Try again later.",
          );
        }
      },
    );
  }

  Future<void> _alias() => _askAndRun(
    title: 'Your name in groups',
    label: 'Name',
    helper: 'Members see this name.',
    start: _vm!.state.alias,
    confirm: 'Save',
    max: 30,
    action: (r, name) => r.setAlias(name),
  );

  Future<void> _signOut() async {
    if (!_current) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Sign out?',
      body: 'Your groups come back when you sign in again.',
      confirm: 'Sign out',
    );
    if (!ok) return;
    await _vm!.run((r) async {
      await r.signOut();
      return null;
    });
  }

  /// After the first sign-in: asks which name the groups see, filled with the Google name.
  Future<void> _askFirstName() async {
    await _alias();
    if (mounted) AppScope.of(context).online.groups.nameDone();
  }

  Future<void> _delete() async {
    if (!_current) return;
    await askConfirmAndRun(
      context,
      _vm!,
      title: 'Delete your account?',
      body: "This removes you from all your groups and deletes your shared totals from Koban's server. The payments on this phone stay.",
      confirm: 'Delete account',
      action: (r) => r.deleteAccount(),
    );
  }

  Future<void> _pull() async {
    setState(() => _pulling = true);
    try {
      await _vm!.refresh();
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    // A hidden tab keeps its message until it shows, as the 0.1.1 tab did.
    final visible = Visibility.of(context);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (visible && vm.message != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _groupOpen ? vm.messageShown() : _showMessage(),
          );
        }
        final state = vm.state;
        final signedIn = state.online && state.userId != null;
        if (signedIn && state.namePending && !_askingName && _current) {
          _askingName = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) await _askFirstName();
            _askingName = false;
          });
        }
        final scheme = Theme.of(context).colorScheme;
        final say = _monSay(state, signedIn: signedIn);
        final band = SceneBand(
          title: 'Groups',
          face: say.face,
          line: say.line,
          detail: say.detail,
          onCoins: signedIn,
          action: signedIn
              ? PopupMenuButton<VoidCallback>(
                  tooltip: 'Account',
                  icon: const Icon(Icons.more_vert),
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surfaceContainer.withValues(
                      alpha: 0.7,
                    ),
                    foregroundColor: scheme.onSurface,
                    minimumSize: const Size(48, 48),
                  ),
                  onSelected: (action) => action(),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _alias,
                      child: const Text('Change your name'),
                    ),
                    PopupMenuItem(
                      value: _signOut,
                      child: const Text('Sign out'),
                    ),
                    PopupMenuItem(
                      value: _delete,
                      child: const Text('Delete account'),
                    ),
                  ],
                )
              : null,
        );
        if (signedIn) return _groups(context, vm, state, band);
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            band,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: !state.online
                  ? _OnlineOff(onTurnOn: () => vm.setOnline(true))
                  : ValueListenableBuilder(
                      valueListenable: AppScope.of(context)
                          .settings
                          .hasDeviceToken,
                      builder: (_, hasInvite, _) => _SignedOut(
                        busy: vm.busy,
                        hasInvite: hasInvite,
                        onInviteCode: _inviteCode,
                        onSignIn: () => vm.run((r) => r.signIn()),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _groups(
    BuildContext context,
    GroupsViewModel vm,
    GroupsState state,
    Widget band,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final items = <Widget>[
      for (final (id, name) in state.removedFrom)
        Material(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(KobanRadius.r24),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'The owner removed you from $name.',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
                TextButton(
                  onPressed: () => vm.run((r) async {
                    await r.dismissRemoved(id);
                    return null;
                  }, silent: true),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        ),
      if (state.groups.isEmpty && !state.loading)
        Text(
          "You are in no groups yet. Make a group and share its code, or join a friend's group with their code.",
          style: theme.textTheme.bodyLarge!.copyWith(color: muted),
        ),
      if (state.groups.isNotEmpty)
        ListGroup(
          children: [
            for (final g in state.groups)
              KobanRow(
                title: g.name,
                subtitle:
                    '${g.members} ${g.members == 1 ? 'member' : 'members'}'
                    '${g.ownerId == state.userId ? ' · you are the group owner' : ''}',
                leading: InitialsAvatar(g.name, tint: scheme.primaryContainer),
                trailing: g.requests > 0
                    ? DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: const StadiumBorder(),
                          color: scheme.primaryContainer,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            '${g.requests} ${g.requests == 1 ? 'join request' : 'join requests'}',
                            style: theme.textTheme.labelMedium!.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      )
                    : null,
                showChevron: true,
                onTapLabel: 'Open group',
                onTap: () => _openGroup(g.id),
              ),
          ],
        ),
      if (state.waiting.isNotEmpty) ...[
        Semantics(
          header: true,
          child: Text(
            'Waiting for the group owner',
            style: theme.textTheme.titleSmall!.copyWith(color: muted),
          ),
        ),
        ListGroup(
          children: [
            for (final r in state.waiting)
              KobanRow(
                title: 'Join request',
                subtitle: _waitingText(r.sentAt, AppScope.of(context).now()),
                leading: Icon(Icons.hourglass_empty, color: muted),
              ),
          ],
        ),
      ],
      FilledButton.icon(
        onPressed: vm.busy ? null : _make,
        style: FilledButton.styleFrom(minimumSize: _tall),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Make a group'),
      ),
      OutlinedButton(
        onPressed: vm.busy ? null : _join,
        style: OutlinedButton.styleFrom(minimumSize: _tall),
        child: const Text('Join with a group code'),
      ),
      Text(
        'Up to 5 groups, 10 members in each.',
        style: theme.textTheme.bodySmall!.copyWith(color: muted),
      ),
    ];
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _pull,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              band,
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: items,
                ),
              ),
            ],
          ),
        ),
        // As the 0.1.1 pull-to-refresh box: the indicator shows while a load runs.
        if (state.loading && !_pulling)
          const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 96),
              child: RefreshProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Sent Tue, 24 Nov. It ends in 5 days." A request ends 7 days after it is sent.
String _waitingText(DateTime? sentAt, DateTime now) {
  if (sentAt == null) return 'Sent. It ends 7 days after you send it.';
  final sent = sentAt.toLocal();
  final left = (7 - now.difference(sentAt).inDays).clamp(1, 7);
  return 'Sent ${_weekdays[sent.weekday - 1]}, ${sent.day} ${_monthNames[sent.month - 1]}. '
      'It ends in $left ${left == 1 ? 'day' : 'days'}.';
}

class _OnlineOff extends StatelessWidget {
  const _OnlineOff({required this.onTurnOn});

  final VoidCallback onTurnOn;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTurnOn,
      style: FilledButton.styleFrom(minimumSize: _tall),
      child: const Text('Turn on online features'),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({
    required this.busy,
    required this.hasInvite,
    required this.onInviteCode,
    required this.onSignIn,
  });

  final bool busy;

  /// False until the phone has an invite code. Groups need one, so the card asks for it first.
  final bool hasInvite;
  final VoidCallback onInviteCode;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyMedium!;
    Widget line(Icon icon, String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        ExcludeSemantics(child: icon),
        Expanded(child: Text(text, style: body)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(KobanRadius.r24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Text(
                  'Compare spending with friends',
                  style: theme.textTheme.headlineSmall,
                ),
                Text(
                  "Members see each other's totals per category, for each week and month.",
                  style: body.copyWith(color: scheme.onSurfaceVariant),
                ),
                line(
                  Icon(Icons.check, color: MoneyColors.of(context).received),
                  'Shared: category totals, week and month',
                ),
                line(
                  Icon(Icons.lock, color: scheme.onSurfaceVariant),
                  'Never shared: single payments, shops, times, notes, Received',
                ),
              ],
            ),
          ),
        ),
        FilledButton(
          onPressed: hasInvite ? (busy ? null : onSignIn) : onInviteCode,
          style: FilledButton.styleFrom(minimumSize: _tall),
          child: Text(
            hasInvite
                ? (busy ? 'Signing in…' : 'Sign in with Google')
                : 'Enter invite code',
          ),
        ),
        Text(
          hasInvite ? 'Groups use the invite code of this phone.' : 'Groups need an invite code from the Koban owner. Enter it first, then sign in.',
          style: theme.textTheme.bodySmall!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
