import 'dart:async';
import 'dart:developer' as developer;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, immutable;
import 'package:intl/intl.dart';

import '../../app/app_services.dart';
import '../../data/database.dart';
import '../../data/ids.dart';
import '../../data/split_repository.dart';
import '../../data/user_error.dart';
import '../../online/receipt_cloud_client.dart' show ReceiptCloudClient;
import '../../receipts/receipt_photos.dart';
import '../../rules/amount_formatter.dart';
import '../../rules/receipt_cloud.dart'
    show CloudRead, CloudReadFailed, CloudReadOk, chooseReceiptRead;
import '../../rules/receipt_rules.dart' show ReceiptRead;
import '../../rules/split_math.dart';

/// The steps of the split editor.
enum SplitStep { photo, reading, items, people, assign, link, summary }

const _loadFailed = 'Something went wrong. Try again.';
const _saveFailed = "Couldn't save the split. Try again.";
const _deleteFailed = "Couldn't delete the split. Try again.";
const _keep = Object();

/// One item row that the user edits. The text stays as typed; [SplitEditorViewModel.parseItems] checks it.
@immutable
class ItemRow {
  const ItemRow({
    required this.key,
    this.name = '',
    this.quantity = '1',
    this.price = '',
    this.sharedBy = const {},
  });

  final int key;
  final String name;
  final String quantity;
  final String price;
  final Set<String> sharedBy;

  ItemRow copyWith({
    String? name,
    String? quantity,
    String? price,
    Set<String>? sharedBy,
  }) => ItemRow(
    key: key,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    price: price ?? this.price,
    sharedBy: sharedBy ?? this.sharedBy,
  );
}

/// What the split editor shows. A port of `SplitEditorState` of 0.1.1.
@immutable
class SplitEditorState {
  const SplitEditorState({
    this.step = SplitStep.photo,
    this.loading = false,
    this.billId,
    this.locked = false,
    this.editing = false,
    this.confirmDiscard = false,
    this.merchant = '',
    required this.billTime,
    this.printedTotal,
    this.items = const [],
    this.serviceCharge = '',
    this.tax = '',
    this.discount = '',
    this.rounding = '',
    this.people = const [],
    this.candidates = const [],
    this.selectedExpenseId,
    this.message,
    this.onlineAccess = false,
    this.readNote,
    this.readSource,
    this.readsLeft,
    this.canReadAgain = false,
    this.readingAgain = false,
    this.error,
    this.saving = false,
    this.finished = false,
  });

  final SplitStep step;
  final bool loading;
  final String? billId;

  /// A bill with a paid debt. Only its payment link and its deletion can change.
  final bool locked;

  /// A saved bill that the user opened again with "Edit items". Without it, a saved bill is only viewed.
  final bool editing;

  /// Back was pressed while the user edits a saved bill. The screen asks before it drops the edits.
  final bool confirmDiscard;
  final String merchant;
  final int billTime;
  final Decimal? printedTotal;
  final List<ItemRow> items;
  final String serviceCharge;
  final String tax;
  final String discount;
  final String rounding;

  /// The people who share the bill, without the owner.
  final List<SplitPeopleData> people;
  final List<Expense> candidates;
  final String? selectedExpenseId;
  final String? message;

  /// A device token is stored.
  final bool onlineAccess;

  /// The line under the items that says the read matches the receipt total.
  final String? readNote;

  /// Who read the receipt, or why Claude did not.
  final String? readSource;

  /// The Claude reads left today, when the server said.
  final int? readsLeft;

  /// "Read again with Claude" shows: online access, a kept photo and no Claude run for it.
  final bool canReadAgain;
  final bool readingAgain;
  final String? error;
  final bool saving;
  final bool finished;

