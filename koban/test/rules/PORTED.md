# Ported Kotlin tests

Each Kotlin `@Test` has one Dart `test(`. The last column counts Dart tests that have no Kotlin source.

| Kotlin test file | Kotlin @Test count | Dart test file | Dart test count | added beyond Kotlin |
|---|---|---|---|---|
| parser/AmountFormatterTest | 5 | rules/amount_formatter_test.dart | 6 | 1 |
| parser/MerchantNormalizerTest | 6 | rules/merchant_normalizer_test.dart | 6 | 0 |
| parser/DedupKeyGeneratorTest | 3 | rules/dedup_key_generator_test.dart | 5 | 2 |
| parser/NotificationParserTest | 16 | rules/notification_parser_test.dart | 17 | 1 |
| parser/PaymentRulesTest | 32 | rules/payment_rules_test.dart | 32 | 0 |
| parser/ReceiptRulesTest | 27 | rules/receipt_rules_test.dart | 27 | 0 |
| parser/ReceiptTiltScanTest | 2 | rules/receipt_scan_test.dart | 6 (shared) | 0 |
| parser/ReceiptLevelScanTest | 1 | rules/receipt_scan_test.dart | (shared) | 0 |
| parser/ReceiptCloudChoiceTest | 2 | rules/receipt_scan_test.dart | (shared) | 0 |
| parser/ReceiptBenchmarkTest | 1 | rules/receipt_scan_test.dart | (shared) | 0 |
| data/SplitMathTest | 11 | rules/split_math_test.dart | 13 | 2 |
| data/PeopleMathTest | 13 | rules/people_math_test.dart | 13 | 0 |
| data/RepaymentMatcherTest | 6 | rules/repayment_matcher_test.dart | 6 | 0 |
| data/PeriodCalculatorTest | 2 | rules/periods_test.dart | 11 (shared) | 0 |
| data/MonthNavTest | 5 | rules/periods_test.dart | (shared) | 0 |
| groups/PeriodMathTest | 3 | rules/periods_test.dart | (shared) | 1 |
| (none, Task 1) | 0 | rules/purity_test.dart | 1 | 1 |
| (none, Task 1) | 0 | theme/tokens_test.dart | 3 | 3 |
| **Total** | **135** | | **146** | **11** |

Check: 135 ported + 7 added tests in rules + 4 Task 1 tests = 146.
`flutter test` runs 147 tests: the 146 above plus the template test `koban/test/widget_test.dart`.

The "added beyond Kotlin" count of PeriodMathTest row is the one extra test in `periods_test.dart` (11 Dart tests, 10 Kotlin tests).

## Kotlin tests that move in later milestones

Update (moved in milestones 4 and 5): ReleaseParser 6 and UpdateSchedule 5 in `test/update/`. ApkCheck 4 is the Kotlin `ApkCheckTest` in `koban/android`.

Screen rules (moved in milestones 4 and 5): OnboardingRules 19, AmountInput 11, PaymentAppsRules 3, DonutSlices 3. CacheFile 5 is in `test/receipts/cache_file_test.dart`. SplitReadNote 1 is in `test/screens/split_read_note_test.dart`.
