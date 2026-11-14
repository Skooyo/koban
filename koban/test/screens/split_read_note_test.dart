import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/receipt_rules.dart';
import 'package:koban/screens/split/split_editor_view_model.dart';

ReceiptRead read(
  bool accepted,
  String? total, [
  List<String> calculated = const [],
]) => ReceiptRead(
  ReceiptDraft(
    merchant: null,
    dateMillis: null,
    items: const [],
    serviceCharge: Decimal.zero,
    tax: Decimal.zero,
    discount: Decimal.zero,
    rounding: Decimal.zero,
    printedTotal: total == null ? null : Decimal.parse(total),
  ),
  accepted,
  calculated,
);

void main() {
  test('the read note names the receipt total and the calculated charges', () {
    expect(
      SplitEditorViewModel.readNote(read(true, '57.80')),
      'Matches the receipt total of RM 57.80.',
    );
    expect(
      SplitEditorViewModel.readNote(
        read(true, '57.80', ['10% service charge', '6% SST']),
      ),
      'Matches the receipt total of RM 57.80 with a calculated 10% service charge and 6% SST.',
    );
    expect(
      SplitEditorViewModel.readNote(read(true, '57.80', ['6% SST'])),
      'Matches the receipt total of RM 57.80 with a calculated 6% SST.',
    );
    expect(SplitEditorViewModel.readNote(read(false, null)), null);
    expect(SplitEditorViewModel.readNote(read(false, '57.80')), null);
  });
}