  SplitEditorState copyWith({
    SplitStep? step,
    bool? loading,
    Object? billId = _keep,
    bool? locked,
    bool? editing,
    bool? confirmDiscard,
    String? merchant,
    int? billTime,
    Object? printedTotal = _keep,
    List<ItemRow>? items,
    String? serviceCharge,
    String? tax,
    String? discount,
    String? rounding,
    List<SplitPeopleData>? people,
    List<Expense>? candidates,
    Object? selectedExpenseId = _keep,
    Object? message = _keep,
    bool? onlineAccess,
    Object? readNote = _keep,
    Object? readSource = _keep,
    Object? readsLeft = _keep,
    bool? canReadAgain,
    bool? readingAgain,
    Object? error = _keep,
    bool? saving,
    bool? finished,
  }) => SplitEditorState(
    step: step ?? this.step,
    loading: loading ?? this.loading,
    billId: identical(billId, _keep) ? this.billId : billId as String?,
    locked: locked ?? this.locked,
    editing: editing ?? this.editing,
    confirmDiscard: confirmDiscard ?? this.confirmDiscard,
    merchant: merchant ?? this.merchant,
    billTime: billTime ?? this.billTime,
    printedTotal: identical(printedTotal, _keep)
        ? this.printedTotal
        : printedTotal as Decimal?,
    items: items ?? this.items,
    serviceCharge: serviceCharge ?? this.serviceCharge,
    tax: tax ?? this.tax,
    discount: discount ?? this.discount,
    rounding: rounding ?? this.rounding,
    people: people ?? this.people,
    candidates: candidates ?? this.candidates,
    selectedExpenseId: identical(selectedExpenseId, _keep)
        ? this.selectedExpenseId
        : selectedExpenseId as String?,
    message: identical(message, _keep) ? this.message : message as String?,
    onlineAccess: onlineAccess ?? this.onlineAccess,
    readNote: identical(readNote, _keep) ? this.readNote : readNote as String?,
    readSource: identical(readSource, _keep)
        ? this.readSource
        : readSource as String?,
    readsLeft: identical(readsLeft, _keep) ? this.readsLeft : readsLeft as int?,
    canReadAgain: canReadAgain ?? this.canReadAgain,
    readingAgain: readingAgain ?? this.readingAgain,
    error: identical(error, _keep) ? this.error : error as String?,
    saving: saving ?? this.saving,
    finished: finished ?? this.finished,
  );
}

/// A blank charge is zero. A bad charge is null.
Decimal? _parseMoney(String text) =>
    text.trim().isEmpty ? Decimal.zero : AmountFormatter.parseInput(text);

String _chargeText(Decimal v) =>
    v.sign == 0 ? '' : AmountFormatter.formatDisplay(v);

// Kotlin Int.MAX_VALUE: a bigger quantity did not parse in 0.1.1.
const _maxInt = 2147483647;

/// The rules of the split editor. A port of `SplitEditorViewModel.kt`.
class SplitEditorViewModel extends ChangeNotifier {
  SplitEditorViewModel(this._s, {String? billId, String? expenseId})
    : _state = SplitEditorState(
        billTime: _s.now().millisecondsSinceEpoch,
        onlineAccess: _s.settings.hasDeviceToken.value,
      ) {
    _s.settings.hasDeviceToken.addListener(_onToken);
    _recentSub = _s.splits.watchRecentPeople().listen(
      (list) {
        _recent = list;
        _notify();
      },
      onError: (Object e, StackTrace st) => _log('Recent people failed', e, st),
    );
    if (billId != null) {
      _state = _state.copyWith(loading: true);
      ready = _loadGuarded(() => _loadExisting(billId));
    } else if (expenseId != null) {
      _state = _state.copyWith(loading: true);
      ready = _loadGuarded(() => _startFromPayment(expenseId));
    } else {
      ready = Future.value();
    }
  }

  final AppServices _s;
  StreamSubscription<List<SplitPeopleData>>? _recentSub;
  List<SplitPeopleData> _recent = const [];
  SplitEditorState _state;
  int _nextKey = 0;
  bool _disposed = false;

  /// The receipt photo that "Read again with Claude" needs. Null when none is kept.
  String? _photo;

  /// True when Claude read [_photo], or used a read of the day on it.
  bool _claudeRan = false;

  /// The number of the last read. A read that ends with an older number shows nothing.
  int _reads = 0;

