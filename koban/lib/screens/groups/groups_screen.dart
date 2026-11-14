import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../app/routes.dart';
import '../../online/group_repository.dart';
import '../../theme/koban_theme.dart';
import '../../theme/mon.dart';
import '../../ui/kit.dart';
import 'group_dialogs.dart';
import 'groups_view_model.dart';

const _tall = Size(0, 48);

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

  Future<void> _openGroup(String id) async {
    if (!_current) return;
    _groupOpen = true;
    try {
      await openGroup(context, id);
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
    );
  }

  Future<void> _make() => _askAndRun(
    title: 'Make a group',
    label: 'Group name',
    start: '',
    confirm: 'Make group',
    max: 40,
    action: (r, name) => r.makeGroup(name),
  );

  Future<void> _join() => _askAndRun(
    title: 'Join a group',
    label: 'Group code, for example GRP-7KQ2',
    start: '',
    confirm: 'Ask to join',
    max: 8,
    action: (r, code) => r.askToJoin(code),
    onOk: () =>
        _snack('Request sent. You join when the group owner approves it.'),
  );

  Future<void> _alias() => _askAndRun(
    title: 'Your name in groups',
    label: 'Name',
    start: _vm!.state.alias,
    confirm: 'Save',
    max: 30,
    action: (r, name) => r.setAlias(name),
  );

  Future<void> _signOut() => _vm!.run((r) async {
    await r.signOut();
    return null;
  });

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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LargeTopBar(
              title: 'Groups',
              actions: [
                if (signedIn)
                  PopupMenuButton<VoidCallback>(
                    tooltip: 'Account',
                    icon: const Icon(Icons.more_vert),
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
                  ),
              ],
            ),
            Expanded(
              child: !state.online
                  ? _OnlineOff(onTurnOn: () => vm.setOnline(true))
                  : state.userId == null
                  ? _SignedOut(
                      busy: vm.busy,
                      onSignIn: () => vm.run((r) => r.signIn()),
                    )
                  : _groups(context, vm, state),
            ),
          ],
        );
      },
    );
  }

  Widget _groups(BuildContext context, GroupsViewModel vm, GroupsState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final items = <Widget>[
      for (final (id, name) in state.removedFrom)
        Material(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
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
                    '${g.ownerId == state.userId ? ' · you are the owner' : ''}',
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
                            '${g.requests} ${g.requests == 1 ? 'request' : 'requests'}',
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
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: vm.busy ? null : _make,
                    style: FilledButton.styleFrom(minimumSize: _tall),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Make a group'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: vm.busy ? null : _join,
                    style: OutlinedButton.styleFrom(minimumSize: _tall),
                    child: const Text('Join a group'),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You can be in up to 5 groups. Each group has up to 10 members.',
                style: theme.textTheme.bodySmall!.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ),
    ];
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _pull,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => items[i],
          ),
        ),
        // As the 0.1.1 pull-to-refresh box: the indicator shows while a load runs.
        if (state.loading && !_pulling)
          const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 16),
              child: RefreshProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

class _OnlineOff extends StatelessWidget {
  const _OnlineOff({required this.onTurnOn});

  final VoidCallback onTurnOn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          const Center(child: Mon(MonFace.idle, size: 120)),
          Text(
            'Online features are off',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          Text(
            'Groups need online features. While they are off, Koban makes no network calls.',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          FilledButton(
            onPressed: onTurnOn,
            style: FilledButton.styleFrom(minimumSize: _tall),
            child: const Text('Turn on online features'),
          ),
        ],
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.busy, required this.onSignIn});

  final bool busy;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
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
                    'Never shared: single payments, shops, times, notes, money in',
                  ),
                ],
              ),
            ),
          ),
          FilledButton(
            onPressed: busy ? null : onSignIn,
            style: FilledButton.styleFrom(minimumSize: _tall),
            child: Text(busy ? 'Signing in…' : 'Sign in with Google'),
          ),
          Text(
            'Groups use the invite code you entered in Settings.',
            style: theme.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
