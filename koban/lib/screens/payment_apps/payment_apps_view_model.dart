import 'package:flutter/foundation.dart';

import '../../app/app_services.dart';
import '../../device/device_control.dart';
import '../../rules/payment_rules.dart';

/// Installed preselected apps first, then by label.
List<InstalledApp> sortApps(List<InstalledApp> apps, Set<String> preselect) =>
    [...apps]..sort((a, b) {
      final byPreselect = (preselect.contains(a.packageName) ? 0 : 1).compareTo(
        preselect.contains(b.packageName) ? 0 : 1,
      );
      if (byPreselect != 0) return byPreselect;
      final byLabel = a.label.toLowerCase().compareTo(b.label.toLowerCase());
      return byLabel != 0 ? byLabel : a.packageName.compareTo(b.packageName);
    });

/// First open: the installed preselected apps. Later: the stored allowlist.
Set<String> initialSelection({
  required bool chosen,
  required Set<String> allowlist,
  required Set<String> installed,
  required Set<String> preselect,
}) => chosen ? allowlist : preselect.intersection(installed);

/// The state of the payment apps picker: the apps, the ticks and the search text.
class PaymentAppsViewModel extends ChangeNotifier {
  PaymentAppsViewModel(this._s) {
    _load();
  }

  final AppServices _s;
  var _disposed = false;
  List<InstalledApp>? _apps;
  Set<String> _selected = {};
  String _query = '';

  /// Null while the apps load.
  List<InstalledApp>? get apps => _apps;
  Set<String> get selected => _selected;
  String get query => _query;

  /// The apps whose label contains the trimmed search text. Case is ignored.
  List<InstalledApp> get shown {
    final q = _query.trim().toLowerCase();
    return [
      for (final a in _apps ?? const <InstalledApp>[])
        if (a.label.toLowerCase().contains(q)) a,
    ];
  }

  Future<void> _load() async {
    final apps = sortApps(
      await _s.device.installedApps(),
      PaymentRules.preselectPackages,
    );
    if (_disposed) return;
    _selected = initialSelection(
      chosen: _s.settings.paymentAppsChosen.value,
      allowlist: _s.settings.paymentApps.value,
      installed: {for (final a in apps) a.packageName},
      preselect: PaymentRules.preselectPackages,
    );
    _apps = apps;
    notifyListeners();
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  void toggle(String packageName) {
    _selected = _selected.contains(packageName)
        ? ({..._selected}..remove(packageName))
        : {..._selected, packageName};
    notifyListeners();
  }

  /// Stores the ticked apps, sends them to the native listener and reads the settings again.
  Future<void> save() async {
    await _s.paymentApps.save(_selected);
    await _s.settings.reload();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