  /// Completes when a saved bill or the linked payment has loaded.
  late final Future<void> ready;

  SplitEditorState get state => _state;

  /// The people of earlier splits, last used first.
  List<SplitPeopleData> get recentPeople => _recent;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _update(SplitEditorState Function(SplitEditorState) change) {
    if (_disposed) return;
    _state = change(_state);
    notifyListeners();
  }

  void _onToken() => _update((s) {
    final online = _s.settings.hasDeviceToken.value;
    return s.copyWith(
      onlineAccess: online,
      canReadAgain: _canReadAgain(online),
    );
  });

  /// Removes the cancelled device token. A failed removal must not stop the read from showing.
  Future<void> _removeToken() async {
    try {
      await _s.online.secrets.setDeviceToken('');
    } catch (e) {
      developer.log(
        'Remove device token failed (${e.runtimeType})',
        name: 'SplitEditorViewModel',
      );
    }
  }

  static void _log(String message, Object e, StackTrace st) => developer.log(
    message,
    name: 'SplitEditorViewModel',
    error: e,
    stackTrace: st,
  );

  /// A failed load ends the spinner and shows the error text.
  Future<void> _loadGuarded(Future<void> Function() load) async {
    try {
      await load();
    } catch (e, st) {
      _log('Load failed', e, st);
      _update((s) => s.copyWith(loading: false, error: _loadFailed));
    }
  }

  Future<void> _startFromPayment(String expenseId) async {
    final existing = await _s.splits.billForExpense(expenseId);
    if (existing != null) return _loadExisting(existing.id);
    final expense = await _s.expenses.getById(expenseId);
    // The time of the linked payment is the best bill time until a receipt gives a date.
    _update(
      (s) => s.copyWith(
        loading: false,
        selectedExpenseId: expenseId,
        billTime: expense?.notificationPostTime ?? s.billTime,
      ),
    );
  }

  Future<void> _loadExisting(String billId) async {
    final draft = await _s.splits.loadDraft(billId);
    if (draft == null) {
      _update((s) => s.copyWith(loading: false, finished: true));
      return;
    }
    final locked = await _s.splits.isLocked(billId);
    _update(
      (s) => s.copyWith(
        loading: false,
        billId: billId,
        locked: locked,
        step: SplitStep.summary,
        merchant: draft.merchant ?? '',
        billTime: draft.billTime,
        printedTotal: draft.printedTotal,
        items: [
          for (final item in draft.items)
            ItemRow(
              key: _nextKey++,
              name: item.name,
              quantity: '${item.quantity}',
              price: AmountFormatter.formatDisplay(item.price),
              sharedBy: item.sharedBy,
            ),
        ],
        serviceCharge: _chargeText(draft.charges.serviceCharge),
        tax: _chargeText(draft.charges.tax),
        discount: _chargeText(draft.charges.discount),
        rounding: _chargeText(draft.charges.rounding),
        people: draft.people,
        selectedExpenseId: draft.linkedExpenseId,
      ),
    );
  }

  // Photo and reading

  bool _canReadAgain(bool online) => online && _photo != null && !_claudeRan;

  /// Deletes the kept photo when it is in the app cache. A photo of the gallery stays.
  void _dropPhoto() {
    final path = _photo;
    _photo = null;
    _update((s) => s.copyWith(canReadAgain: false));
    if (path == null) return;
    () async {
      try {
        await deleteIfCache(path, (await _s.cacheDir()).path);
      } catch (e) {
        developer.log(
          'Delete receipt photo failed (${e.runtimeType})',
          name: 'SplitEditorViewModel',
        );
      }
    }();
  }

  /// The Claude read. Null when the call throws: the phone read then shows alone.
  Future<CloudRead?> _cloudRead(String path, String token) async {
    try {
      return await _s.online.receiptCloud.read(path, token);
    } catch (e) {
      developer.log(
        'Claude read failed (${e.runtimeType})',
        name: 'SplitEditorViewModel',
      );
      return null;
    }
  }

