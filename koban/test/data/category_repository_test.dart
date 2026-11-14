import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/category_repository.dart';
import 'package:koban/data/database.dart';

void main() {
  late KobanDatabase db;
  late CategoryRepository repo;

  setUp(() {
    db = KobanDatabase(NativeDatabase.memory());
    repo = CategoryRepository(db);
  });
  tearDown(() => db.close());

  test('seeding adds the 7 built-in categories one time', () async {
    await repo.seedIfEmpty();

    final first = await repo.watchAll().first;
    expect(first.map((c) => c.name), [
      'Bills & Utilities',
      'Entertainment',
      'Food & Dining',
      'Health',
      'Other',
      'Shopping',
      'Transport',
    ]);
    expect(first.every((c) => c.isDefault), isTrue);
    final food = await repo.getById('food');
    expect((food!.name, food.colorHex), ('Food & Dining', '#E53935'));

    await repo.seedIfEmpty();
    expect(await repo.watchAll().first, hasLength(7));
  });

  test('only own categories can be deleted', () async {
    await repo.seedIfEmpty();
    await repo.addCategory('  Hobi  ', '#123456');
    final own = (await repo.watchAll().first).firstWhere(
      (c) => c.name == 'Hobi',
    );
    expect(own.isDefault, isFalse);
    expect(own.colorHex, '#123456');

    expect(await repo.deleteCategory('food'), isFalse);
    expect(await repo.deleteCategory(own.id), isTrue);

    expect(await repo.watchAll().first, hasLength(7));
    expect(await repo.getById(own.id), isNull);
    expect(await repo.getById(null), isNull);
  });

  test('a blank name adds no category', () async {
    await repo.addCategory('   ', '#123456');

    expect(await repo.watchAll().first, isEmpty);
  });
}
