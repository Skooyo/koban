import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../ui/kit.dart';
import 'payment_apps_view_model.dart';

/// Pick which installed apps Koban listens to. Save with none ticked is allowed.
/// [onSaved] and [onBack] replace the default, which closes the page.
class PaymentAppsScreen extends StatefulWidget {
  const PaymentAppsScreen({super.key, this.onSaved, this.onBack});

  final VoidCallback? onSaved;
  final VoidCallback? onBack;

  @override
  State<PaymentAppsScreen> createState() => _PaymentAppsScreenState();
}

class _PaymentAppsScreenState extends State<PaymentAppsScreen> {
  PaymentAppsViewModel? _vm;
  final _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm ??= PaymentAppsViewModel(AppScope.of(context));
  }

  @override
  void dispose() {
    _search.dispose();
    _vm?.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _vm!.save();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (widget.onSaved != null) {
      widget.onSaved!();
    } else if (ModalRoute.of(context)?.isCurrent == true) {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final apps = vm.apps;
        final shown = vm.shown;
        final n = vm.selected.length;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: widget.onBack ?? _close,
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Semantics(
                            header: true,
                            child: Text('Payment apps', style: text.titleLarge),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Koban reads notifications only from the apps you tick.',
                      style: text.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: _search,
                    onChanged: vm.setQuery,
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Search apps',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: apps == null
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          children: [
                            if (shown.isEmpty)
                              Text(
                                'No apps match.',
                                style: text.bodyMedium!.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ListGroup(
                              children: [
                                for (final a in shown)
                                  MergeSemantics(
                                    key: ValueKey(a.packageName),
                                    child: Semantics(
                                      checked: vm.selected.contains(
                                        a.packageName,
                                      ),
                                      child: KobanRow(
                                        title: a.label,
                                        leading: a.icon == null
                                            ? InitialsAvatar(a.label)
                                            : Image.memory(
                                                a.icon!,
                                                width: 40,
                                                height: 40,
                                                cacheWidth: (40 * dpr).round(),
                                                cacheHeight: (40 * dpr).round(),
                                                gaplessPlayback: true,
                                                excludeFromSemantics: true,
                                                errorBuilder: (_, _, _) =>
                                                    InitialsAvatar(a.label),
                                              ),
                                        // Display only, as in 0.1.1: the row takes the tap.
                                        trailing: ExcludeSemantics(
                                          child: IgnorePointer(
                                            child: Checkbox(
                                              value: vm.selected.contains(
                                                a.packageName,
                                              ),
                                              onChanged: null,
                                            ),
                                          ),
                                        ),
                                        onTap: () => vm.toggle(a.packageName),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: apps == null || _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(switch (n) {
                      0 => 'Save without apps',
                      1 => 'Save 1 app',
                      _ => 'Save $n apps',
                    }, style: text.labelLarge),
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