  /// Reads the photo on the phone and, with a device token, with Claude at the same time.
  /// The photo stays for "Read again with Claude" until the items step closes.
  Future<void> readReceipt(String path) async {
    final run = ++_reads;
    _dropPhoto();
    _photo = path;
    _claudeRan = false;
    _update(
      (s) => s.copyWith(
        step: SplitStep.reading,
        message: null,
        readNote: null,
        readSource: null,
      ),
    );
    final token = _s.online.secrets.deviceToken.value;
    final (rules, cloud) = await (
      _s.receiptReader.read(path),
      token.isEmpty ? Future<CloudRead?>.value() : _cloudRead(path, token),
    ).wait;
    if (cloud is CloudReadFailed && cloud.tokenRevoked) {
      await _removeToken();
    }
    // Back or close ended this read: it shows nothing.
    if (run != _reads) return;
    _claudeRan =
        cloud is CloudReadOk || (cloud is CloudReadFailed && cloud.usedRead);
    final (read, source) = chooseReceiptRead(rules, cloud);
    _showRead(read, source, cloud is CloudReadOk ? cloud.readsLeft : null);
  }

  /// Sends the kept photo to Claude and replaces the items with its read.
  Future<void> readAgainWithClaude() async {
    final path = _photo;
    if (path == null || _state.readingAgain) return;
    _update((s) => s.copyWith(readingAgain: true));
    final token = _s.online.secrets.deviceToken.value;
    final cloud = token.isEmpty
        ? const CloudReadFailed('Enter an invite code in Settings first.')
        : await _cloudRead(path, token) ??
              const CloudReadFailed(ReceiptCloudClient.notReachable);
    if (cloud is CloudReadFailed && cloud.tokenRevoked) {
      await _removeToken();
    }
    _update((s) => s.copyWith(readingAgain: false));
    // The items step closed while Claude read: the photo is gone and the answer shows nothing.
    if (_photo != path) return;
    switch (cloud) {
      case CloudReadOk():
        _claudeRan = true;
        _showRead(
          cloud.read,
          chooseReceiptRead(null, cloud).$2,
          cloud.readsLeft,
        );
      case CloudReadFailed():
        if (cloud.usedRead) _claudeRan = true;
        _update(
          (s) => s.copyWith(
            readSource: cloud.why,
            canReadAgain: _canReadAgain(s.onlineAccess),
          ),
        );
    }
  }

  void _showRead(ReceiptRead? read, String? source, int? readsLeft) {
    final draft = read?.draft;
    _update(
      (s) => s.copyWith(
        step: SplitStep.items,
        merchant: draft?.merchant ?? '',
        billTime: draft?.dateMillis ?? s.billTime,
        printedTotal: draft?.printedTotal,
        items: [
          for (final item in draft?.items ?? const [])
            ItemRow(
              key: _nextKey++,
              name: item.name,
              quantity: '${item.quantity}',
              price: AmountFormatter.formatDisplay(item.price),
            ),
        ],
        serviceCharge: draft == null ? '' : _chargeText(draft.serviceCharge),
        tax: draft == null ? '' : _chargeText(draft.tax),
        discount: draft == null ? '' : _chargeText(draft.discount),
        rounding: draft == null ? '' : _chargeText(draft.rounding),
        readNote: read == null ? null : readNote(read),
        readSource: source,
        readsLeft: readsLeft ?? s.readsLeft,
        canReadAgain: _canReadAgain(s.onlineAccess),
        message: draft == null
            ? "Couldn't read this receipt. Add the items by hand."
            : draft.printedTotal == null
            ? 'No total found on the receipt. Check the items.'
            : null,
      ),
    );
  }

  void typeItemsInstead() {
    _update((s) => s.copyWith(step: SplitStep.items, message: null));
    if (_state.items.isEmpty) addItem();
  }

  // Items

  void addItem() => _update(
    (s) => s.copyWith(
      items: [
        ...s.items,
        ItemRow(key: _nextKey++),
      ],
    ),
  );

  void updateItem(int key, ItemRow Function(ItemRow) change) => _update(
    (s) => s.copyWith(
      items: [for (final r in s.items) r.key == key ? change(r) : r],
    ),
  );

  void removeItem(int key) => _update(
    (s) => s.copyWith(items: s.items.where((r) => r.key != key).toList()),
  );

  void setMerchant(String v) => _update((s) => s.copyWith(merchant: v));
  void setServiceCharge(String v) =>
      _update((s) => s.copyWith(serviceCharge: v));
  void setTax(String v) => _update((s) => s.copyWith(tax: v));
  void setDiscount(String v) => _update((s) => s.copyWith(discount: v));
  void setRounding(String v) => _update((s) => s.copyWith(rounding: v));

  /// Moves the whole gap to the printed total into the rounding field.
  void addRoundingDifference() {
    final diff = difference(_state);
    final current = _parseMoney(_state.rounding);
    if (diff == null || current == null) return;
    _update(
      (s) =>
          s.copyWith(rounding: AmountFormatter.formatDisplay(current + diff)),
    );
  }

  // People

  void addPerson(String name) {
    final trimmed = name.trim();
    final key = trimmed.toLowerCase();
    if (trimmed.isEmpty || key == 'me') return;
    if (_state.people.any((p) => p.name.toLowerCase() == key)) return;
    final known = _recent.where((p) => p.name.toLowerCase() == key).firstOrNull;
    _update(
      (s) => s.copyWith(
        people: [
          ...s.people,
          known ??
              SplitPeopleData(
                id: newId(),
                name: trimmed,
                lastUsedAt: 0,
                archived: false,
              ),
        ],
      ),
    );
  }

  void togglePerson(SplitPeopleData person) {
    if (!_state.people.any((p) => p.id == person.id)) {
      addPerson(person.name);
      return;
    }
    _update(
      (s) => s.copyWith(
        people: s.people.where((p) => p.id != person.id).toList(),
        items: [
          for (final r in s.items)
            r.copyWith(sharedBy: {...r.sharedBy}..remove(person.id)),
        ],
      ),
    );
  }

  // Assign

  void toggleShare(int key, String personId) => updateItem(
    key,
    (r) => r.copyWith(
      sharedBy: r.sharedBy.contains(personId)
          ? ({...r.sharedBy}..remove(personId))
          : {...r.sharedBy, personId},
    ),
  );

  // Link

  void selectExpense(String? id) =>
      _update((s) => s.copyWith(selectedExpenseId: id));

  Future<void> _loadCandidates() async {
    final s = _state;
    final total = totalOf(s);
    if (total == null) return;
    final found = await _s.splits.paymentCandidates(
      s.billId,
      total,
      s.billTime,
    );
    final id = s.selectedExpenseId;
    final selected = id == null || found.any((e) => e.id == id)
        ? null
        : await _s.expenses.getById(id);
    _update((st) => st.copyWith(candidates: [?selected, ...found]));
  }

  void _loadCandidatesLogged() {
    _loadCandidates().catchError((Object e, StackTrace st) {
      developer.log(
        'Payment candidates failed',
        name: 'SplitEditorViewModel',
        error: e,
        stackTrace: st,
      );
    });
  }

  /// Locked bills only: saves the new link at once and shows the summary again.
  Future<void> saveLockedPayment() async {
    final billId = _state.billId;
    if (billId == null || _state.saving) return;
    _update((s) => s.copyWith(saving: true, error: null));
    try {
      await _s.splits.linkPayment(billId, _state.selectedExpenseId);
      _update((s) => s.copyWith(step: SplitStep.summary, saving: false));
    } on KobanUserError catch (e) {
      _update((s) => s.copyWith(saving: false, error: e.message));
    } catch (e, st) {
      developer.log(
        'Link payment failed',
        name: 'SplitEditorViewModel',
        error: e,
        stackTrace: st,
      );
      _update((s) => s.copyWith(saving: false, error: _saveFailed));
    }
  }

  void editItems() => _update(
    (s) => s.copyWith(step: SplitStep.items, editing: true, error: null),
  );

  void changePayment() {
    _update((s) => s.copyWith(step: SplitStep.link));
    _loadCandidatesLogged();
  }

  Future<void> deleteSplit() async {
    final billId = _state.billId;
    if (billId == null || _state.saving) return;
    _update((s) => s.copyWith(saving: true, error: null));
    try {
      await _s.splits.deleteSplit(billId);
      _update((s) => s.copyWith(finished: true));
    } catch (e, st) {
      developer.log(
        'Delete split failed',
        name: 'SplitEditorViewModel',
        error: e,
        stackTrace: st,
      );
      _update((s) => s.copyWith(saving: false, error: _deleteFailed));
    }
  }

  // Moves between the steps

  void next() {
    final target = switch (_state.step) {
      SplitStep.items => SplitStep.people,
      SplitStep.people => SplitStep.assign,
      SplitStep.assign => SplitStep.link,
      SplitStep.link => SplitStep.summary,
      _ => null,
    };
    if (target == null) return;
    if (_state.step == SplitStep.items) _dropPhoto();
    _update((s) => s.copyWith(step: target, error: null));
    if (target == SplitStep.link) _loadCandidatesLogged();
  }

  /// Returns false when the screen must leave the editor.
  bool back() {
    final s = _state;
    final SplitStep target;
    switch (s.step) {
      case SplitStep.photo:
        return false;
      case SplitStep.reading:
        // The late result of this read shows nothing.
        _reads++;
        _dropPhoto();
        target = SplitStep.photo;
      case SplitStep.items:
        // ponytail: "editing" counts as changed even with no edit; compare with the saved draft if this asks too often.
        if (s.billId != null && s.editing) {
          _update((st) => st.copyWith(confirmDiscard: true));
          return true;
        }
        _dropPhoto();
        if (s.billId != null) return false;
        target = SplitStep.photo;
      case SplitStep.people:
        target = SplitStep.items;
      case SplitStep.assign:
        target = SplitStep.people;
      case SplitStep.link:
        target = s.locked ? SplitStep.summary : SplitStep.assign;
      case SplitStep.summary:
        if (s.locked || (s.billId != null && !s.editing)) return false;
        target = SplitStep.link;
    }
    _update((st) => st.copyWith(step: target, error: null));
    return true;
  }

  /// Clears the question flag. The screen then leaves the editor.
  void discardEdits() {
    _update((s) => s.copyWith(confirmDiscard: false));
    _dropPhoto();
  }

  void keepEditing() => _update((s) => s.copyWith(confirmDiscard: false));

  // Save

  Future<void> done() async {
    final s = _state;
    if (s.locked || s.saving) return;
    // A viewed bill has nothing to save. A new save would drop its repayment suggestions.
    if (s.billId != null && !s.editing) {
      _update((st) => st.copyWith(finished: true));
      return;
    }
    final items = parseItems(s);
    final charges = chargesOf(s);
    if (items == null || charges == null) return;
    final merchant = s.merchant.trim();
    final draft = SplitDraft(
      billId: s.billId,
      merchant: merchant.isEmpty ? null : merchant,
      billTime: s.billTime,
      currency: 'MYR',
      printedTotal: s.printedTotal,
      items: items,
      charges: charges,
      people: s.people,
      linkedExpenseId: s.selectedExpenseId,
    );
    _update((st) => st.copyWith(saving: true, error: null));
    try {
      await _s.splits.saveSplit(draft);
      _update((st) => st.copyWith(finished: true));
    } on KobanUserError catch (e) {
      _update((st) => st.copyWith(saving: false, error: e.message));
    } catch (e, stack) {
      developer.log(
        'Save split failed',
        name: 'SplitEditorViewModel',
        error: e,
        stackTrace: stack,
      );
      _update((st) => st.copyWith(saving: false, error: _saveFailed));
    }
  }

  @override
  void dispose() {
    _reads++;
    _dropPhoto();
    _disposed = true;
    _s.settings.hasDeviceToken.removeListener(_onToken);
    _recentSub?.cancel();
    super.dispose();
  }

  // Values that the screen shows. They use only the state.

  /// The line for an accepted read. Null otherwise: the mismatch warning or an error text covers it.
  static String? readNote(ReceiptRead read) {
    final total = read.draft.printedTotal;
    if (total == null || !read.accepted) return null;
    final calculated = read.calculated.isEmpty
        ? ''
        : ' with a calculated ${read.calculated.join(' and ')}';
    return 'Matches the receipt total of RM ${AmountFormatter.formatDisplay(total)}$calculated.';
  }

  /// Null when a row has a bad name, quantity or price.
  static List<DraftItem>? parseItems(SplitEditorState s) {
    final out = <DraftItem>[];
    for (final row in s.items) {
      final price = AmountFormatter.parseInput(row.price);
      final quantity = int.tryParse(row.quantity.trim(), radix: 10);
      if (row.name.trim().isEmpty ||
          price == null ||
          price.sign <= 0 ||
          quantity == null ||
          quantity < 1 ||
          quantity > _maxInt) {
        return null;
      }
      out.add(
        DraftItem(
          name: row.name.trim(),
          quantity: quantity,
          price: price,
          sharedBy: row.sharedBy,
        ),
      );
    }
    return out;
  }

  static SplitCharges? chargesOf(SplitEditorState s) {
    final service = _parseMoney(s.serviceCharge);
    final tax = _parseMoney(s.tax);
    final discount = _parseMoney(s.discount);
    final rounding = _parseMoney(s.rounding);
    if (service == null ||
        tax == null ||
        discount == null ||
        rounding == null) {
      return null;
    }
    return SplitCharges(
      serviceCharge: service,
      tax: tax,
      discount: discount,
      rounding: rounding,
    );
  }

  static List<SplitItemInput>? _inputsOf(SplitEditorState s) =>
      parseItems(s)
          ?.map((i) => SplitItemInput(price: i.price, sharedBy: i.sharedBy))
          .toList();

  static Decimal? totalOf(SplitEditorState s) {
    final items = _inputsOf(s);
    final charges = chargesOf(s);
    if (items == null || charges == null) return null;
    return SplitMath.computedTotal(items, charges);
  }

  /// The printed total minus the computed total. Null when they are equal, or one is not known or not valid.
  static Decimal? difference(SplitEditorState s) {
    final printed = s.printedTotal;
    final total = totalOf(s);
    if (printed == null || total == null) return null;
    final diff = printed - total;
    return diff.sign == 0 ? null : diff;
  }

  /// The keys of the rows that nobody shares.
  static Set<int> unassigned(SplitEditorState s) => {
    for (final i in SplitMath.unassignedItemIndexes([
      for (final r in s.items)
        SplitItemInput(price: Decimal.zero, sharedBy: r.sharedBy),
    ]))
      s.items[i].key,
  };

  /// The names with their amounts, Me last. Null until the bill is complete.
  static List<(String, Decimal)>? summaryLines(SplitEditorState s) {
    final inputs = _inputsOf(s);
    final charges = chargesOf(s);
    if (inputs == null || charges == null) return null;
    if (SplitMath.unassignedItemIndexes(inputs).isNotEmpty) return null;
    final shares = SplitMath.shares(inputs, charges);
    final names = {for (final p in s.people) p.id: p.name};
    return [
      for (final e in shares.entries)
        if (e.key != meId) (names[e.key] ?? e.key, e.value),
      ('Me', shares[meId]!),
    ];
  }

  static String? shareText(SplitEditorState s) {
    final lines = summaryLines(s);
    final total = totalOf(s);
    if (lines == null || total == null) return null;
    final date = DateFormat(
      'd MMM yyyy',
      'en_US',
    ).format(DateTime.fromMillisecondsSinceEpoch(s.billTime));
    final merchant = s.merchant.trim();
    final head = '${merchant.isEmpty ? 'Bill' : merchant}, $date';
    final body = lines
        .map((l) => '${l.$1}: RM ${AmountFormatter.formatGrouped(l.$2)}')
        .join('\n');
    return '$head\n$body\nTotal: RM ${AmountFormatter.formatGrouped(total)}';
  }
}
