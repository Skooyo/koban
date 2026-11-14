// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class Expenses extends Table with TableInfo<Expenses, Expense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Expenses(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  late final GeneratedColumnWithTypeConverter<Decimal, String> amount =
      GeneratedColumn<String>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<Decimal>(Expenses.$converteramount);
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _merchantMeta = const VerificationMeta(
    'merchant',
  );
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
    'merchant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _rawNotificationTextMeta =
      const VerificationMeta('rawNotificationText');
  late final GeneratedColumn<String> rawNotificationText =
      GeneratedColumn<String>(
        'rawNotificationText',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      );
  static const VerificationMeta _sourcePackageMeta = const VerificationMeta(
    'sourcePackage',
  );
  late final GeneratedColumn<String> sourcePackage = GeneratedColumn<String>(
    'sourcePackage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _notificationPostTimeMeta =
      const VerificationMeta('notificationPostTime');
  late final GeneratedColumn<int> notificationPostTime = GeneratedColumn<int>(
    'notificationPostTime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'createdAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _dedupKeyMeta = const VerificationMeta(
    'dedupKey',
  );
  late final GeneratedColumn<String> dedupKey = GeneratedColumn<String>(
    'dedupKey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<ExpenseStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<ExpenseStatus>(Expenses.$converterstatus);
  late final GeneratedColumnWithTypeConverter<ParseConfidence, String>
  confidence = GeneratedColumn<String>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  ).withConverter<ParseConfidence>(Expenses.$converterconfidence);
  static const VerificationMeta _notificationKeyMeta = const VerificationMeta(
    'notificationKey',
  );
  late final GeneratedColumn<String> notificationKey = GeneratedColumn<String>(
    'notificationKey',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'categoryId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  late final GeneratedColumnWithTypeConverter<TransactionType, String>
  transactionType = GeneratedColumn<String>(
    'transactionType',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  ).withConverter<TransactionType>(Expenses.$convertertransactionType);
  late final GeneratedColumnWithTypeConverter<Decimal?, String> countedAmount =
      GeneratedColumn<String>(
        'countedAmount',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      ).withConverter<Decimal?>(Expenses.$convertercountedAmountn);
  late final GeneratedColumnWithTypeConverter<bool, int> privateToGroups =
      GeneratedColumn<int>(
        'privateToGroups',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<bool>(Expenses.$converterprivateToGroups);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    amount,
    currency,
    merchant,
    rawNotificationText,
    sourcePackage,
    notificationPostTime,
    createdAt,
    dedupKey,
    status,
    confidence,
    notificationKey,
    categoryId,
    notes,
    transactionType,
    countedAmount,
    privateToGroups,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Expense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('merchant')) {
      context.handle(
        _merchantMeta,
        merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta),
      );
    }
    if (data.containsKey('rawNotificationText')) {
      context.handle(
        _rawNotificationTextMeta,
        rawNotificationText.isAcceptableOrUnknown(
          data['rawNotificationText']!,
          _rawNotificationTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rawNotificationTextMeta);
    }
    if (data.containsKey('sourcePackage')) {
      context.handle(
        _sourcePackageMeta,
        sourcePackage.isAcceptableOrUnknown(
          data['sourcePackage']!,
          _sourcePackageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourcePackageMeta);
    }
    if (data.containsKey('notificationPostTime')) {
      context.handle(
        _notificationPostTimeMeta,
        notificationPostTime.isAcceptableOrUnknown(
          data['notificationPostTime']!,
          _notificationPostTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_notificationPostTimeMeta);
    }
    if (data.containsKey('createdAt')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['createdAt']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('dedupKey')) {
      context.handle(
        _dedupKeyMeta,
        dedupKey.isAcceptableOrUnknown(data['dedupKey']!, _dedupKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dedupKeyMeta);
    }
    if (data.containsKey('notificationKey')) {
      context.handle(
        _notificationKeyMeta,
        notificationKey.isAcceptableOrUnknown(
          data['notificationKey']!,
          _notificationKeyMeta,
        ),
      );
    }
    if (data.containsKey('categoryId')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['categoryId']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Expense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Expense(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      amount: Expenses.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}amount'],
        )!,
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      merchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant'],
      ),
      rawNotificationText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rawNotificationText'],
      )!,
      sourcePackage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sourcePackage'],
      )!,
      notificationPostTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notificationPostTime'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}createdAt'],
      )!,
      dedupKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupKey'],
      )!,
      status: Expenses.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      confidence: Expenses.$converterconfidence.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}confidence'],
        )!,
      ),
      notificationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notificationKey'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categoryId'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      transactionType: Expenses.$convertertransactionType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}transactionType'],
        )!,
      ),
      countedAmount: Expenses.$convertercountedAmountn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}countedAmount'],
        ),
      ),
      privateToGroups: Expenses.$converterprivateToGroups.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}privateToGroups'],
        )!,
      ),
    );
  }

  @override
  Expenses createAlias(String alias) {
    return Expenses(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converteramount =
      const MoneyConverter();
  static TypeConverter<ExpenseStatus, String> $converterstatus =
      const ExpenseStatusConverter();
  static TypeConverter<ParseConfidence, String> $converterconfidence =
      const ParseConfidenceConverter();
  static TypeConverter<TransactionType, String> $convertertransactionType =
      const TransactionTypeConverter();
  static TypeConverter<Decimal, String> $convertercountedAmount =
      const MoneyConverter();
  static TypeConverter<Decimal?, String?> $convertercountedAmountn =
      NullAwareTypeConverter.wrap($convertercountedAmount);
  static TypeConverter<bool, int> $converterprivateToGroups =
      const BoolConverter();
  @override
  bool get dontWriteConstraints => true;
}

class Expense extends DataClass implements Insertable<Expense> {
  final String id;
  final Decimal amount;
  final String currency;
  final String? merchant;
  final String rawNotificationText;
  final String sourcePackage;
  final int notificationPostTime;
  final int createdAt;
  final String dedupKey;
  final ExpenseStatus status;
  final ParseConfidence confidence;
  final String? notificationKey;
  final String? categoryId;
  final String? notes;
  final TransactionType transactionType;
  final Decimal? countedAmount;
  final bool privateToGroups;
  const Expense({
    required this.id,
    required this.amount,
    required this.currency,
    this.merchant,
    required this.rawNotificationText,
    required this.sourcePackage,
    required this.notificationPostTime,
    required this.createdAt,
    required this.dedupKey,
    required this.status,
    required this.confidence,
    this.notificationKey,
    this.categoryId,
    this.notes,
    required this.transactionType,
    this.countedAmount,
    required this.privateToGroups,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['amount'] = Variable<String>(Expenses.$converteramount.toSql(amount));
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || merchant != null) {
      map['merchant'] = Variable<String>(merchant);
    }
    map['rawNotificationText'] = Variable<String>(rawNotificationText);
    map['sourcePackage'] = Variable<String>(sourcePackage);
    map['notificationPostTime'] = Variable<int>(notificationPostTime);
    map['createdAt'] = Variable<int>(createdAt);
    map['dedupKey'] = Variable<String>(dedupKey);
    {
      map['status'] = Variable<String>(Expenses.$converterstatus.toSql(status));
    }
    {
      map['confidence'] = Variable<String>(
        Expenses.$converterconfidence.toSql(confidence),
      );
    }
    if (!nullToAbsent || notificationKey != null) {
      map['notificationKey'] = Variable<String>(notificationKey);
    }
    if (!nullToAbsent || categoryId != null) {
      map['categoryId'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    {
      map['transactionType'] = Variable<String>(
        Expenses.$convertertransactionType.toSql(transactionType),
      );
    }
    if (!nullToAbsent || countedAmount != null) {
      map['countedAmount'] = Variable<String>(
        Expenses.$convertercountedAmountn.toSql(countedAmount),
      );
    }
    {
      map['privateToGroups'] = Variable<int>(
        Expenses.$converterprivateToGroups.toSql(privateToGroups),
      );
    }
    return map;
  }

  ExpensesCompanion toCompanion(bool nullToAbsent) {
    return ExpensesCompanion(
      id: Value(id),
      amount: Value(amount),
      currency: Value(currency),
      merchant: merchant == null && nullToAbsent
          ? const Value.absent()
          : Value(merchant),
      rawNotificationText: Value(rawNotificationText),
      sourcePackage: Value(sourcePackage),
      notificationPostTime: Value(notificationPostTime),
      createdAt: Value(createdAt),
      dedupKey: Value(dedupKey),
      status: Value(status),
      confidence: Value(confidence),
      notificationKey: notificationKey == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationKey),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      transactionType: Value(transactionType),
      countedAmount: countedAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(countedAmount),
      privateToGroups: Value(privateToGroups),
    );
  }

  factory Expense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Expense(
      id: serializer.fromJson<String>(json['id']),
      amount: serializer.fromJson<Decimal>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      merchant: serializer.fromJson<String?>(json['merchant']),
      rawNotificationText: serializer.fromJson<String>(
        json['rawNotificationText'],
      ),
      sourcePackage: serializer.fromJson<String>(json['sourcePackage']),
      notificationPostTime: serializer.fromJson<int>(
        json['notificationPostTime'],
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      dedupKey: serializer.fromJson<String>(json['dedupKey']),
      status: serializer.fromJson<ExpenseStatus>(json['status']),
      confidence: serializer.fromJson<ParseConfidence>(json['confidence']),
      notificationKey: serializer.fromJson<String?>(json['notificationKey']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      notes: serializer.fromJson<String?>(json['notes']),
      transactionType: serializer.fromJson<TransactionType>(
        json['transactionType'],
      ),
      countedAmount: serializer.fromJson<Decimal?>(json['countedAmount']),
      privateToGroups: serializer.fromJson<bool>(json['privateToGroups']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'amount': serializer.toJson<Decimal>(amount),
      'currency': serializer.toJson<String>(currency),
      'merchant': serializer.toJson<String?>(merchant),
      'rawNotificationText': serializer.toJson<String>(rawNotificationText),
      'sourcePackage': serializer.toJson<String>(sourcePackage),
      'notificationPostTime': serializer.toJson<int>(notificationPostTime),
      'createdAt': serializer.toJson<int>(createdAt),
      'dedupKey': serializer.toJson<String>(dedupKey),
      'status': serializer.toJson<ExpenseStatus>(status),
      'confidence': serializer.toJson<ParseConfidence>(confidence),
      'notificationKey': serializer.toJson<String?>(notificationKey),
      'categoryId': serializer.toJson<String?>(categoryId),
      'notes': serializer.toJson<String?>(notes),
      'transactionType': serializer.toJson<TransactionType>(transactionType),
      'countedAmount': serializer.toJson<Decimal?>(countedAmount),
      'privateToGroups': serializer.toJson<bool>(privateToGroups),
    };
  }

  Expense copyWith({
    String? id,
    Decimal? amount,
    String? currency,
    Value<String?> merchant = const Value.absent(),
    String? rawNotificationText,
    String? sourcePackage,
    int? notificationPostTime,
    int? createdAt,
    String? dedupKey,
    ExpenseStatus? status,
    ParseConfidence? confidence,
    Value<String?> notificationKey = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    TransactionType? transactionType,
    Value<Decimal?> countedAmount = const Value.absent(),
    bool? privateToGroups,
  }) => Expense(
    id: id ?? this.id,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    merchant: merchant.present ? merchant.value : this.merchant,
    rawNotificationText: rawNotificationText ?? this.rawNotificationText,
    sourcePackage: sourcePackage ?? this.sourcePackage,
    notificationPostTime: notificationPostTime ?? this.notificationPostTime,
    createdAt: createdAt ?? this.createdAt,
    dedupKey: dedupKey ?? this.dedupKey,
    status: status ?? this.status,
    confidence: confidence ?? this.confidence,
    notificationKey: notificationKey.present
        ? notificationKey.value
        : this.notificationKey,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    notes: notes.present ? notes.value : this.notes,
    transactionType: transactionType ?? this.transactionType,
    countedAmount: countedAmount.present
        ? countedAmount.value
        : this.countedAmount,
    privateToGroups: privateToGroups ?? this.privateToGroups,
  );
  Expense copyWithCompanion(ExpensesCompanion data) {
    return Expense(
      id: data.id.present ? data.id.value : this.id,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      rawNotificationText: data.rawNotificationText.present
          ? data.rawNotificationText.value
          : this.rawNotificationText,
      sourcePackage: data.sourcePackage.present
          ? data.sourcePackage.value
          : this.sourcePackage,
      notificationPostTime: data.notificationPostTime.present
          ? data.notificationPostTime.value
          : this.notificationPostTime,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      dedupKey: data.dedupKey.present ? data.dedupKey.value : this.dedupKey,
      status: data.status.present ? data.status.value : this.status,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      notificationKey: data.notificationKey.present
          ? data.notificationKey.value
          : this.notificationKey,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      notes: data.notes.present ? data.notes.value : this.notes,
      transactionType: data.transactionType.present
          ? data.transactionType.value
          : this.transactionType,
      countedAmount: data.countedAmount.present
          ? data.countedAmount.value
          : this.countedAmount,
      privateToGroups: data.privateToGroups.present
          ? data.privateToGroups.value
          : this.privateToGroups,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Expense(')
          ..write('id: $id, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('merchant: $merchant, ')
          ..write('rawNotificationText: $rawNotificationText, ')
          ..write('sourcePackage: $sourcePackage, ')
          ..write('notificationPostTime: $notificationPostTime, ')
          ..write('createdAt: $createdAt, ')
          ..write('dedupKey: $dedupKey, ')
          ..write('status: $status, ')
          ..write('confidence: $confidence, ')
          ..write('notificationKey: $notificationKey, ')
          ..write('categoryId: $categoryId, ')
          ..write('notes: $notes, ')
          ..write('transactionType: $transactionType, ')
          ..write('countedAmount: $countedAmount, ')
          ..write('privateToGroups: $privateToGroups')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    amount,
    currency,
    merchant,
    rawNotificationText,
    sourcePackage,
    notificationPostTime,
    createdAt,
    dedupKey,
    status,
    confidence,
    notificationKey,
    categoryId,
    notes,
    transactionType,
    countedAmount,
    privateToGroups,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Expense &&
          other.id == this.id &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.merchant == this.merchant &&
          other.rawNotificationText == this.rawNotificationText &&
          other.sourcePackage == this.sourcePackage &&
          other.notificationPostTime == this.notificationPostTime &&
          other.createdAt == this.createdAt &&
          other.dedupKey == this.dedupKey &&
          other.status == this.status &&
          other.confidence == this.confidence &&
          other.notificationKey == this.notificationKey &&
          other.categoryId == this.categoryId &&
          other.notes == this.notes &&
          other.transactionType == this.transactionType &&
          other.countedAmount == this.countedAmount &&
          other.privateToGroups == this.privateToGroups);
}

class ExpensesCompanion extends UpdateCompanion<Expense> {
  final Value<String> id;
  final Value<Decimal> amount;
  final Value<String> currency;
  final Value<String?> merchant;
  final Value<String> rawNotificationText;
  final Value<String> sourcePackage;
  final Value<int> notificationPostTime;
  final Value<int> createdAt;
  final Value<String> dedupKey;
  final Value<ExpenseStatus> status;
  final Value<ParseConfidence> confidence;
  final Value<String?> notificationKey;
  final Value<String?> categoryId;
  final Value<String?> notes;
  final Value<TransactionType> transactionType;
  final Value<Decimal?> countedAmount;
  final Value<bool> privateToGroups;
  final Value<int> rowid;
  const ExpensesCompanion({
    this.id = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.merchant = const Value.absent(),
    this.rawNotificationText = const Value.absent(),
    this.sourcePackage = const Value.absent(),
    this.notificationPostTime = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.dedupKey = const Value.absent(),
    this.status = const Value.absent(),
    this.confidence = const Value.absent(),
    this.notificationKey = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.notes = const Value.absent(),
    this.transactionType = const Value.absent(),
    this.countedAmount = const Value.absent(),
    this.privateToGroups = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpensesCompanion.insert({
    required String id,
    required Decimal amount,
    required String currency,
    this.merchant = const Value.absent(),
    required String rawNotificationText,
    required String sourcePackage,
    required int notificationPostTime,
    required int createdAt,
    required String dedupKey,
    required ExpenseStatus status,
    required ParseConfidence confidence,
    this.notificationKey = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.notes = const Value.absent(),
    required TransactionType transactionType,
    this.countedAmount = const Value.absent(),
    required bool privateToGroups,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       amount = Value(amount),
       currency = Value(currency),
       rawNotificationText = Value(rawNotificationText),
       sourcePackage = Value(sourcePackage),
       notificationPostTime = Value(notificationPostTime),
       createdAt = Value(createdAt),
       dedupKey = Value(dedupKey),
       status = Value(status),
       confidence = Value(confidence),
       transactionType = Value(transactionType),
       privateToGroups = Value(privateToGroups);
  static Insertable<Expense> custom({
    Expression<String>? id,
    Expression<String>? amount,
    Expression<String>? currency,
    Expression<String>? merchant,
    Expression<String>? rawNotificationText,
    Expression<String>? sourcePackage,
    Expression<int>? notificationPostTime,
    Expression<int>? createdAt,
    Expression<String>? dedupKey,
    Expression<String>? status,
    Expression<String>? confidence,
    Expression<String>? notificationKey,
    Expression<String>? categoryId,
    Expression<String>? notes,
    Expression<String>? transactionType,
    Expression<String>? countedAmount,
    Expression<int>? privateToGroups,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (merchant != null) 'merchant': merchant,
      if (rawNotificationText != null)
        'rawNotificationText': rawNotificationText,
      if (sourcePackage != null) 'sourcePackage': sourcePackage,
      if (notificationPostTime != null)
        'notificationPostTime': notificationPostTime,
      if (createdAt != null) 'createdAt': createdAt,
      if (dedupKey != null) 'dedupKey': dedupKey,
      if (status != null) 'status': status,
      if (confidence != null) 'confidence': confidence,
      if (notificationKey != null) 'notificationKey': notificationKey,
      if (categoryId != null) 'categoryId': categoryId,
      if (notes != null) 'notes': notes,
      if (transactionType != null) 'transactionType': transactionType,
      if (countedAmount != null) 'countedAmount': countedAmount,
      if (privateToGroups != null) 'privateToGroups': privateToGroups,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpensesCompanion copyWith({
    Value<String>? id,
    Value<Decimal>? amount,
    Value<String>? currency,
    Value<String?>? merchant,
    Value<String>? rawNotificationText,
    Value<String>? sourcePackage,
    Value<int>? notificationPostTime,
    Value<int>? createdAt,
    Value<String>? dedupKey,
    Value<ExpenseStatus>? status,
    Value<ParseConfidence>? confidence,
    Value<String?>? notificationKey,
    Value<String?>? categoryId,
    Value<String?>? notes,
    Value<TransactionType>? transactionType,
    Value<Decimal?>? countedAmount,
    Value<bool>? privateToGroups,
    Value<int>? rowid,
  }) {
    return ExpensesCompanion(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      merchant: merchant ?? this.merchant,
      rawNotificationText: rawNotificationText ?? this.rawNotificationText,
      sourcePackage: sourcePackage ?? this.sourcePackage,
      notificationPostTime: notificationPostTime ?? this.notificationPostTime,
      createdAt: createdAt ?? this.createdAt,
      dedupKey: dedupKey ?? this.dedupKey,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      notificationKey: notificationKey ?? this.notificationKey,
      categoryId: categoryId ?? this.categoryId,
      notes: notes ?? this.notes,
      transactionType: transactionType ?? this.transactionType,
      countedAmount: countedAmount ?? this.countedAmount,
      privateToGroups: privateToGroups ?? this.privateToGroups,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(
        Expenses.$converteramount.toSql(amount.value),
      );
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (rawNotificationText.present) {
      map['rawNotificationText'] = Variable<String>(rawNotificationText.value);
    }
    if (sourcePackage.present) {
      map['sourcePackage'] = Variable<String>(sourcePackage.value);
    }
    if (notificationPostTime.present) {
      map['notificationPostTime'] = Variable<int>(notificationPostTime.value);
    }
    if (createdAt.present) {
      map['createdAt'] = Variable<int>(createdAt.value);
    }
    if (dedupKey.present) {
      map['dedupKey'] = Variable<String>(dedupKey.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        Expenses.$converterstatus.toSql(status.value),
      );
    }
    if (confidence.present) {
      map['confidence'] = Variable<String>(
        Expenses.$converterconfidence.toSql(confidence.value),
      );
    }
    if (notificationKey.present) {
      map['notificationKey'] = Variable<String>(notificationKey.value);
    }
    if (categoryId.present) {
      map['categoryId'] = Variable<String>(categoryId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (transactionType.present) {
      map['transactionType'] = Variable<String>(
        Expenses.$convertertransactionType.toSql(transactionType.value),
      );
    }
    if (countedAmount.present) {
      map['countedAmount'] = Variable<String>(
        Expenses.$convertercountedAmountn.toSql(countedAmount.value),
      );
    }
    if (privateToGroups.present) {
      map['privateToGroups'] = Variable<int>(
        Expenses.$converterprivateToGroups.toSql(privateToGroups.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensesCompanion(')
          ..write('id: $id, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('merchant: $merchant, ')
          ..write('rawNotificationText: $rawNotificationText, ')
          ..write('sourcePackage: $sourcePackage, ')
          ..write('notificationPostTime: $notificationPostTime, ')
          ..write('createdAt: $createdAt, ')
          ..write('dedupKey: $dedupKey, ')
          ..write('status: $status, ')
          ..write('confidence: $confidence, ')
          ..write('notificationKey: $notificationKey, ')
          ..write('categoryId: $categoryId, ')
          ..write('notes: $notes, ')
          ..write('transactionType: $transactionType, ')
          ..write('countedAmount: $countedAmount, ')
          ..write('privateToGroups: $privateToGroups, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Categories extends Table with TableInfo<Categories, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Categories(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'colorHex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<bool, int> isDefault =
      GeneratedColumn<int>(
        'isDefault',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<bool>(Categories.$converterisDefault);
  @override
  List<GeneratedColumn> get $columns => [id, name, colorHex, isDefault];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('colorHex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['colorHex']!, _colorHexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorHexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}colorHex'],
      )!,
      isDefault: Categories.$converterisDefault.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}isDefault'],
        )!,
      ),
    );
  }

  @override
  Categories createAlias(String alias) {
    return Categories(attachedDatabase, alias);
  }

  static TypeConverter<bool, int> $converterisDefault = const BoolConverter();
  @override
  bool get dontWriteConstraints => true;
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String name;
  final String colorHex;
  final bool isDefault;
  const Category({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['colorHex'] = Variable<String>(colorHex);
    {
      map['isDefault'] = Variable<int>(
        Categories.$converterisDefault.toSql(isDefault),
      );
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      colorHex: Value(colorHex),
      isDefault: Value(isDefault),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorHex': serializer.toJson<String>(colorHex),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? colorHex,
    bool? isDefault,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    colorHex: colorHex ?? this.colorHex,
    isDefault: isDefault ?? this.isDefault,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorHex, isDefault);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorHex == this.colorHex &&
          other.isDefault == this.isDefault);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> colorHex;
  final Value<bool> isDefault;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    required String colorHex,
    required bool isDefault,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       colorHex = Value(colorHex),
       isDefault = Value(isDefault);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? colorHex,
    Expression<int>? isDefault,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorHex != null) 'colorHex': colorHex,
      if (isDefault != null) 'isDefault': isDefault,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? colorHex,
    Value<bool>? isDefault,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      isDefault: isDefault ?? this.isDefault,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorHex.present) {
      map['colorHex'] = Variable<String>(colorHex.value);
    }
    if (isDefault.present) {
      map['isDefault'] = Variable<int>(
        Categories.$converterisDefault.toSql(isDefault.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('isDefault: $isDefault, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class MerchantCategoryMap extends Table
    with TableInfo<MerchantCategoryMap, MerchantCategoryMapData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MerchantCategoryMap(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _merchantKeyMeta = const VerificationMeta(
    'merchantKey',
  );
  late final GeneratedColumn<String> merchantKey = GeneratedColumn<String>(
    'merchantKey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'displayName',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'categoryId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updatedAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    merchantKey,
    displayName,
    categoryId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'merchant_category_map';
  @override
  VerificationContext validateIntegrity(
    Insertable<MerchantCategoryMapData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('merchantKey')) {
      context.handle(
        _merchantKeyMeta,
        merchantKey.isAcceptableOrUnknown(
          data['merchantKey']!,
          _merchantKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_merchantKeyMeta);
    }
    if (data.containsKey('displayName')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['displayName']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('categoryId')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['categoryId']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('updatedAt')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updatedAt']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {merchantKey};
  @override
  MerchantCategoryMapData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MerchantCategoryMapData(
      merchantKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchantKey'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}displayName'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categoryId'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updatedAt'],
      )!,
    );
  }

  @override
  MerchantCategoryMap createAlias(String alias) {
    return MerchantCategoryMap(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class MerchantCategoryMapData extends DataClass
    implements Insertable<MerchantCategoryMapData> {
  final String merchantKey;
  final String displayName;
  final String categoryId;
  final int updatedAt;
  const MerchantCategoryMapData({
    required this.merchantKey,
    required this.displayName,
    required this.categoryId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['merchantKey'] = Variable<String>(merchantKey);
    map['displayName'] = Variable<String>(displayName);
    map['categoryId'] = Variable<String>(categoryId);
    map['updatedAt'] = Variable<int>(updatedAt);
    return map;
  }

  MerchantCategoryMapCompanion toCompanion(bool nullToAbsent) {
    return MerchantCategoryMapCompanion(
      merchantKey: Value(merchantKey),
      displayName: Value(displayName),
      categoryId: Value(categoryId),
      updatedAt: Value(updatedAt),
    );
  }

  factory MerchantCategoryMapData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MerchantCategoryMapData(
      merchantKey: serializer.fromJson<String>(json['merchantKey']),
      displayName: serializer.fromJson<String>(json['displayName']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'merchantKey': serializer.toJson<String>(merchantKey),
      'displayName': serializer.toJson<String>(displayName),
      'categoryId': serializer.toJson<String>(categoryId),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MerchantCategoryMapData copyWith({
    String? merchantKey,
    String? displayName,
    String? categoryId,
    int? updatedAt,
  }) => MerchantCategoryMapData(
    merchantKey: merchantKey ?? this.merchantKey,
    displayName: displayName ?? this.displayName,
    categoryId: categoryId ?? this.categoryId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MerchantCategoryMapData copyWithCompanion(MerchantCategoryMapCompanion data) {
    return MerchantCategoryMapData(
      merchantKey: data.merchantKey.present
          ? data.merchantKey.value
          : this.merchantKey,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MerchantCategoryMapData(')
          ..write('merchantKey: $merchantKey, ')
          ..write('displayName: $displayName, ')
          ..write('categoryId: $categoryId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(merchantKey, displayName, categoryId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MerchantCategoryMapData &&
          other.merchantKey == this.merchantKey &&
          other.displayName == this.displayName &&
          other.categoryId == this.categoryId &&
          other.updatedAt == this.updatedAt);
}

class MerchantCategoryMapCompanion
    extends UpdateCompanion<MerchantCategoryMapData> {
  final Value<String> merchantKey;
  final Value<String> displayName;
  final Value<String> categoryId;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MerchantCategoryMapCompanion({
    this.merchantKey = const Value.absent(),
    this.displayName = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MerchantCategoryMapCompanion.insert({
    required String merchantKey,
    required String displayName,
    required String categoryId,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : merchantKey = Value(merchantKey),
       displayName = Value(displayName),
       categoryId = Value(categoryId),
       updatedAt = Value(updatedAt);
  static Insertable<MerchantCategoryMapData> custom({
    Expression<String>? merchantKey,
    Expression<String>? displayName,
    Expression<String>? categoryId,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (merchantKey != null) 'merchantKey': merchantKey,
      if (displayName != null) 'displayName': displayName,
      if (categoryId != null) 'categoryId': categoryId,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MerchantCategoryMapCompanion copyWith({
    Value<String>? merchantKey,
    Value<String>? displayName,
    Value<String>? categoryId,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return MerchantCategoryMapCompanion(
      merchantKey: merchantKey ?? this.merchantKey,
      displayName: displayName ?? this.displayName,
      categoryId: categoryId ?? this.categoryId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (merchantKey.present) {
      map['merchantKey'] = Variable<String>(merchantKey.value);
    }
    if (displayName.present) {
      map['displayName'] = Variable<String>(displayName.value);
    }
    if (categoryId.present) {
      map['categoryId'] = Variable<String>(categoryId.value);
    }
    if (updatedAt.present) {
      map['updatedAt'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MerchantCategoryMapCompanion(')
          ..write('merchantKey: $merchantKey, ')
          ..write('displayName: $displayName, ')
          ..write('categoryId: $categoryId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PendingPayments extends Table
    with TableInfo<PendingPayments, PendingPayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PendingPayments(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  late final GeneratedColumnWithTypeConverter<Decimal, String> amount =
      GeneratedColumn<String>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<Decimal>(PendingPayments.$converteramount);
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _merchantMeta = const VerificationMeta(
    'merchant',
  );
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
    'merchant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  late final GeneratedColumnWithTypeConverter<TransactionType, String>
  transactionType = GeneratedColumn<String>(
    'transactionType',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  ).withConverter<TransactionType>(PendingPayments.$convertertransactionType);
  static const VerificationMeta _sourcePackageMeta = const VerificationMeta(
    'sourcePackage',
  );
  late final GeneratedColumn<String> sourcePackage = GeneratedColumn<String>(
    'sourcePackage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _rawNotificationTextMeta =
      const VerificationMeta('rawNotificationText');
  late final GeneratedColumn<String> rawNotificationText =
      GeneratedColumn<String>(
        'rawNotificationText',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      );
  static const VerificationMeta _notificationPostTimeMeta =
      const VerificationMeta('notificationPostTime');
  late final GeneratedColumn<int> notificationPostTime = GeneratedColumn<int>(
    'notificationPostTime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _notificationKeyMeta = const VerificationMeta(
    'notificationKey',
  );
  late final GeneratedColumn<String> notificationKey = GeneratedColumn<String>(
    'notificationKey',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dedupKeyMeta = const VerificationMeta(
    'dedupKey',
  );
  late final GeneratedColumn<String> dedupKey = GeneratedColumn<String>(
    'dedupKey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<CaptureFormat, String> format =
      GeneratedColumn<String>(
        'format',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<CaptureFormat>(PendingPayments.$converterformat);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'categoryId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  late final GeneratedColumnWithTypeConverter<bool, int> likelyPromotion =
      GeneratedColumn<int>(
        'likelyPromotion',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<bool>(PendingPayments.$converterlikelyPromotion);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'createdAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<bool, int> edited =
      GeneratedColumn<int>(
        'edited',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<bool>(PendingPayments.$converteredited);
  late final GeneratedColumnWithTypeConverter<bool, int> directionUnclear =
      GeneratedColumn<int>(
        'directionUnclear',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        $customConstraints: 'NOT NULL DEFAULT 0',
        defaultValue: const CustomExpression('0'),
      ).withConverter<bool>(PendingPayments.$converterdirectionUnclear);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    amount,
    currency,
    merchant,
    transactionType,
    sourcePackage,
    rawNotificationText,
    notificationPostTime,
    notificationKey,
    dedupKey,
    format,
    categoryId,
    likelyPromotion,
    createdAt,
    edited,
    directionUnclear,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingPayment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('merchant')) {
      context.handle(
        _merchantMeta,
        merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta),
      );
    }
    if (data.containsKey('sourcePackage')) {
      context.handle(
        _sourcePackageMeta,
        sourcePackage.isAcceptableOrUnknown(
          data['sourcePackage']!,
          _sourcePackageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourcePackageMeta);
    }
    if (data.containsKey('rawNotificationText')) {
      context.handle(
        _rawNotificationTextMeta,
        rawNotificationText.isAcceptableOrUnknown(
          data['rawNotificationText']!,
          _rawNotificationTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rawNotificationTextMeta);
    }
    if (data.containsKey('notificationPostTime')) {
      context.handle(
        _notificationPostTimeMeta,
        notificationPostTime.isAcceptableOrUnknown(
          data['notificationPostTime']!,
          _notificationPostTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_notificationPostTimeMeta);
    }
    if (data.containsKey('notificationKey')) {
      context.handle(
        _notificationKeyMeta,
        notificationKey.isAcceptableOrUnknown(
          data['notificationKey']!,
          _notificationKeyMeta,
        ),
      );
    }
    if (data.containsKey('dedupKey')) {
      context.handle(
        _dedupKeyMeta,
        dedupKey.isAcceptableOrUnknown(data['dedupKey']!, _dedupKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dedupKeyMeta);
    }
    if (data.containsKey('categoryId')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['categoryId']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('createdAt')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['createdAt']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingPayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingPayment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      amount: PendingPayments.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}amount'],
        )!,
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      merchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant'],
      ),
      transactionType: PendingPayments.$convertertransactionType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}transactionType'],
        )!,
      ),
      sourcePackage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sourcePackage'],
      )!,
      rawNotificationText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rawNotificationText'],
      )!,
      notificationPostTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notificationPostTime'],
      )!,
      notificationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notificationKey'],
      ),
      dedupKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupKey'],
      )!,
      format: PendingPayments.$converterformat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}format'],
        )!,
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categoryId'],
      ),
      likelyPromotion: PendingPayments.$converterlikelyPromotion.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}likelyPromotion'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}createdAt'],
      )!,
      edited: PendingPayments.$converteredited.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}edited'],
        )!,
      ),
      directionUnclear: PendingPayments.$converterdirectionUnclear.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}directionUnclear'],
        )!,
      ),
    );
  }

  @override
  PendingPayments createAlias(String alias) {
    return PendingPayments(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converteramount =
      const MoneyConverter();
  static TypeConverter<TransactionType, String> $convertertransactionType =
      const TransactionTypeConverter();
  static TypeConverter<CaptureFormat, String> $converterformat =
      const CaptureFormatConverter();
  static TypeConverter<bool, int> $converterlikelyPromotion =
      const BoolConverter();
  static TypeConverter<bool, int> $converteredited = const BoolConverter();
  static TypeConverter<bool, int> $converterdirectionUnclear =
      const BoolConverter();
  @override
  bool get dontWriteConstraints => true;
}

class PendingPayment extends DataClass implements Insertable<PendingPayment> {
  final String id;
  final Decimal amount;
  final String currency;
  final String? merchant;
  final TransactionType transactionType;
  final String sourcePackage;
  final String rawNotificationText;
  final int notificationPostTime;
  final String? notificationKey;
  final String dedupKey;
  final CaptureFormat format;
  final String? categoryId;
  final bool likelyPromotion;
  final int createdAt;
  final bool edited;
  final bool directionUnclear;
  const PendingPayment({
    required this.id,
    required this.amount,
    required this.currency,
    this.merchant,
    required this.transactionType,
    required this.sourcePackage,
    required this.rawNotificationText,
    required this.notificationPostTime,
    this.notificationKey,
    required this.dedupKey,
    required this.format,
    this.categoryId,
    required this.likelyPromotion,
    required this.createdAt,
    required this.edited,
    required this.directionUnclear,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['amount'] = Variable<String>(
        PendingPayments.$converteramount.toSql(amount),
      );
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || merchant != null) {
      map['merchant'] = Variable<String>(merchant);
    }
    {
      map['transactionType'] = Variable<String>(
        PendingPayments.$convertertransactionType.toSql(transactionType),
      );
    }
    map['sourcePackage'] = Variable<String>(sourcePackage);
    map['rawNotificationText'] = Variable<String>(rawNotificationText);
    map['notificationPostTime'] = Variable<int>(notificationPostTime);
    if (!nullToAbsent || notificationKey != null) {
      map['notificationKey'] = Variable<String>(notificationKey);
    }
    map['dedupKey'] = Variable<String>(dedupKey);
    {
      map['format'] = Variable<String>(
        PendingPayments.$converterformat.toSql(format),
      );
    }
    if (!nullToAbsent || categoryId != null) {
      map['categoryId'] = Variable<String>(categoryId);
    }
    {
      map['likelyPromotion'] = Variable<int>(
        PendingPayments.$converterlikelyPromotion.toSql(likelyPromotion),
      );
    }
    map['createdAt'] = Variable<int>(createdAt);
    {
      map['edited'] = Variable<int>(
        PendingPayments.$converteredited.toSql(edited),
      );
    }
    {
      map['directionUnclear'] = Variable<int>(
        PendingPayments.$converterdirectionUnclear.toSql(directionUnclear),
      );
    }
    return map;
  }

  PendingPaymentsCompanion toCompanion(bool nullToAbsent) {
    return PendingPaymentsCompanion(
      id: Value(id),
      amount: Value(amount),
      currency: Value(currency),
      merchant: merchant == null && nullToAbsent
          ? const Value.absent()
          : Value(merchant),
      transactionType: Value(transactionType),
      sourcePackage: Value(sourcePackage),
      rawNotificationText: Value(rawNotificationText),
      notificationPostTime: Value(notificationPostTime),
      notificationKey: notificationKey == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationKey),
      dedupKey: Value(dedupKey),
      format: Value(format),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      likelyPromotion: Value(likelyPromotion),
      createdAt: Value(createdAt),
      edited: Value(edited),
      directionUnclear: Value(directionUnclear),
    );
  }

  factory PendingPayment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingPayment(
      id: serializer.fromJson<String>(json['id']),
      amount: serializer.fromJson<Decimal>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      merchant: serializer.fromJson<String?>(json['merchant']),
      transactionType: serializer.fromJson<TransactionType>(
        json['transactionType'],
      ),
      sourcePackage: serializer.fromJson<String>(json['sourcePackage']),
      rawNotificationText: serializer.fromJson<String>(
        json['rawNotificationText'],
      ),
      notificationPostTime: serializer.fromJson<int>(
        json['notificationPostTime'],
      ),
      notificationKey: serializer.fromJson<String?>(json['notificationKey']),
      dedupKey: serializer.fromJson<String>(json['dedupKey']),
      format: serializer.fromJson<CaptureFormat>(json['format']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      likelyPromotion: serializer.fromJson<bool>(json['likelyPromotion']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      edited: serializer.fromJson<bool>(json['edited']),
      directionUnclear: serializer.fromJson<bool>(json['directionUnclear']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'amount': serializer.toJson<Decimal>(amount),
      'currency': serializer.toJson<String>(currency),
      'merchant': serializer.toJson<String?>(merchant),
      'transactionType': serializer.toJson<TransactionType>(transactionType),
      'sourcePackage': serializer.toJson<String>(sourcePackage),
      'rawNotificationText': serializer.toJson<String>(rawNotificationText),
      'notificationPostTime': serializer.toJson<int>(notificationPostTime),
      'notificationKey': serializer.toJson<String?>(notificationKey),
      'dedupKey': serializer.toJson<String>(dedupKey),
      'format': serializer.toJson<CaptureFormat>(format),
      'categoryId': serializer.toJson<String?>(categoryId),
      'likelyPromotion': serializer.toJson<bool>(likelyPromotion),
      'createdAt': serializer.toJson<int>(createdAt),
      'edited': serializer.toJson<bool>(edited),
      'directionUnclear': serializer.toJson<bool>(directionUnclear),
    };
  }

  PendingPayment copyWith({
    String? id,
    Decimal? amount,
    String? currency,
    Value<String?> merchant = const Value.absent(),
    TransactionType? transactionType,
    String? sourcePackage,
    String? rawNotificationText,
    int? notificationPostTime,
    Value<String?> notificationKey = const Value.absent(),
    String? dedupKey,
    CaptureFormat? format,
    Value<String?> categoryId = const Value.absent(),
    bool? likelyPromotion,
    int? createdAt,
    bool? edited,
    bool? directionUnclear,
  }) => PendingPayment(
    id: id ?? this.id,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    merchant: merchant.present ? merchant.value : this.merchant,
    transactionType: transactionType ?? this.transactionType,
    sourcePackage: sourcePackage ?? this.sourcePackage,
    rawNotificationText: rawNotificationText ?? this.rawNotificationText,
    notificationPostTime: notificationPostTime ?? this.notificationPostTime,
    notificationKey: notificationKey.present
        ? notificationKey.value
        : this.notificationKey,
    dedupKey: dedupKey ?? this.dedupKey,
    format: format ?? this.format,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    likelyPromotion: likelyPromotion ?? this.likelyPromotion,
    createdAt: createdAt ?? this.createdAt,
    edited: edited ?? this.edited,
    directionUnclear: directionUnclear ?? this.directionUnclear,
  );
  PendingPayment copyWithCompanion(PendingPaymentsCompanion data) {
    return PendingPayment(
      id: data.id.present ? data.id.value : this.id,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      transactionType: data.transactionType.present
          ? data.transactionType.value
          : this.transactionType,
      sourcePackage: data.sourcePackage.present
          ? data.sourcePackage.value
          : this.sourcePackage,
      rawNotificationText: data.rawNotificationText.present
          ? data.rawNotificationText.value
          : this.rawNotificationText,
      notificationPostTime: data.notificationPostTime.present
          ? data.notificationPostTime.value
          : this.notificationPostTime,
      notificationKey: data.notificationKey.present
          ? data.notificationKey.value
          : this.notificationKey,
      dedupKey: data.dedupKey.present ? data.dedupKey.value : this.dedupKey,
      format: data.format.present ? data.format.value : this.format,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      likelyPromotion: data.likelyPromotion.present
          ? data.likelyPromotion.value
          : this.likelyPromotion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      edited: data.edited.present ? data.edited.value : this.edited,
      directionUnclear: data.directionUnclear.present
          ? data.directionUnclear.value
          : this.directionUnclear,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingPayment(')
          ..write('id: $id, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('merchant: $merchant, ')
          ..write('transactionType: $transactionType, ')
          ..write('sourcePackage: $sourcePackage, ')
          ..write('rawNotificationText: $rawNotificationText, ')
          ..write('notificationPostTime: $notificationPostTime, ')
          ..write('notificationKey: $notificationKey, ')
          ..write('dedupKey: $dedupKey, ')
          ..write('format: $format, ')
          ..write('categoryId: $categoryId, ')
          ..write('likelyPromotion: $likelyPromotion, ')
          ..write('createdAt: $createdAt, ')
          ..write('edited: $edited, ')
          ..write('directionUnclear: $directionUnclear')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    amount,
    currency,
    merchant,
    transactionType,
    sourcePackage,
    rawNotificationText,
    notificationPostTime,
    notificationKey,
    dedupKey,
    format,
    categoryId,
    likelyPromotion,
    createdAt,
    edited,
    directionUnclear,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingPayment &&
          other.id == this.id &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.merchant == this.merchant &&
          other.transactionType == this.transactionType &&
          other.sourcePackage == this.sourcePackage &&
          other.rawNotificationText == this.rawNotificationText &&
          other.notificationPostTime == this.notificationPostTime &&
          other.notificationKey == this.notificationKey &&
          other.dedupKey == this.dedupKey &&
          other.format == this.format &&
          other.categoryId == this.categoryId &&
          other.likelyPromotion == this.likelyPromotion &&
          other.createdAt == this.createdAt &&
          other.edited == this.edited &&
          other.directionUnclear == this.directionUnclear);
}

class PendingPaymentsCompanion extends UpdateCompanion<PendingPayment> {
  final Value<String> id;
  final Value<Decimal> amount;
  final Value<String> currency;
  final Value<String?> merchant;
  final Value<TransactionType> transactionType;
  final Value<String> sourcePackage;
  final Value<String> rawNotificationText;
  final Value<int> notificationPostTime;
  final Value<String?> notificationKey;
  final Value<String> dedupKey;
  final Value<CaptureFormat> format;
  final Value<String?> categoryId;
  final Value<bool> likelyPromotion;
  final Value<int> createdAt;
  final Value<bool> edited;
  final Value<bool> directionUnclear;
  final Value<int> rowid;
  const PendingPaymentsCompanion({
    this.id = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.merchant = const Value.absent(),
    this.transactionType = const Value.absent(),
    this.sourcePackage = const Value.absent(),
    this.rawNotificationText = const Value.absent(),
    this.notificationPostTime = const Value.absent(),
    this.notificationKey = const Value.absent(),
    this.dedupKey = const Value.absent(),
    this.format = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.likelyPromotion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.edited = const Value.absent(),
    this.directionUnclear = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingPaymentsCompanion.insert({
    required String id,
    required Decimal amount,
    required String currency,
    this.merchant = const Value.absent(),
    required TransactionType transactionType,
    required String sourcePackage,
    required String rawNotificationText,
    required int notificationPostTime,
    this.notificationKey = const Value.absent(),
    required String dedupKey,
    required CaptureFormat format,
    this.categoryId = const Value.absent(),
    required bool likelyPromotion,
    required int createdAt,
    required bool edited,
    this.directionUnclear = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       amount = Value(amount),
       currency = Value(currency),
       transactionType = Value(transactionType),
       sourcePackage = Value(sourcePackage),
       rawNotificationText = Value(rawNotificationText),
       notificationPostTime = Value(notificationPostTime),
       dedupKey = Value(dedupKey),
       format = Value(format),
       likelyPromotion = Value(likelyPromotion),
       createdAt = Value(createdAt),
       edited = Value(edited);
  static Insertable<PendingPayment> custom({
    Expression<String>? id,
    Expression<String>? amount,
    Expression<String>? currency,
    Expression<String>? merchant,
    Expression<String>? transactionType,
    Expression<String>? sourcePackage,
    Expression<String>? rawNotificationText,
    Expression<int>? notificationPostTime,
    Expression<String>? notificationKey,
    Expression<String>? dedupKey,
    Expression<String>? format,
    Expression<String>? categoryId,
    Expression<int>? likelyPromotion,
    Expression<int>? createdAt,
    Expression<int>? edited,
    Expression<int>? directionUnclear,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (merchant != null) 'merchant': merchant,
      if (transactionType != null) 'transactionType': transactionType,
      if (sourcePackage != null) 'sourcePackage': sourcePackage,
      if (rawNotificationText != null)
        'rawNotificationText': rawNotificationText,
      if (notificationPostTime != null)
        'notificationPostTime': notificationPostTime,
      if (notificationKey != null) 'notificationKey': notificationKey,
      if (dedupKey != null) 'dedupKey': dedupKey,
      if (format != null) 'format': format,
      if (categoryId != null) 'categoryId': categoryId,
      if (likelyPromotion != null) 'likelyPromotion': likelyPromotion,
      if (createdAt != null) 'createdAt': createdAt,
      if (edited != null) 'edited': edited,
      if (directionUnclear != null) 'directionUnclear': directionUnclear,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingPaymentsCompanion copyWith({
    Value<String>? id,
    Value<Decimal>? amount,
    Value<String>? currency,
    Value<String?>? merchant,
    Value<TransactionType>? transactionType,
    Value<String>? sourcePackage,
    Value<String>? rawNotificationText,
    Value<int>? notificationPostTime,
    Value<String?>? notificationKey,
    Value<String>? dedupKey,
    Value<CaptureFormat>? format,
    Value<String?>? categoryId,
    Value<bool>? likelyPromotion,
    Value<int>? createdAt,
    Value<bool>? edited,
    Value<bool>? directionUnclear,
    Value<int>? rowid,
  }) {
    return PendingPaymentsCompanion(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      merchant: merchant ?? this.merchant,
      transactionType: transactionType ?? this.transactionType,
      sourcePackage: sourcePackage ?? this.sourcePackage,
      rawNotificationText: rawNotificationText ?? this.rawNotificationText,
      notificationPostTime: notificationPostTime ?? this.notificationPostTime,
      notificationKey: notificationKey ?? this.notificationKey,
      dedupKey: dedupKey ?? this.dedupKey,
      format: format ?? this.format,
      categoryId: categoryId ?? this.categoryId,
      likelyPromotion: likelyPromotion ?? this.likelyPromotion,
      createdAt: createdAt ?? this.createdAt,
      edited: edited ?? this.edited,
      directionUnclear: directionUnclear ?? this.directionUnclear,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(
        PendingPayments.$converteramount.toSql(amount.value),
      );
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (transactionType.present) {
      map['transactionType'] = Variable<String>(
        PendingPayments.$convertertransactionType.toSql(transactionType.value),
      );
    }
    if (sourcePackage.present) {
      map['sourcePackage'] = Variable<String>(sourcePackage.value);
    }
    if (rawNotificationText.present) {
      map['rawNotificationText'] = Variable<String>(rawNotificationText.value);
    }
    if (notificationPostTime.present) {
      map['notificationPostTime'] = Variable<int>(notificationPostTime.value);
    }
    if (notificationKey.present) {
      map['notificationKey'] = Variable<String>(notificationKey.value);
    }
    if (dedupKey.present) {
      map['dedupKey'] = Variable<String>(dedupKey.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(
        PendingPayments.$converterformat.toSql(format.value),
      );
    }
    if (categoryId.present) {
      map['categoryId'] = Variable<String>(categoryId.value);
    }
    if (likelyPromotion.present) {
      map['likelyPromotion'] = Variable<int>(
        PendingPayments.$converterlikelyPromotion.toSql(likelyPromotion.value),
      );
    }
    if (createdAt.present) {
      map['createdAt'] = Variable<int>(createdAt.value);
    }
    if (edited.present) {
      map['edited'] = Variable<int>(
        PendingPayments.$converteredited.toSql(edited.value),
      );
    }
    if (directionUnclear.present) {
      map['directionUnclear'] = Variable<int>(
        PendingPayments.$converterdirectionUnclear.toSql(
          directionUnclear.value,
        ),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingPaymentsCompanion(')
          ..write('id: $id, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('merchant: $merchant, ')
          ..write('transactionType: $transactionType, ')
          ..write('sourcePackage: $sourcePackage, ')
          ..write('rawNotificationText: $rawNotificationText, ')
          ..write('notificationPostTime: $notificationPostTime, ')
          ..write('notificationKey: $notificationKey, ')
          ..write('dedupKey: $dedupKey, ')
          ..write('format: $format, ')
          ..write('categoryId: $categoryId, ')
          ..write('likelyPromotion: $likelyPromotion, ')
          ..write('createdAt: $createdAt, ')
          ..write('edited: $edited, ')
          ..write('directionUnclear: $directionUnclear, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class DroppedNotifications extends Table
    with TableInfo<DroppedNotifications, DroppedNotification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DroppedNotifications(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dedupKeyMeta = const VerificationMeta(
    'dedupKey',
  );
  late final GeneratedColumn<String> dedupKey = GeneratedColumn<String>(
    'dedupKey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _notificationKeyMeta = const VerificationMeta(
    'notificationKey',
  );
  late final GeneratedColumn<String> notificationKey = GeneratedColumn<String>(
    'notificationKey',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _droppedAtMeta = const VerificationMeta(
    'droppedAt',
  );
  late final GeneratedColumn<int> droppedAt = GeneratedColumn<int>(
    'droppedAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [dedupKey, notificationKey, droppedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dropped_notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<DroppedNotification> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dedupKey')) {
      context.handle(
        _dedupKeyMeta,
        dedupKey.isAcceptableOrUnknown(data['dedupKey']!, _dedupKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dedupKeyMeta);
    }
    if (data.containsKey('notificationKey')) {
      context.handle(
        _notificationKeyMeta,
        notificationKey.isAcceptableOrUnknown(
          data['notificationKey']!,
          _notificationKeyMeta,
        ),
      );
    }
    if (data.containsKey('droppedAt')) {
      context.handle(
        _droppedAtMeta,
        droppedAt.isAcceptableOrUnknown(data['droppedAt']!, _droppedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_droppedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dedupKey};
  @override
  DroppedNotification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DroppedNotification(
      dedupKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupKey'],
      )!,
      notificationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notificationKey'],
      ),
      droppedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}droppedAt'],
      )!,
    );
  }

  @override
  DroppedNotifications createAlias(String alias) {
    return DroppedNotifications(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DroppedNotification extends DataClass
    implements Insertable<DroppedNotification> {
  final String dedupKey;
  final String? notificationKey;
  final int droppedAt;
  const DroppedNotification({
    required this.dedupKey,
    this.notificationKey,
    required this.droppedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dedupKey'] = Variable<String>(dedupKey);
    if (!nullToAbsent || notificationKey != null) {
      map['notificationKey'] = Variable<String>(notificationKey);
    }
    map['droppedAt'] = Variable<int>(droppedAt);
    return map;
  }

  DroppedNotificationsCompanion toCompanion(bool nullToAbsent) {
    return DroppedNotificationsCompanion(
      dedupKey: Value(dedupKey),
      notificationKey: notificationKey == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationKey),
      droppedAt: Value(droppedAt),
    );
  }

  factory DroppedNotification.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DroppedNotification(
      dedupKey: serializer.fromJson<String>(json['dedupKey']),
      notificationKey: serializer.fromJson<String?>(json['notificationKey']),
      droppedAt: serializer.fromJson<int>(json['droppedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dedupKey': serializer.toJson<String>(dedupKey),
      'notificationKey': serializer.toJson<String?>(notificationKey),
      'droppedAt': serializer.toJson<int>(droppedAt),
    };
  }

  DroppedNotification copyWith({
    String? dedupKey,
    Value<String?> notificationKey = const Value.absent(),
    int? droppedAt,
  }) => DroppedNotification(
    dedupKey: dedupKey ?? this.dedupKey,
    notificationKey: notificationKey.present
        ? notificationKey.value
        : this.notificationKey,
    droppedAt: droppedAt ?? this.droppedAt,
  );
  DroppedNotification copyWithCompanion(DroppedNotificationsCompanion data) {
    return DroppedNotification(
      dedupKey: data.dedupKey.present ? data.dedupKey.value : this.dedupKey,
      notificationKey: data.notificationKey.present
          ? data.notificationKey.value
          : this.notificationKey,
      droppedAt: data.droppedAt.present ? data.droppedAt.value : this.droppedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DroppedNotification(')
          ..write('dedupKey: $dedupKey, ')
          ..write('notificationKey: $notificationKey, ')
          ..write('droppedAt: $droppedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dedupKey, notificationKey, droppedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DroppedNotification &&
          other.dedupKey == this.dedupKey &&
          other.notificationKey == this.notificationKey &&
          other.droppedAt == this.droppedAt);
}

class DroppedNotificationsCompanion
    extends UpdateCompanion<DroppedNotification> {
  final Value<String> dedupKey;
  final Value<String?> notificationKey;
  final Value<int> droppedAt;
  final Value<int> rowid;
  const DroppedNotificationsCompanion({
    this.dedupKey = const Value.absent(),
    this.notificationKey = const Value.absent(),
    this.droppedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DroppedNotificationsCompanion.insert({
    required String dedupKey,
    this.notificationKey = const Value.absent(),
    required int droppedAt,
    this.rowid = const Value.absent(),
  }) : dedupKey = Value(dedupKey),
       droppedAt = Value(droppedAt);
  static Insertable<DroppedNotification> custom({
    Expression<String>? dedupKey,
    Expression<String>? notificationKey,
    Expression<int>? droppedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dedupKey != null) 'dedupKey': dedupKey,
      if (notificationKey != null) 'notificationKey': notificationKey,
      if (droppedAt != null) 'droppedAt': droppedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DroppedNotificationsCompanion copyWith({
    Value<String>? dedupKey,
    Value<String?>? notificationKey,
    Value<int>? droppedAt,
    Value<int>? rowid,
  }) {
    return DroppedNotificationsCompanion(
      dedupKey: dedupKey ?? this.dedupKey,
      notificationKey: notificationKey ?? this.notificationKey,
      droppedAt: droppedAt ?? this.droppedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dedupKey.present) {
      map['dedupKey'] = Variable<String>(dedupKey.value);
    }
    if (notificationKey.present) {
      map['notificationKey'] = Variable<String>(notificationKey.value);
    }
    if (droppedAt.present) {
      map['droppedAt'] = Variable<int>(droppedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DroppedNotificationsCompanion(')
          ..write('dedupKey: $dedupKey, ')
          ..write('notificationKey: $notificationKey, ')
          ..write('droppedAt: $droppedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SplitBills extends Table with TableInfo<SplitBills, SplitBill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SplitBills(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _merchantMeta = const VerificationMeta(
    'merchant',
  );
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
    'merchant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _billTimeMeta = const VerificationMeta(
    'billTime',
  );
  late final GeneratedColumn<int> billTime = GeneratedColumn<int>(
    'billTime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<Decimal?, String> printedTotal =
      GeneratedColumn<String>(
        'printedTotal',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      ).withConverter<Decimal?>(SplitBills.$converterprintedTotaln);
  late final GeneratedColumnWithTypeConverter<Decimal, String> serviceCharge =
      GeneratedColumn<String>(
        'serviceCharge',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<Decimal>(SplitBills.$converterserviceCharge);
  late final GeneratedColumnWithTypeConverter<Decimal, String> tax =
      GeneratedColumn<String>(
        'tax',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<Decimal>(SplitBills.$convertertax);
  late final GeneratedColumnWithTypeConverter<Decimal, String> discount =
      GeneratedColumn<String>(
        'discount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<Decimal>(SplitBills.$converterdiscount);
  late final GeneratedColumnWithTypeConverter<Decimal, String> rounding =
      GeneratedColumn<String>(
        'rounding',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<Decimal>(SplitBills.$converterrounding);
  static const VerificationMeta _linkedExpenseIdMeta = const VerificationMeta(
    'linkedExpenseId',
  );
  late final GeneratedColumn<String> linkedExpenseId = GeneratedColumn<String>(
    'linkedExpenseId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'createdAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<bool, int> manual =
      GeneratedColumn<int>(
        'manual',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        $customConstraints: 'NOT NULL DEFAULT 0',
        defaultValue: const CustomExpression('0'),
      ).withConverter<bool>(SplitBills.$convertermanual);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    merchant,
    billTime,
    currency,
    printedTotal,
    serviceCharge,
    tax,
    discount,
    rounding,
    linkedExpenseId,
    createdAt,
    manual,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'split_bills';
  @override
  VerificationContext validateIntegrity(
    Insertable<SplitBill> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('merchant')) {
      context.handle(
        _merchantMeta,
        merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta),
      );
    }
    if (data.containsKey('billTime')) {
      context.handle(
        _billTimeMeta,
        billTime.isAcceptableOrUnknown(data['billTime']!, _billTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_billTimeMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('linkedExpenseId')) {
      context.handle(
        _linkedExpenseIdMeta,
        linkedExpenseId.isAcceptableOrUnknown(
          data['linkedExpenseId']!,
          _linkedExpenseIdMeta,
        ),
      );
    }
    if (data.containsKey('createdAt')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['createdAt']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SplitBill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SplitBill(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      merchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant'],
      ),
      billTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}billTime'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      printedTotal: SplitBills.$converterprintedTotaln.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}printedTotal'],
        ),
      ),
      serviceCharge: SplitBills.$converterserviceCharge.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}serviceCharge'],
        )!,
      ),
      tax: SplitBills.$convertertax.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tax'],
        )!,
      ),
      discount: SplitBills.$converterdiscount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}discount'],
        )!,
      ),
      rounding: SplitBills.$converterrounding.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}rounding'],
        )!,
      ),
      linkedExpenseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linkedExpenseId'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}createdAt'],
      )!,
      manual: SplitBills.$convertermanual.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}manual'],
        )!,
      ),
    );
  }

  @override
  SplitBills createAlias(String alias) {
    return SplitBills(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converterprintedTotal =
      const MoneyConverter();
  static TypeConverter<Decimal?, String?> $converterprintedTotaln =
      NullAwareTypeConverter.wrap($converterprintedTotal);
  static TypeConverter<Decimal, String> $converterserviceCharge =
      const MoneyConverter();
  static TypeConverter<Decimal, String> $convertertax = const MoneyConverter();
  static TypeConverter<Decimal, String> $converterdiscount =
      const MoneyConverter();
  static TypeConverter<Decimal, String> $converterrounding =
      const MoneyConverter();
  static TypeConverter<bool, int> $convertermanual = const BoolConverter();
  @override
  bool get dontWriteConstraints => true;
}

class SplitBill extends DataClass implements Insertable<SplitBill> {
  final String id;
  final String? merchant;
  final int billTime;
  final String currency;
  final Decimal? printedTotal;
  final Decimal serviceCharge;
  final Decimal tax;
  final Decimal discount;
  final Decimal rounding;
  final String? linkedExpenseId;
  final int createdAt;
  final bool manual;
  const SplitBill({
    required this.id,
    this.merchant,
    required this.billTime,
    required this.currency,
    this.printedTotal,
    required this.serviceCharge,
    required this.tax,
    required this.discount,
    required this.rounding,
    this.linkedExpenseId,
    required this.createdAt,
    required this.manual,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || merchant != null) {
      map['merchant'] = Variable<String>(merchant);
    }
    map['billTime'] = Variable<int>(billTime);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || printedTotal != null) {
      map['printedTotal'] = Variable<String>(
        SplitBills.$converterprintedTotaln.toSql(printedTotal),
      );
    }
    {
      map['serviceCharge'] = Variable<String>(
        SplitBills.$converterserviceCharge.toSql(serviceCharge),
      );
    }
    {
      map['tax'] = Variable<String>(SplitBills.$convertertax.toSql(tax));
    }
    {
      map['discount'] = Variable<String>(
        SplitBills.$converterdiscount.toSql(discount),
      );
    }
    {
      map['rounding'] = Variable<String>(
        SplitBills.$converterrounding.toSql(rounding),
      );
    }
    if (!nullToAbsent || linkedExpenseId != null) {
      map['linkedExpenseId'] = Variable<String>(linkedExpenseId);
    }
    map['createdAt'] = Variable<int>(createdAt);
    {
      map['manual'] = Variable<int>(SplitBills.$convertermanual.toSql(manual));
    }
    return map;
  }

  SplitBillsCompanion toCompanion(bool nullToAbsent) {
    return SplitBillsCompanion(
      id: Value(id),
      merchant: merchant == null && nullToAbsent
          ? const Value.absent()
          : Value(merchant),
      billTime: Value(billTime),
      currency: Value(currency),
      printedTotal: printedTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(printedTotal),
      serviceCharge: Value(serviceCharge),
      tax: Value(tax),
      discount: Value(discount),
      rounding: Value(rounding),
      linkedExpenseId: linkedExpenseId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedExpenseId),
      createdAt: Value(createdAt),
      manual: Value(manual),
    );
  }

  factory SplitBill.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SplitBill(
      id: serializer.fromJson<String>(json['id']),
      merchant: serializer.fromJson<String?>(json['merchant']),
      billTime: serializer.fromJson<int>(json['billTime']),
      currency: serializer.fromJson<String>(json['currency']),
      printedTotal: serializer.fromJson<Decimal?>(json['printedTotal']),
      serviceCharge: serializer.fromJson<Decimal>(json['serviceCharge']),
      tax: serializer.fromJson<Decimal>(json['tax']),
      discount: serializer.fromJson<Decimal>(json['discount']),
      rounding: serializer.fromJson<Decimal>(json['rounding']),
      linkedExpenseId: serializer.fromJson<String?>(json['linkedExpenseId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      manual: serializer.fromJson<bool>(json['manual']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'merchant': serializer.toJson<String?>(merchant),
      'billTime': serializer.toJson<int>(billTime),
      'currency': serializer.toJson<String>(currency),
      'printedTotal': serializer.toJson<Decimal?>(printedTotal),
      'serviceCharge': serializer.toJson<Decimal>(serviceCharge),
      'tax': serializer.toJson<Decimal>(tax),
      'discount': serializer.toJson<Decimal>(discount),
      'rounding': serializer.toJson<Decimal>(rounding),
      'linkedExpenseId': serializer.toJson<String?>(linkedExpenseId),
      'createdAt': serializer.toJson<int>(createdAt),
      'manual': serializer.toJson<bool>(manual),
    };
  }

  SplitBill copyWith({
    String? id,
    Value<String?> merchant = const Value.absent(),
    int? billTime,
    String? currency,
    Value<Decimal?> printedTotal = const Value.absent(),
    Decimal? serviceCharge,
    Decimal? tax,
    Decimal? discount,
    Decimal? rounding,
    Value<String?> linkedExpenseId = const Value.absent(),
    int? createdAt,
    bool? manual,
  }) => SplitBill(
    id: id ?? this.id,
    merchant: merchant.present ? merchant.value : this.merchant,
    billTime: billTime ?? this.billTime,
    currency: currency ?? this.currency,
    printedTotal: printedTotal.present ? printedTotal.value : this.printedTotal,
    serviceCharge: serviceCharge ?? this.serviceCharge,
    tax: tax ?? this.tax,
    discount: discount ?? this.discount,
    rounding: rounding ?? this.rounding,
    linkedExpenseId: linkedExpenseId.present
        ? linkedExpenseId.value
        : this.linkedExpenseId,
    createdAt: createdAt ?? this.createdAt,
    manual: manual ?? this.manual,
  );
  SplitBill copyWithCompanion(SplitBillsCompanion data) {
    return SplitBill(
      id: data.id.present ? data.id.value : this.id,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      billTime: data.billTime.present ? data.billTime.value : this.billTime,
      currency: data.currency.present ? data.currency.value : this.currency,
      printedTotal: data.printedTotal.present
          ? data.printedTotal.value
          : this.printedTotal,
      serviceCharge: data.serviceCharge.present
          ? data.serviceCharge.value
          : this.serviceCharge,
      tax: data.tax.present ? data.tax.value : this.tax,
      discount: data.discount.present ? data.discount.value : this.discount,
      rounding: data.rounding.present ? data.rounding.value : this.rounding,
      linkedExpenseId: data.linkedExpenseId.present
          ? data.linkedExpenseId.value
          : this.linkedExpenseId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      manual: data.manual.present ? data.manual.value : this.manual,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SplitBill(')
          ..write('id: $id, ')
          ..write('merchant: $merchant, ')
          ..write('billTime: $billTime, ')
          ..write('currency: $currency, ')
          ..write('printedTotal: $printedTotal, ')
          ..write('serviceCharge: $serviceCharge, ')
          ..write('tax: $tax, ')
          ..write('discount: $discount, ')
          ..write('rounding: $rounding, ')
          ..write('linkedExpenseId: $linkedExpenseId, ')
          ..write('createdAt: $createdAt, ')
          ..write('manual: $manual')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    merchant,
    billTime,
    currency,
    printedTotal,
    serviceCharge,
    tax,
    discount,
    rounding,
    linkedExpenseId,
    createdAt,
    manual,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SplitBill &&
          other.id == this.id &&
          other.merchant == this.merchant &&
          other.billTime == this.billTime &&
          other.currency == this.currency &&
          other.printedTotal == this.printedTotal &&
          other.serviceCharge == this.serviceCharge &&
          other.tax == this.tax &&
          other.discount == this.discount &&
          other.rounding == this.rounding &&
          other.linkedExpenseId == this.linkedExpenseId &&
          other.createdAt == this.createdAt &&
          other.manual == this.manual);
}

class SplitBillsCompanion extends UpdateCompanion<SplitBill> {
  final Value<String> id;
  final Value<String?> merchant;
  final Value<int> billTime;
  final Value<String> currency;
  final Value<Decimal?> printedTotal;
  final Value<Decimal> serviceCharge;
  final Value<Decimal> tax;
  final Value<Decimal> discount;
  final Value<Decimal> rounding;
  final Value<String?> linkedExpenseId;
  final Value<int> createdAt;
  final Value<bool> manual;
  final Value<int> rowid;
  const SplitBillsCompanion({
    this.id = const Value.absent(),
    this.merchant = const Value.absent(),
    this.billTime = const Value.absent(),
    this.currency = const Value.absent(),
    this.printedTotal = const Value.absent(),
    this.serviceCharge = const Value.absent(),
    this.tax = const Value.absent(),
    this.discount = const Value.absent(),
    this.rounding = const Value.absent(),
    this.linkedExpenseId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.manual = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SplitBillsCompanion.insert({
    required String id,
    this.merchant = const Value.absent(),
    required int billTime,
    required String currency,
    this.printedTotal = const Value.absent(),
    required Decimal serviceCharge,
    required Decimal tax,
    required Decimal discount,
    required Decimal rounding,
    this.linkedExpenseId = const Value.absent(),
    required int createdAt,
    this.manual = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       billTime = Value(billTime),
       currency = Value(currency),
       serviceCharge = Value(serviceCharge),
       tax = Value(tax),
       discount = Value(discount),
       rounding = Value(rounding),
       createdAt = Value(createdAt);
  static Insertable<SplitBill> custom({
    Expression<String>? id,
    Expression<String>? merchant,
    Expression<int>? billTime,
    Expression<String>? currency,
    Expression<String>? printedTotal,
    Expression<String>? serviceCharge,
    Expression<String>? tax,
    Expression<String>? discount,
    Expression<String>? rounding,
    Expression<String>? linkedExpenseId,
    Expression<int>? createdAt,
    Expression<int>? manual,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (merchant != null) 'merchant': merchant,
      if (billTime != null) 'billTime': billTime,
      if (currency != null) 'currency': currency,
      if (printedTotal != null) 'printedTotal': printedTotal,
      if (serviceCharge != null) 'serviceCharge': serviceCharge,
      if (tax != null) 'tax': tax,
      if (discount != null) 'discount': discount,
      if (rounding != null) 'rounding': rounding,
      if (linkedExpenseId != null) 'linkedExpenseId': linkedExpenseId,
      if (createdAt != null) 'createdAt': createdAt,
      if (manual != null) 'manual': manual,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SplitBillsCompanion copyWith({
    Value<String>? id,
    Value<String?>? merchant,
    Value<int>? billTime,
    Value<String>? currency,
    Value<Decimal?>? printedTotal,
    Value<Decimal>? serviceCharge,
    Value<Decimal>? tax,
    Value<Decimal>? discount,
    Value<Decimal>? rounding,
    Value<String?>? linkedExpenseId,
    Value<int>? createdAt,
    Value<bool>? manual,
    Value<int>? rowid,
  }) {
    return SplitBillsCompanion(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      billTime: billTime ?? this.billTime,
      currency: currency ?? this.currency,
      printedTotal: printedTotal ?? this.printedTotal,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      rounding: rounding ?? this.rounding,
      linkedExpenseId: linkedExpenseId ?? this.linkedExpenseId,
      createdAt: createdAt ?? this.createdAt,
      manual: manual ?? this.manual,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (billTime.present) {
      map['billTime'] = Variable<int>(billTime.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (printedTotal.present) {
      map['printedTotal'] = Variable<String>(
        SplitBills.$converterprintedTotaln.toSql(printedTotal.value),
      );
    }
    if (serviceCharge.present) {
      map['serviceCharge'] = Variable<String>(
        SplitBills.$converterserviceCharge.toSql(serviceCharge.value),
      );
    }
    if (tax.present) {
      map['tax'] = Variable<String>(SplitBills.$convertertax.toSql(tax.value));
    }
    if (discount.present) {
      map['discount'] = Variable<String>(
        SplitBills.$converterdiscount.toSql(discount.value),
      );
    }
    if (rounding.present) {
      map['rounding'] = Variable<String>(
        SplitBills.$converterrounding.toSql(rounding.value),
      );
    }
    if (linkedExpenseId.present) {
      map['linkedExpenseId'] = Variable<String>(linkedExpenseId.value);
    }
    if (createdAt.present) {
      map['createdAt'] = Variable<int>(createdAt.value);
    }
    if (manual.present) {
      map['manual'] = Variable<int>(
        SplitBills.$convertermanual.toSql(manual.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SplitBillsCompanion(')
          ..write('id: $id, ')
          ..write('merchant: $merchant, ')
          ..write('billTime: $billTime, ')
          ..write('currency: $currency, ')
          ..write('printedTotal: $printedTotal, ')
          ..write('serviceCharge: $serviceCharge, ')
          ..write('tax: $tax, ')
          ..write('discount: $discount, ')
          ..write('rounding: $rounding, ')
          ..write('linkedExpenseId: $linkedExpenseId, ')
          ..write('createdAt: $createdAt, ')
          ..write('manual: $manual, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SplitItems extends Table with TableInfo<SplitItems, SplitItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SplitItems(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _billIdMeta = const VerificationMeta('billId');
  late final GeneratedColumn<String> billId = GeneratedColumn<String>(
    'billId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<Decimal, String> price =
      GeneratedColumn<String>(
        'price',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<Decimal>(SplitItems.$converterprice);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    billId,
    name,
    quantity,
    price,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'split_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SplitItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('billId')) {
      context.handle(
        _billIdMeta,
        billId.isAcceptableOrUnknown(data['billId']!, _billIdMeta),
      );
    } else if (isInserting) {
      context.missing(_billIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SplitItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SplitItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      billId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}billId'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      price: SplitItems.$converterprice.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}price'],
        )!,
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  SplitItems createAlias(String alias) {
    return SplitItems(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converterprice =
      const MoneyConverter();
  @override
  bool get dontWriteConstraints => true;
}

class SplitItem extends DataClass implements Insertable<SplitItem> {
  final String id;
  final String billId;
  final String name;
  final int quantity;
  final Decimal price;
  final int position;
  const SplitItem({
    required this.id,
    required this.billId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['billId'] = Variable<String>(billId);
    map['name'] = Variable<String>(name);
    map['quantity'] = Variable<int>(quantity);
    {
      map['price'] = Variable<String>(SplitItems.$converterprice.toSql(price));
    }
    map['position'] = Variable<int>(position);
    return map;
  }

  SplitItemsCompanion toCompanion(bool nullToAbsent) {
    return SplitItemsCompanion(
      id: Value(id),
      billId: Value(billId),
      name: Value(name),
      quantity: Value(quantity),
      price: Value(price),
      position: Value(position),
    );
  }

  factory SplitItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SplitItem(
      id: serializer.fromJson<String>(json['id']),
      billId: serializer.fromJson<String>(json['billId']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<int>(json['quantity']),
      price: serializer.fromJson<Decimal>(json['price']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'billId': serializer.toJson<String>(billId),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<int>(quantity),
      'price': serializer.toJson<Decimal>(price),
      'position': serializer.toJson<int>(position),
    };
  }

  SplitItem copyWith({
    String? id,
    String? billId,
    String? name,
    int? quantity,
    Decimal? price,
    int? position,
  }) => SplitItem(
    id: id ?? this.id,
    billId: billId ?? this.billId,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    price: price ?? this.price,
    position: position ?? this.position,
  );
  SplitItem copyWithCompanion(SplitItemsCompanion data) {
    return SplitItem(
      id: data.id.present ? data.id.value : this.id,
      billId: data.billId.present ? data.billId.value : this.billId,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      price: data.price.present ? data.price.value : this.price,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SplitItem(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, billId, name, quantity, price, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SplitItem &&
          other.id == this.id &&
          other.billId == this.billId &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.price == this.price &&
          other.position == this.position);
}

class SplitItemsCompanion extends UpdateCompanion<SplitItem> {
  final Value<String> id;
  final Value<String> billId;
  final Value<String> name;
  final Value<int> quantity;
  final Value<Decimal> price;
  final Value<int> position;
  final Value<int> rowid;
  const SplitItemsCompanion({
    this.id = const Value.absent(),
    this.billId = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.price = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SplitItemsCompanion.insert({
    required String id,
    required String billId,
    required String name,
    required int quantity,
    required Decimal price,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       billId = Value(billId),
       name = Value(name),
       quantity = Value(quantity),
       price = Value(price),
       position = Value(position);
  static Insertable<SplitItem> custom({
    Expression<String>? id,
    Expression<String>? billId,
    Expression<String>? name,
    Expression<int>? quantity,
    Expression<String>? price,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (billId != null) 'billId': billId,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (price != null) 'price': price,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SplitItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? billId,
    Value<String>? name,
    Value<int>? quantity,
    Value<Decimal>? price,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return SplitItemsCompanion(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (billId.present) {
      map['billId'] = Variable<String>(billId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (price.present) {
      map['price'] = Variable<String>(
        SplitItems.$converterprice.toSql(price.value),
      );
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SplitItemsCompanion(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SplitPeople extends Table with TableInfo<SplitPeople, SplitPeopleData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SplitPeople(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  late final GeneratedColumn<int> lastUsedAt = GeneratedColumn<int>(
    'lastUsedAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _qrPathMeta = const VerificationMeta('qrPath');
  late final GeneratedColumn<String> qrPath = GeneratedColumn<String>(
    'qrPath',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  late final GeneratedColumnWithTypeConverter<bool, int> archived =
      GeneratedColumn<int>(
        'archived',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        $customConstraints: 'NOT NULL DEFAULT 0',
        defaultValue: const CustomExpression('0'),
      ).withConverter<bool>(SplitPeople.$converterarchived);
  static const VerificationMeta _suggestedSettleExpenseIdMeta =
      const VerificationMeta('suggestedSettleExpenseId');
  late final GeneratedColumn<String> suggestedSettleExpenseId =
      GeneratedColumn<String>(
        'suggestedSettleExpenseId',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    lastUsedAt,
    qrPath,
    archived,
    suggestedSettleExpenseId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'split_people';
  @override
  VerificationContext validateIntegrity(
    Insertable<SplitPeopleData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('lastUsedAt')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(data['lastUsedAt']!, _lastUsedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_lastUsedAtMeta);
    }
    if (data.containsKey('qrPath')) {
      context.handle(
        _qrPathMeta,
        qrPath.isAcceptableOrUnknown(data['qrPath']!, _qrPathMeta),
      );
    }
    if (data.containsKey('suggestedSettleExpenseId')) {
      context.handle(
        _suggestedSettleExpenseIdMeta,
        suggestedSettleExpenseId.isAcceptableOrUnknown(
          data['suggestedSettleExpenseId']!,
          _suggestedSettleExpenseIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SplitPeopleData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SplitPeopleData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lastUsedAt'],
      )!,
      qrPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qrPath'],
      ),
      archived: SplitPeople.$converterarchived.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}archived'],
        )!,
      ),
      suggestedSettleExpenseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggestedSettleExpenseId'],
      ),
    );
  }

  @override
  SplitPeople createAlias(String alias) {
    return SplitPeople(attachedDatabase, alias);
  }

  static TypeConverter<bool, int> $converterarchived = const BoolConverter();
  @override
  bool get dontWriteConstraints => true;
}

class SplitPeopleData extends DataClass implements Insertable<SplitPeopleData> {
  final String id;
  final String name;
  final int lastUsedAt;
  final String? qrPath;
  final bool archived;
  final String? suggestedSettleExpenseId;
  const SplitPeopleData({
    required this.id,
    required this.name,
    required this.lastUsedAt,
    this.qrPath,
    required this.archived,
    this.suggestedSettleExpenseId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['lastUsedAt'] = Variable<int>(lastUsedAt);
    if (!nullToAbsent || qrPath != null) {
      map['qrPath'] = Variable<String>(qrPath);
    }
    {
      map['archived'] = Variable<int>(
        SplitPeople.$converterarchived.toSql(archived),
      );
    }
    if (!nullToAbsent || suggestedSettleExpenseId != null) {
      map['suggestedSettleExpenseId'] = Variable<String>(
        suggestedSettleExpenseId,
      );
    }
    return map;
  }

  SplitPeopleCompanion toCompanion(bool nullToAbsent) {
    return SplitPeopleCompanion(
      id: Value(id),
      name: Value(name),
      lastUsedAt: Value(lastUsedAt),
      qrPath: qrPath == null && nullToAbsent
          ? const Value.absent()
          : Value(qrPath),
      archived: Value(archived),
      suggestedSettleExpenseId: suggestedSettleExpenseId == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedSettleExpenseId),
    );
  }

  factory SplitPeopleData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SplitPeopleData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      lastUsedAt: serializer.fromJson<int>(json['lastUsedAt']),
      qrPath: serializer.fromJson<String?>(json['qrPath']),
      archived: serializer.fromJson<bool>(json['archived']),
      suggestedSettleExpenseId: serializer.fromJson<String?>(
        json['suggestedSettleExpenseId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'lastUsedAt': serializer.toJson<int>(lastUsedAt),
      'qrPath': serializer.toJson<String?>(qrPath),
      'archived': serializer.toJson<bool>(archived),
      'suggestedSettleExpenseId': serializer.toJson<String?>(
        suggestedSettleExpenseId,
      ),
    };
  }

  SplitPeopleData copyWith({
    String? id,
    String? name,
    int? lastUsedAt,
    Value<String?> qrPath = const Value.absent(),
    bool? archived,
    Value<String?> suggestedSettleExpenseId = const Value.absent(),
  }) => SplitPeopleData(
    id: id ?? this.id,
    name: name ?? this.name,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    qrPath: qrPath.present ? qrPath.value : this.qrPath,
    archived: archived ?? this.archived,
    suggestedSettleExpenseId: suggestedSettleExpenseId.present
        ? suggestedSettleExpenseId.value
        : this.suggestedSettleExpenseId,
  );
  SplitPeopleData copyWithCompanion(SplitPeopleCompanion data) {
    return SplitPeopleData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
      qrPath: data.qrPath.present ? data.qrPath.value : this.qrPath,
      archived: data.archived.present ? data.archived.value : this.archived,
      suggestedSettleExpenseId: data.suggestedSettleExpenseId.present
          ? data.suggestedSettleExpenseId.value
          : this.suggestedSettleExpenseId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SplitPeopleData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('qrPath: $qrPath, ')
          ..write('archived: $archived, ')
          ..write('suggestedSettleExpenseId: $suggestedSettleExpenseId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    lastUsedAt,
    qrPath,
    archived,
    suggestedSettleExpenseId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SplitPeopleData &&
          other.id == this.id &&
          other.name == this.name &&
          other.lastUsedAt == this.lastUsedAt &&
          other.qrPath == this.qrPath &&
          other.archived == this.archived &&
          other.suggestedSettleExpenseId == this.suggestedSettleExpenseId);
}

class SplitPeopleCompanion extends UpdateCompanion<SplitPeopleData> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> lastUsedAt;
  final Value<String?> qrPath;
  final Value<bool> archived;
  final Value<String?> suggestedSettleExpenseId;
  final Value<int> rowid;
  const SplitPeopleCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.qrPath = const Value.absent(),
    this.archived = const Value.absent(),
    this.suggestedSettleExpenseId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SplitPeopleCompanion.insert({
    required String id,
    required String name,
    required int lastUsedAt,
    this.qrPath = const Value.absent(),
    this.archived = const Value.absent(),
    this.suggestedSettleExpenseId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       lastUsedAt = Value(lastUsedAt);
  static Insertable<SplitPeopleData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? lastUsedAt,
    Expression<String>? qrPath,
    Expression<int>? archived,
    Expression<String>? suggestedSettleExpenseId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (lastUsedAt != null) 'lastUsedAt': lastUsedAt,
      if (qrPath != null) 'qrPath': qrPath,
      if (archived != null) 'archived': archived,
      if (suggestedSettleExpenseId != null)
        'suggestedSettleExpenseId': suggestedSettleExpenseId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SplitPeopleCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? lastUsedAt,
    Value<String?>? qrPath,
    Value<bool>? archived,
    Value<String?>? suggestedSettleExpenseId,
    Value<int>? rowid,
  }) {
    return SplitPeopleCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      qrPath: qrPath ?? this.qrPath,
      archived: archived ?? this.archived,
      suggestedSettleExpenseId:
          suggestedSettleExpenseId ?? this.suggestedSettleExpenseId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lastUsedAt.present) {
      map['lastUsedAt'] = Variable<int>(lastUsedAt.value);
    }
    if (qrPath.present) {
      map['qrPath'] = Variable<String>(qrPath.value);
    }
    if (archived.present) {
      map['archived'] = Variable<int>(
        SplitPeople.$converterarchived.toSql(archived.value),
      );
    }
    if (suggestedSettleExpenseId.present) {
      map['suggestedSettleExpenseId'] = Variable<String>(
        suggestedSettleExpenseId.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SplitPeopleCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('qrPath: $qrPath, ')
          ..write('archived: $archived, ')
          ..write('suggestedSettleExpenseId: $suggestedSettleExpenseId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SplitItemShares extends Table
    with TableInfo<SplitItemShares, SplitItemShare> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SplitItemShares(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'itemId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'personId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, personId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'split_item_shares';
  @override
  VerificationContext validateIntegrity(
    Insertable<SplitItemShare> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('itemId')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['itemId']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('personId')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['personId']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId, personId};
  @override
  SplitItemShare map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SplitItemShare(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}itemId'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}personId'],
      )!,
    );
  }

  @override
  SplitItemShares createAlias(String alias) {
    return SplitItemShares(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(itemId, personId)'];
  @override
  bool get dontWriteConstraints => true;
}

class SplitItemShare extends DataClass implements Insertable<SplitItemShare> {
  final String itemId;
  final String personId;
  const SplitItemShare({required this.itemId, required this.personId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['itemId'] = Variable<String>(itemId);
    map['personId'] = Variable<String>(personId);
    return map;
  }

  SplitItemSharesCompanion toCompanion(bool nullToAbsent) {
    return SplitItemSharesCompanion(
      itemId: Value(itemId),
      personId: Value(personId),
    );
  }

  factory SplitItemShare.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SplitItemShare(
      itemId: serializer.fromJson<String>(json['itemId']),
      personId: serializer.fromJson<String>(json['personId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'personId': serializer.toJson<String>(personId),
    };
  }

  SplitItemShare copyWith({String? itemId, String? personId}) => SplitItemShare(
    itemId: itemId ?? this.itemId,
    personId: personId ?? this.personId,
  );
  SplitItemShare copyWithCompanion(SplitItemSharesCompanion data) {
    return SplitItemShare(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      personId: data.personId.present ? data.personId.value : this.personId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SplitItemShare(')
          ..write('itemId: $itemId, ')
          ..write('personId: $personId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, personId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SplitItemShare &&
          other.itemId == this.itemId &&
          other.personId == this.personId);
}

class SplitItemSharesCompanion extends UpdateCompanion<SplitItemShare> {
  final Value<String> itemId;
  final Value<String> personId;
  final Value<int> rowid;
  const SplitItemSharesCompanion({
    this.itemId = const Value.absent(),
    this.personId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SplitItemSharesCompanion.insert({
    required String itemId,
    required String personId,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       personId = Value(personId);
  static Insertable<SplitItemShare> custom({
    Expression<String>? itemId,
    Expression<String>? personId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'itemId': itemId,
      if (personId != null) 'personId': personId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SplitItemSharesCompanion copyWith({
    Value<String>? itemId,
    Value<String>? personId,
    Value<int>? rowid,
  }) {
    return SplitItemSharesCompanion(
      itemId: itemId ?? this.itemId,
      personId: personId ?? this.personId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['itemId'] = Variable<String>(itemId.value);
    }
    if (personId.present) {
      map['personId'] = Variable<String>(personId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SplitItemSharesCompanion(')
          ..write('itemId: $itemId, ')
          ..write('personId: $personId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SplitDebts extends Table with TableInfo<SplitDebts, SplitDebt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SplitDebts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _billIdMeta = const VerificationMeta('billId');
  late final GeneratedColumn<String> billId = GeneratedColumn<String>(
    'billId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'personId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<Decimal, String> amount =
      GeneratedColumn<String>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<Decimal>(SplitDebts.$converteramount);
  late final GeneratedColumnWithTypeConverter<DebtStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DebtStatus>(SplitDebts.$converterstatus);
  static const VerificationMeta _repaymentExpenseIdMeta =
      const VerificationMeta('repaymentExpenseId');
  late final GeneratedColumn<String> repaymentExpenseId =
      GeneratedColumn<String>(
        'repaymentExpenseId',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _suggestedRepaymentExpenseIdMeta =
      const VerificationMeta('suggestedRepaymentExpenseId');
  late final GeneratedColumn<String> suggestedRepaymentExpenseId =
      GeneratedColumn<String>(
        'suggestedRepaymentExpenseId',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  late final GeneratedColumn<int> paidAt = GeneratedColumn<int>(
    'paidAt',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    billId,
    personId,
    amount,
    status,
    repaymentExpenseId,
    suggestedRepaymentExpenseId,
    paidAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'split_debts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SplitDebt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('billId')) {
      context.handle(
        _billIdMeta,
        billId.isAcceptableOrUnknown(data['billId']!, _billIdMeta),
      );
    } else if (isInserting) {
      context.missing(_billIdMeta);
    }
    if (data.containsKey('personId')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['personId']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('repaymentExpenseId')) {
      context.handle(
        _repaymentExpenseIdMeta,
        repaymentExpenseId.isAcceptableOrUnknown(
          data['repaymentExpenseId']!,
          _repaymentExpenseIdMeta,
        ),
      );
    }
    if (data.containsKey('suggestedRepaymentExpenseId')) {
      context.handle(
        _suggestedRepaymentExpenseIdMeta,
        suggestedRepaymentExpenseId.isAcceptableOrUnknown(
          data['suggestedRepaymentExpenseId']!,
          _suggestedRepaymentExpenseIdMeta,
        ),
      );
    }
    if (data.containsKey('paidAt')) {
      context.handle(
        _paidAtMeta,
        paidAt.isAcceptableOrUnknown(data['paidAt']!, _paidAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SplitDebt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SplitDebt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      billId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}billId'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}personId'],
      )!,
      amount: SplitDebts.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}amount'],
        )!,
      ),
      status: SplitDebts.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      repaymentExpenseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repaymentExpenseId'],
      ),
      suggestedRepaymentExpenseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggestedRepaymentExpenseId'],
      ),
      paidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paidAt'],
      ),
    );
  }

  @override
  SplitDebts createAlias(String alias) {
    return SplitDebts(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converteramount =
      const MoneyConverter();
  static TypeConverter<DebtStatus, String> $converterstatus =
      const DebtStatusConverter();
  @override
  bool get dontWriteConstraints => true;
}

class SplitDebt extends DataClass implements Insertable<SplitDebt> {
  final String id;
  final String billId;
  final String personId;
  final Decimal amount;
  final DebtStatus status;
  final String? repaymentExpenseId;
  final String? suggestedRepaymentExpenseId;
  final int? paidAt;
  const SplitDebt({
    required this.id,
    required this.billId,
    required this.personId,
    required this.amount,
    required this.status,
    this.repaymentExpenseId,
    this.suggestedRepaymentExpenseId,
    this.paidAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['billId'] = Variable<String>(billId);
    map['personId'] = Variable<String>(personId);
    {
      map['amount'] = Variable<String>(
        SplitDebts.$converteramount.toSql(amount),
      );
    }
    {
      map['status'] = Variable<String>(
        SplitDebts.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || repaymentExpenseId != null) {
      map['repaymentExpenseId'] = Variable<String>(repaymentExpenseId);
    }
    if (!nullToAbsent || suggestedRepaymentExpenseId != null) {
      map['suggestedRepaymentExpenseId'] = Variable<String>(
        suggestedRepaymentExpenseId,
      );
    }
    if (!nullToAbsent || paidAt != null) {
      map['paidAt'] = Variable<int>(paidAt);
    }
    return map;
  }

  SplitDebtsCompanion toCompanion(bool nullToAbsent) {
    return SplitDebtsCompanion(
      id: Value(id),
      billId: Value(billId),
      personId: Value(personId),
      amount: Value(amount),
      status: Value(status),
      repaymentExpenseId: repaymentExpenseId == null && nullToAbsent
          ? const Value.absent()
          : Value(repaymentExpenseId),
      suggestedRepaymentExpenseId:
          suggestedRepaymentExpenseId == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedRepaymentExpenseId),
      paidAt: paidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(paidAt),
    );
  }

  factory SplitDebt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SplitDebt(
      id: serializer.fromJson<String>(json['id']),
      billId: serializer.fromJson<String>(json['billId']),
      personId: serializer.fromJson<String>(json['personId']),
      amount: serializer.fromJson<Decimal>(json['amount']),
      status: serializer.fromJson<DebtStatus>(json['status']),
      repaymentExpenseId: serializer.fromJson<String?>(
        json['repaymentExpenseId'],
      ),
      suggestedRepaymentExpenseId: serializer.fromJson<String?>(
        json['suggestedRepaymentExpenseId'],
      ),
      paidAt: serializer.fromJson<int?>(json['paidAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'billId': serializer.toJson<String>(billId),
      'personId': serializer.toJson<String>(personId),
      'amount': serializer.toJson<Decimal>(amount),
      'status': serializer.toJson<DebtStatus>(status),
      'repaymentExpenseId': serializer.toJson<String?>(repaymentExpenseId),
      'suggestedRepaymentExpenseId': serializer.toJson<String?>(
        suggestedRepaymentExpenseId,
      ),
      'paidAt': serializer.toJson<int?>(paidAt),
    };
  }

  SplitDebt copyWith({
    String? id,
    String? billId,
    String? personId,
    Decimal? amount,
    DebtStatus? status,
    Value<String?> repaymentExpenseId = const Value.absent(),
    Value<String?> suggestedRepaymentExpenseId = const Value.absent(),
    Value<int?> paidAt = const Value.absent(),
  }) => SplitDebt(
    id: id ?? this.id,
    billId: billId ?? this.billId,
    personId: personId ?? this.personId,
    amount: amount ?? this.amount,
    status: status ?? this.status,
    repaymentExpenseId: repaymentExpenseId.present
        ? repaymentExpenseId.value
        : this.repaymentExpenseId,
    suggestedRepaymentExpenseId: suggestedRepaymentExpenseId.present
        ? suggestedRepaymentExpenseId.value
        : this.suggestedRepaymentExpenseId,
    paidAt: paidAt.present ? paidAt.value : this.paidAt,
  );
  SplitDebt copyWithCompanion(SplitDebtsCompanion data) {
    return SplitDebt(
      id: data.id.present ? data.id.value : this.id,
      billId: data.billId.present ? data.billId.value : this.billId,
      personId: data.personId.present ? data.personId.value : this.personId,
      amount: data.amount.present ? data.amount.value : this.amount,
      status: data.status.present ? data.status.value : this.status,
      repaymentExpenseId: data.repaymentExpenseId.present
          ? data.repaymentExpenseId.value
          : this.repaymentExpenseId,
      suggestedRepaymentExpenseId: data.suggestedRepaymentExpenseId.present
          ? data.suggestedRepaymentExpenseId.value
          : this.suggestedRepaymentExpenseId,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SplitDebt(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('personId: $personId, ')
          ..write('amount: $amount, ')
          ..write('status: $status, ')
          ..write('repaymentExpenseId: $repaymentExpenseId, ')
          ..write('suggestedRepaymentExpenseId: $suggestedRepaymentExpenseId, ')
          ..write('paidAt: $paidAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    billId,
    personId,
    amount,
    status,
    repaymentExpenseId,
    suggestedRepaymentExpenseId,
    paidAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SplitDebt &&
          other.id == this.id &&
          other.billId == this.billId &&
          other.personId == this.personId &&
          other.amount == this.amount &&
          other.status == this.status &&
          other.repaymentExpenseId == this.repaymentExpenseId &&
          other.suggestedRepaymentExpenseId ==
              this.suggestedRepaymentExpenseId &&
          other.paidAt == this.paidAt);
}

class SplitDebtsCompanion extends UpdateCompanion<SplitDebt> {
  final Value<String> id;
  final Value<String> billId;
  final Value<String> personId;
  final Value<Decimal> amount;
  final Value<DebtStatus> status;
  final Value<String?> repaymentExpenseId;
  final Value<String?> suggestedRepaymentExpenseId;
  final Value<int?> paidAt;
  final Value<int> rowid;
  const SplitDebtsCompanion({
    this.id = const Value.absent(),
    this.billId = const Value.absent(),
    this.personId = const Value.absent(),
    this.amount = const Value.absent(),
    this.status = const Value.absent(),
    this.repaymentExpenseId = const Value.absent(),
    this.suggestedRepaymentExpenseId = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SplitDebtsCompanion.insert({
    required String id,
    required String billId,
    required String personId,
    required Decimal amount,
    required DebtStatus status,
    this.repaymentExpenseId = const Value.absent(),
    this.suggestedRepaymentExpenseId = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       billId = Value(billId),
       personId = Value(personId),
       amount = Value(amount),
       status = Value(status);
  static Insertable<SplitDebt> custom({
    Expression<String>? id,
    Expression<String>? billId,
    Expression<String>? personId,
    Expression<String>? amount,
    Expression<String>? status,
    Expression<String>? repaymentExpenseId,
    Expression<String>? suggestedRepaymentExpenseId,
    Expression<int>? paidAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (billId != null) 'billId': billId,
      if (personId != null) 'personId': personId,
      if (amount != null) 'amount': amount,
      if (status != null) 'status': status,
      if (repaymentExpenseId != null) 'repaymentExpenseId': repaymentExpenseId,
      if (suggestedRepaymentExpenseId != null)
        'suggestedRepaymentExpenseId': suggestedRepaymentExpenseId,
      if (paidAt != null) 'paidAt': paidAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SplitDebtsCompanion copyWith({
    Value<String>? id,
    Value<String>? billId,
    Value<String>? personId,
    Value<Decimal>? amount,
    Value<DebtStatus>? status,
    Value<String?>? repaymentExpenseId,
    Value<String?>? suggestedRepaymentExpenseId,
    Value<int?>? paidAt,
    Value<int>? rowid,
  }) {
    return SplitDebtsCompanion(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      personId: personId ?? this.personId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      repaymentExpenseId: repaymentExpenseId ?? this.repaymentExpenseId,
      suggestedRepaymentExpenseId:
          suggestedRepaymentExpenseId ?? this.suggestedRepaymentExpenseId,
      paidAt: paidAt ?? this.paidAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (billId.present) {
      map['billId'] = Variable<String>(billId.value);
    }
    if (personId.present) {
      map['personId'] = Variable<String>(personId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(
        SplitDebts.$converteramount.toSql(amount.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        SplitDebts.$converterstatus.toSql(status.value),
      );
    }
    if (repaymentExpenseId.present) {
      map['repaymentExpenseId'] = Variable<String>(repaymentExpenseId.value);
    }
    if (suggestedRepaymentExpenseId.present) {
      map['suggestedRepaymentExpenseId'] = Variable<String>(
        suggestedRepaymentExpenseId.value,
      );
    }
    if (paidAt.present) {
      map['paidAt'] = Variable<int>(paidAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SplitDebtsCompanion(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('personId: $personId, ')
          ..write('amount: $amount, ')
          ..write('status: $status, ')
          ..write('repaymentExpenseId: $repaymentExpenseId, ')
          ..write('suggestedRepaymentExpenseId: $suggestedRepaymentExpenseId, ')
          ..write('paidAt: $paidAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class OwedItems extends Table with TableInfo<OwedItems, OwedItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  OwedItems(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'personId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<Decimal, String> amount =
      GeneratedColumn<String>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<Decimal>(OwedItems.$converteramount);
  static const VerificationMeta _itemDateMeta = const VerificationMeta(
    'itemDate',
  );
  late final GeneratedColumn<int> itemDate = GeneratedColumn<int>(
    'itemDate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'createdAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<DebtStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DebtStatus>(OwedItems.$converterstatus);
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  late final GeneratedColumn<int> paidAt = GeneratedColumn<int>(
    'paidAt',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    personId,
    description,
    amount,
    itemDate,
    createdAt,
    status,
    paidAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'owed_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<OwedItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('personId')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['personId']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('itemDate')) {
      context.handle(
        _itemDateMeta,
        itemDate.isAcceptableOrUnknown(data['itemDate']!, _itemDateMeta),
      );
    } else if (isInserting) {
      context.missing(_itemDateMeta);
    }
    if (data.containsKey('createdAt')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['createdAt']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('paidAt')) {
      context.handle(
        _paidAtMeta,
        paidAt.isAcceptableOrUnknown(data['paidAt']!, _paidAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OwedItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OwedItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}personId'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      amount: OwedItems.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}amount'],
        )!,
      ),
      itemDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}itemDate'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}createdAt'],
      )!,
      status: OwedItems.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      paidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paidAt'],
      ),
    );
  }

  @override
  OwedItems createAlias(String alias) {
    return OwedItems(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converteramount =
      const MoneyConverter();
  static TypeConverter<DebtStatus, String> $converterstatus =
      const DebtStatusConverter();
  @override
  bool get dontWriteConstraints => true;
}

class OwedItem extends DataClass implements Insertable<OwedItem> {
  final String id;
  final String personId;
  final String description;
  final Decimal amount;
  final int itemDate;
  final int createdAt;
  final DebtStatus status;
  final int? paidAt;
  const OwedItem({
    required this.id,
    required this.personId,
    required this.description,
    required this.amount,
    required this.itemDate,
    required this.createdAt,
    required this.status,
    this.paidAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['personId'] = Variable<String>(personId);
    map['description'] = Variable<String>(description);
    {
      map['amount'] = Variable<String>(
        OwedItems.$converteramount.toSql(amount),
      );
    }
    map['itemDate'] = Variable<int>(itemDate);
    map['createdAt'] = Variable<int>(createdAt);
    {
      map['status'] = Variable<String>(
        OwedItems.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || paidAt != null) {
      map['paidAt'] = Variable<int>(paidAt);
    }
    return map;
  }

  OwedItemsCompanion toCompanion(bool nullToAbsent) {
    return OwedItemsCompanion(
      id: Value(id),
      personId: Value(personId),
      description: Value(description),
      amount: Value(amount),
      itemDate: Value(itemDate),
      createdAt: Value(createdAt),
      status: Value(status),
      paidAt: paidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(paidAt),
    );
  }

  factory OwedItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OwedItem(
      id: serializer.fromJson<String>(json['id']),
      personId: serializer.fromJson<String>(json['personId']),
      description: serializer.fromJson<String>(json['description']),
      amount: serializer.fromJson<Decimal>(json['amount']),
      itemDate: serializer.fromJson<int>(json['itemDate']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      status: serializer.fromJson<DebtStatus>(json['status']),
      paidAt: serializer.fromJson<int?>(json['paidAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'personId': serializer.toJson<String>(personId),
      'description': serializer.toJson<String>(description),
      'amount': serializer.toJson<Decimal>(amount),
      'itemDate': serializer.toJson<int>(itemDate),
      'createdAt': serializer.toJson<int>(createdAt),
      'status': serializer.toJson<DebtStatus>(status),
      'paidAt': serializer.toJson<int?>(paidAt),
    };
  }

  OwedItem copyWith({
    String? id,
    String? personId,
    String? description,
    Decimal? amount,
    int? itemDate,
    int? createdAt,
    DebtStatus? status,
    Value<int?> paidAt = const Value.absent(),
  }) => OwedItem(
    id: id ?? this.id,
    personId: personId ?? this.personId,
    description: description ?? this.description,
    amount: amount ?? this.amount,
    itemDate: itemDate ?? this.itemDate,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
    paidAt: paidAt.present ? paidAt.value : this.paidAt,
  );
  OwedItem copyWithCompanion(OwedItemsCompanion data) {
    return OwedItem(
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      description: data.description.present
          ? data.description.value
          : this.description,
      amount: data.amount.present ? data.amount.value : this.amount,
      itemDate: data.itemDate.present ? data.itemDate.value : this.itemDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OwedItem(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('itemDate: $itemDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('paidAt: $paidAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    personId,
    description,
    amount,
    itemDate,
    createdAt,
    status,
    paidAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OwedItem &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.description == this.description &&
          other.amount == this.amount &&
          other.itemDate == this.itemDate &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.paidAt == this.paidAt);
}

class OwedItemsCompanion extends UpdateCompanion<OwedItem> {
  final Value<String> id;
  final Value<String> personId;
  final Value<String> description;
  final Value<Decimal> amount;
  final Value<int> itemDate;
  final Value<int> createdAt;
  final Value<DebtStatus> status;
  final Value<int?> paidAt;
  final Value<int> rowid;
  const OwedItemsCompanion({
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.description = const Value.absent(),
    this.amount = const Value.absent(),
    this.itemDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OwedItemsCompanion.insert({
    required String id,
    required String personId,
    required String description,
    required Decimal amount,
    required int itemDate,
    required int createdAt,
    required DebtStatus status,
    this.paidAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       personId = Value(personId),
       description = Value(description),
       amount = Value(amount),
       itemDate = Value(itemDate),
       createdAt = Value(createdAt),
       status = Value(status);
  static Insertable<OwedItem> custom({
    Expression<String>? id,
    Expression<String>? personId,
    Expression<String>? description,
    Expression<String>? amount,
    Expression<int>? itemDate,
    Expression<int>? createdAt,
    Expression<String>? status,
    Expression<int>? paidAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personId != null) 'personId': personId,
      if (description != null) 'description': description,
      if (amount != null) 'amount': amount,
      if (itemDate != null) 'itemDate': itemDate,
      if (createdAt != null) 'createdAt': createdAt,
      if (status != null) 'status': status,
      if (paidAt != null) 'paidAt': paidAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OwedItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? personId,
    Value<String>? description,
    Value<Decimal>? amount,
    Value<int>? itemDate,
    Value<int>? createdAt,
    Value<DebtStatus>? status,
    Value<int?>? paidAt,
    Value<int>? rowid,
  }) {
    return OwedItemsCompanion(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      itemDate: itemDate ?? this.itemDate,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (personId.present) {
      map['personId'] = Variable<String>(personId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(
        OwedItems.$converteramount.toSql(amount.value),
      );
    }
    if (itemDate.present) {
      map['itemDate'] = Variable<int>(itemDate.value);
    }
    if (createdAt.present) {
      map['createdAt'] = Variable<int>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        OwedItems.$converterstatus.toSql(status.value),
      );
    }
    if (paidAt.present) {
      map['paidAt'] = Variable<int>(paidAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OwedItemsCompanion(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('itemDate: $itemDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('paidAt: $paidAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$KobanDatabase extends GeneratedDatabase {
  _$KobanDatabase(QueryExecutor e) : super(e);
  $KobanDatabaseManager get managers => $KobanDatabaseManager(this);
  late final Expenses expenses = Expenses(this);
  late final Categories categories = Categories(this);
  late final MerchantCategoryMap merchantCategoryMap = MerchantCategoryMap(
    this,
  );
  late final PendingPayments pendingPayments = PendingPayments(this);
  late final DroppedNotifications droppedNotifications = DroppedNotifications(
    this,
  );
  late final SplitBills splitBills = SplitBills(this);
  late final SplitItems splitItems = SplitItems(this);
  late final SplitPeople splitPeople = SplitPeople(this);
  late final SplitItemShares splitItemShares = SplitItemShares(this);
  late final SplitDebts splitDebts = SplitDebts(this);
  late final OwedItems owedItems = OwedItems(this);
  late final Index indexExpensesDedupKey = Index(
    'index_expenses_dedupKey',
    'CREATE UNIQUE INDEX index_expenses_dedupKey ON expenses (dedupKey)',
  );
  late final Index indexOwedItemsPersonId = Index(
    'index_owed_items_personId',
    'CREATE INDEX index_owed_items_personId ON owed_items (personId)',
  );
  late final Index indexPendingPaymentsNotificationKey = Index(
    'index_pending_payments_notificationKey',
    'CREATE INDEX index_pending_payments_notificationKey ON pending_payments (notificationKey)',
  );
  late final Index indexSplitDebtsBillId = Index(
    'index_split_debts_billId',
    'CREATE INDEX index_split_debts_billId ON split_debts (billId)',
  );
  late final Index indexSplitDebtsPersonId = Index(
    'index_split_debts_personId',
    'CREATE INDEX index_split_debts_personId ON split_debts (personId)',
  );
  late final Index indexSplitItemSharesPersonId = Index(
    'index_split_item_shares_personId',
    'CREATE INDEX index_split_item_shares_personId ON split_item_shares (personId)',
  );
  late final Index indexSplitItemsBillId = Index(
    'index_split_items_billId',
    'CREATE INDEX index_split_items_billId ON split_items (billId)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    expenses,
    categories,
    merchantCategoryMap,
    pendingPayments,
    droppedNotifications,
    splitBills,
    splitItems,
    splitPeople,
    splitItemShares,
    splitDebts,
    owedItems,
    indexExpensesDedupKey,
    indexOwedItemsPersonId,
    indexPendingPaymentsNotificationKey,
    indexSplitDebtsBillId,
    indexSplitDebtsPersonId,
    indexSplitItemSharesPersonId,
    indexSplitItemsBillId,
  ];
}

typedef $ExpensesCreateCompanionBuilder = ExpensesCompanion Function({
  required String id,
  required Decimal amount,
  required String currency,
  Value<String?> merchant,
  required String rawNotificationText,
  required String sourcePackage,
  required int notificationPostTime,
  required int createdAt,
  required String dedupKey,
  required ExpenseStatus status,
  required ParseConfidence confidence,
  Value<String?> notificationKey,
  Value<String?> categoryId,
  Value<String?> notes,
  required TransactionType transactionType,
  Value<Decimal?> countedAmount,
  required bool privateToGroups,
  Value<int> rowid,
});
typedef $ExpensesUpdateCompanionBuilder = ExpensesCompanion Function({
  Value<String> id,
  Value<Decimal> amount,
  Value<String> currency,
  Value<String?> merchant,
  Value<String> rawNotificationText,
  Value<String> sourcePackage,
  Value<int> notificationPostTime,
  Value<int> createdAt,
  Value<String> dedupKey,
  Value<ExpenseStatus> status,
  Value<ParseConfidence> confidence,
  Value<String?> notificationKey,
  Value<String?> categoryId,
  Value<String?> notes,
  Value<TransactionType> transactionType,
  Value<Decimal?> countedAmount,
  Value<bool> privateToGroups,
  Value<int> rowid,
});

class $ExpensesFilterComposer extends Composer<_$KobanDatabase, Expenses> {
  $ExpensesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawNotificationText => $composableBuilder(
    column: $table.rawNotificationText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePackage => $composableBuilder(
    column: $table.sourcePackage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationPostTime => $composableBuilder(
    column: $table.notificationPostTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupKey => $composableBuilder(
    column: $table.dedupKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ExpenseStatus, ExpenseStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<ParseConfidence, ParseConfidence, String>
  get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get notificationKey => $composableBuilder(
    column: $table.notificationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TransactionType, TransactionType, String>
  get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal?, Decimal, String> get countedAmount =>
      $composableBuilder(
        column: $table.countedAmount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<bool, bool, int> get privateToGroups =>
      $composableBuilder(
        column: $table.privateToGroups,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $ExpensesOrderingComposer extends Composer<_$KobanDatabase, Expenses> {
  $ExpensesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawNotificationText => $composableBuilder(
    column: $table.rawNotificationText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePackage => $composableBuilder(
    column: $table.sourcePackage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationPostTime => $composableBuilder(
    column: $table.notificationPostTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupKey => $composableBuilder(
    column: $table.dedupKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notificationKey => $composableBuilder(
    column: $table.notificationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get countedAmount => $composableBuilder(
    column: $table.countedAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get privateToGroups => $composableBuilder(
    column: $table.privateToGroups,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ExpensesAnnotationComposer extends Composer<_$KobanDatabase, Expenses> {
  $ExpensesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<String> get rawNotificationText => $composableBuilder(
    column: $table.rawNotificationText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourcePackage => $composableBuilder(
    column: $table.sourcePackage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationPostTime => $composableBuilder(
    column: $table.notificationPostTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get dedupKey =>
      $composableBuilder(column: $table.dedupKey, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ExpenseStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ParseConfidence, String> get confidence =>
      $composableBuilder(
        column: $table.confidence,
        builder: (column) => column,
      );

  GeneratedColumn<String> get notificationKey => $composableBuilder(
    column: $table.notificationKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TransactionType, String>
  get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Decimal?, String> get countedAmount =>
      $composableBuilder(
        column: $table.countedAmount,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<bool, int> get privateToGroups =>
      $composableBuilder(
        column: $table.privateToGroups,
        builder: (column) => column,
      );
}

class $ExpensesTableManager
    extends
        RootTableManager<
          _$KobanDatabase,
          Expenses,
          Expense,
          $ExpensesFilterComposer,
          $ExpensesOrderingComposer,
          $ExpensesAnnotationComposer,
          $ExpensesCreateCompanionBuilder,
          $ExpensesUpdateCompanionBuilder,
          (Expense, BaseReferences<_$KobanDatabase, Expenses, Expense>),
          Expense,
          PrefetchHooks Function()
        > {
  $ExpensesTableManager(_$KobanDatabase db, Expenses table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ExpensesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ExpensesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ExpensesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<Decimal> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                Value<String> rawNotificationText = const Value.absent(),
                Value<String> sourcePackage = const Value.absent(),
                Value<int> notificationPostTime = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> dedupKey = const Value.absent(),
                Value<ExpenseStatus> status = const Value.absent(),
                Value<ParseConfidence> confidence = const Value.absent(),
                Value<String?> notificationKey = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<TransactionType> transactionType = const Value.absent(),
                Value<Decimal?> countedAmount = const Value.absent(),
                Value<bool> privateToGroups = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion(
                id: id,
                amount: amount,
                currency: currency,
                merchant: merchant,
                rawNotificationText: rawNotificationText,
                sourcePackage: sourcePackage,
                notificationPostTime: notificationPostTime,
                createdAt: createdAt,
                dedupKey: dedupKey,
                status: status,
                confidence: confidence,
                notificationKey: notificationKey,
                categoryId: categoryId,
                notes: notes,
                transactionType: transactionType,
                countedAmount: countedAmount,
                privateToGroups: privateToGroups,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required Decimal amount,
                required String currency,
                Value<String?> merchant = const Value.absent(),
                required String rawNotificationText,
                required String sourcePackage,
                required int notificationPostTime,
                required int createdAt,
                required String dedupKey,
                required ExpenseStatus status,
                required ParseConfidence confidence,
                Value<String?> notificationKey = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required TransactionType transactionType,
                Value<Decimal?> countedAmount = const Value.absent(),
                required bool privateToGroups,
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion.insert(
                id: id,
                amount: amount,
                currency: currency,
                merchant: merchant,
                rawNotificationText: rawNotificationText,
                sourcePackage: sourcePackage,
                notificationPostTime: notificationPostTime,
                createdAt: createdAt,
                dedupKey: dedupKey,
                status: status,
                confidence: confidence,
                notificationKey: notificationKey,
                categoryId: categoryId,
                notes: notes,
                transactionType: transactionType,
                countedAmount: countedAmount,
                privateToGroups: privateToGroups,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Expenses, Expense>(table),
                  BaseReferences<_$KobanDatabase, Expenses, Expense>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ExpensesProcessedTableManager =
    ProcessedTableManager<
      _$KobanDatabase,
      Expenses,
      Expense,
      $ExpensesFilterComposer,
      $ExpensesOrderingComposer,
      $ExpensesAnnotationComposer,
      $ExpensesCreateCompanionBuilder,
      $ExpensesUpdateCompanionBuilder,
      (Expense, BaseReferences<_$KobanDatabase, Expenses, Expense>),
      Expense,
      PrefetchHooks Function()
    >;
typedef $CategoriesCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required String name,
  required String colorHex,
  required bool isDefault,
  Value<int> rowid,
});
typedef $CategoriesUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> colorHex,
  Value<bool> isDefault,
  Value<int> rowid,
});

class $CategoriesFilterComposer extends Composer<_$KobanDatabase, Categories> {
  $CategoriesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<bool, bool, int> get isDefault =>
      $composableBuilder(
        column: $table.isDefault,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $CategoriesOrderingComposer
    extends Composer<_$KobanDatabase, Categories> {
  $CategoriesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );
}

class $CategoriesAnnotationComposer
    extends Composer<_$KobanDatabase, Categories> {
  $CategoriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumnWithTypeConverter<bool, int> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);
}

class $CategoriesTableManager
    extends
        RootTableManager<
          _$KobanDatabase,
          Categories,
          Category,
          $CategoriesFilterComposer,
          $CategoriesOrderingComposer,
          $CategoriesAnnotationComposer,
          $CategoriesCreateCompanionBuilder,
          $CategoriesUpdateCompanionBuilder,
          (Category, BaseReferences<_$KobanDatabase, Categories, Category>),
          Category,
          PrefetchHooks Function()
        > {
  $CategoriesTableManager(_$KobanDatabase db, Categories table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CategoriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CategoriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CategoriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                colorHex: colorHex,
                isDefault: isDefault,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String colorHex,
                required bool isDefault,
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                colorHex: colorHex,
                isDefault: isDefault,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Categories, Category>(table),
                  BaseReferences<_$KobanDatabase, Categories, Category>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $CategoriesProcessedTableManager =
    ProcessedTableManager<
      _$KobanDatabase,
      Categories,
      Category,
      $CategoriesFilterComposer,
      $CategoriesOrderingComposer,
      $CategoriesAnnotationComposer,
      $CategoriesCreateCompanionBuilder,
      $CategoriesUpdateCompanionBuilder,
      (Category, BaseReferences<_$KobanDatabase, Categories, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $MerchantCategoryMapCreateCompanionBuilder =
    MerchantCategoryMapCompanion Function({
      required String merchantKey,
      required String displayName,
      required String categoryId,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $MerchantCategoryMapUpdateCompanionBuilder =
    MerchantCategoryMapCompanion Function({
      Value<String> merchantKey,
      Value<String> displayName,
      Value<String> categoryId,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $MerchantCategoryMapFilterComposer
    extends Composer<_$KobanDatabase, MerchantCategoryMap> {
  $MerchantCategoryMapFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get merchantKey => $composableBuilder(
    column: $table.merchantKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $MerchantCategoryMapOrderingComposer
    extends Composer<_$KobanDatabase, MerchantCategoryMap> {
  $MerchantCategoryMapOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get merchantKey => $composableBuilder(
    column: $table.merchantKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $MerchantCategoryMapAnnotationComposer
    extends Composer<_$KobanDatabase, MerchantCategoryMap> {
  $MerchantCategoryMapAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get merchantKey => $composableBuilder(
    column: $table.merchantKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $MerchantCategoryMapTableManager
    extends
        RootTableManager<
          _$KobanDatabase,
          MerchantCategoryMap,
          MerchantCategoryMapData,
          $MerchantCategoryMapFilterComposer,
          $MerchantCategoryMapOrderingComposer,
          $MerchantCategoryMapAnnotationComposer,
          $MerchantCategoryMapCreateCompanionBuilder,
          $MerchantCategoryMapUpdateCompanionBuilder,
          (
            MerchantCategoryMapData,
            BaseReferences<
              _$KobanDatabase,
              MerchantCategoryMap,
              MerchantCategoryMapData
            >,
          ),
          MerchantCategoryMapData,
          PrefetchHooks Function()
        > {
  $MerchantCategoryMapTableManager(
    _$KobanDatabase db,
    MerchantCategoryMap table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MerchantCategoryMapFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MerchantCategoryMapOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MerchantCategoryMapAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> merchantKey = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MerchantCategoryMapCompanion(
                merchantKey: merchantKey,
                displayName: displayName,
                categoryId: categoryId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String merchantKey,
                required String displayName,
                required String categoryId,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MerchantCategoryMapCompanion.insert(
                merchantKey: merchantKey,
                displayName: displayName,
                categoryId: categoryId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<MerchantCategoryMap, MerchantCategoryMapData>(
                    table,
                  ),
                  BaseReferences<
                    _$KobanDatabase,
                    MerchantCategoryMap,
                    MerchantCategoryMapData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $MerchantCategoryMapProcessedTableManager =
    ProcessedTableManager<
      _$KobanDatabase,
      MerchantCategoryMap,
      MerchantCategoryMapData,
      $MerchantCategoryMapFilterComposer,
      $MerchantCategoryMapOrderingComposer,
      $MerchantCategoryMapAnnotationComposer,
      $MerchantCategoryMapCreateCompanionBuilder,
      $MerchantCategoryMapUpdateCompanionBuilder,
      (
        MerchantCategoryMapData,
        BaseReferences<
          _$KobanDatabase,
          MerchantCategoryMap,
          MerchantCategoryMapData
        >,
      ),
      MerchantCategoryMapData,
      PrefetchHooks Function()
    >;
typedef $PendingPaymentsCreateCompanionBuilder =
    PendingPaymentsCompanion Function({
      required String id,
      required Decimal amount,
      required String currency,
      Value<String?> merchant,
      required TransactionType transactionType,
      required String sourcePackage,
      required String rawNotificationText,
      required int notificationPostTime,
      Value<String?> notificationKey,
      required String dedupKey,
      required CaptureFormat format,
      Value<String?> categoryId,
      required bool likelyPromotion,
      required int createdAt,
      required bool edited,
      Value<bool> directionUnclear,
      Value<int> rowid,
    });
typedef $PendingPaymentsUpdateCompanionBuilder =
    PendingPaymentsCompanion Function({
      Value<String> id,
      Value<Decimal> amount,
      Value<String> currency,
      Value<String?> merchant,
      Value<TransactionType> transactionType,
      Value<String> sourcePackage,
      Value<String> rawNotificationText,
      Value<int> notificationPostTime,
      Value<String?> notificationKey,
      Value<String> dedupKey,
      Value<CaptureFormat> format,
      Value<String?> categoryId,
      Value<bool> likelyPromotion,
      Value<int> createdAt,
      Value<bool> edited,
      Value<bool> directionUnclear,
      Value<int> rowid,
    });

class $PendingPaymentsFilterComposer
    extends Composer<_$KobanDatabase, PendingPayments> {
  $PendingPaymentsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TransactionType, TransactionType, String>
  get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get sourcePackage => $composableBuilder(
    column: $table.sourcePackage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawNotificationText => $composableBuilder(
    column: $table.rawNotificationText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationPostTime => $composableBuilder(
    column: $table.notificationPostTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notificationKey => $composableBuilder(
    column: $table.notificationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupKey => $composableBuilder(
    column: $table.dedupKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CaptureFormat, CaptureFormat, String>
  get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<bool, bool, int> get likelyPromotion =>
      $composableBuilder(
        column: $table.likelyPromotion,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<bool, bool, int> get edited =>
      $composableBuilder(
        column: $table.edited,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<bool, bool, int> get directionUnclear =>
      $composableBuilder(
        column: $table.directionUnclear,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $PendingPaymentsOrderingComposer
    extends Composer<_$KobanDatabase, PendingPayments> {
  $PendingPaymentsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePackage => $composableBuilder(
    column: $table.sourcePackage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawNotificationText => $composableBuilder(
    column: $table.rawNotificationText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationPostTime => $composableBuilder(
    column: $table.notificationPostTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notificationKey => $composableBuilder(
    column: $table.notificationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupKey => $composableBuilder(
    column: $table.dedupKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likelyPromotion => $composableBuilder(
    column: $table.likelyPromotion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get directionUnclear => $composableBuilder(
    column: $table.directionUnclear,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PendingPaymentsAnnotationComposer
    extends Composer<_$KobanDatabase, PendingPayments> {
  $PendingPaymentsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TransactionType, String>
  get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourcePackage => $composableBuilder(
    column: $table.sourcePackage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawNotificationText => $composableBuilder(
    column: $table.rawNotificationText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationPostTime => $composableBuilder(
    column: $table.notificationPostTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notificationKey => $composableBuilder(
    column: $table.notificationKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dedupKey =>
      $composableBuilder(column: $table.dedupKey, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CaptureFormat, String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<bool, int> get likelyPromotion =>
      $composableBuilder(
        column: $table.likelyPromotion,
        builder: (column) => column,
      );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<bool, int> get edited =>
      $composableBuilder(column: $table.edited, builder: (column) => column);

  GeneratedColumnWithTypeConverter<bool, int> get directionUnclear =>
      $composableBuilder(
        column: $table.directionUnclear,
        builder: (column) => column,
      );
}

class $PendingPaymentsTableManager
    extends
        RootTableManager<
          _$KobanDatabase,
          PendingPayments,
          PendingPayment,
          $PendingPaymentsFilterComposer,
          $PendingPaymentsOrderingComposer,
          $PendingPaymentsAnnotationComposer,
          $PendingPaymentsCreateCompanionBuilder,
          $PendingPaymentsUpdateCompanionBuilder,
          (
            PendingPayment,
            BaseReferences<_$KobanDatabase, PendingPayments, PendingPayment>,
          ),
          PendingPayment,
          PrefetchHooks Function()
        > {
  $PendingPaymentsTableManager(_$KobanDatabase db, PendingPayments table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PendingPaymentsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PendingPaymentsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PendingPaymentsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<Decimal> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                Value<TransactionType> transactionType = const Value.absent(),
                Value<String> sourcePackage = const Value.absent(),
                Value<String> rawNotificationText = const Value.absent(),
                Value<int> notificationPostTime = const Value.absent(),
                Value<String?> notificationKey = const Value.absent(),
                Value<String> dedupKey = const Value.absent(),
                Value<CaptureFormat> format = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<bool> likelyPromotion = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<bool> edited = const Value.absent(),
                Value<bool> directionUnclear = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingPaymentsCompanion(
                id: id,
                amount: amount,
                currency: currency,
                merchant: merchant,
                transactionType: transactionType,
                sourcePackage: sourcePackage,
                rawNotificationText: rawNotificationText,
                notificationPostTime: notificationPostTime,
                notificationKey: notificationKey,
                dedupKey: dedupKey,
                format: format,
                categoryId: categoryId,
                likelyPromotion: likelyPromotion,
                createdAt: createdAt,
                edited: edited,
                directionUnclear: directionUnclear,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required Decimal amount,
                required String currency,
                Value<String?> merchant = const Value.absent(),
                required TransactionType transactionType,
                required String sourcePackage,
                required String rawNotificationText,
                required int notificationPostTime,
                Value<String?> notificationKey = const Value.absent(),
                required String dedupKey,
                required CaptureFormat format,
                Value<String?> categoryId = const Value.absent(),
                required bool likelyPromotion,
                required int createdAt,
                required bool edited,
                Value<bool> directionUnclear = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingPaymentsCompanion.insert(
                id: id,
                amount: amount,
                currency: currency,
                merchant: merchant,
                transactionType: transactionType,
                sourcePackage: sourcePackage,
                rawNotificationText: rawNotificationText,
                notificationPostTime: notificationPostTime,
                notificationKey: notificationKey,
                dedupKey: dedupKey,
                format: format,
                categoryId: categoryId,
                likelyPromotion: likelyPromotion,
                createdAt: createdAt,
                edited: edited,
                directionUnclear: directionUnclear,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PendingPayments, PendingPayment>(table),
                  BaseReferences<
                    _$KobanDatabase,
                    PendingPayments,
                    PendingPayment
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PendingPaymentsProcessedTableManager =
    ProcessedTableManager<
      _$KobanDatabase,
      PendingPayments,
      PendingPayment,
      $PendingPaymentsFilterComposer,
      $PendingPaymentsOrderingComposer,
      $PendingPaymentsAnnotationComposer,
      $PendingPaymentsCreateCompanionBuilder,
      $PendingPaymentsUpdateCompanionBuilder,
      (
        PendingPayment,
        BaseReferences<_$KobanDatabase, PendingPayments, PendingPayment>,
      ),
      PendingPayment,
      PrefetchHooks Function()
    >;
typedef $DroppedNotificationsCreateCompanionBuilder =
    DroppedNotificationsCompanion Function({
      required String dedupKey,
      Value<String?> notificationKey,
      required int droppedAt,
      Value<int> rowid,
    });
typedef $DroppedNotificationsUpdateCompanionBuilder =
    DroppedNotificationsCompanion Function({
      Value<String> dedupKey,
      Value<String?> notificationKey,
      Value<int> droppedAt,
      Value<int> rowid,
    });

class $DroppedNotificationsFilterComposer
    extends Composer<_$KobanDatabase, DroppedNotifications> {
  $DroppedNotificationsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dedupKey => $composableBuilder(
    column: $table.dedupKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notificationKey => $composableBuilder(
    column: $table.notificationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get droppedAt => $composableBuilder(
    column: $table.droppedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $DroppedNotificationsOrderingComposer
    extends Composer<_$KobanDatabase, DroppedNotifications> {
  $DroppedNotificationsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dedupKey => $composableBuilder(
    column: $table.dedupKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notificationKey => $composableBuilder(
    column: $table.notificationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get droppedAt => $composableBuilder(
    column: $table.droppedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $DroppedNotificationsAnnotationComposer
    extends Composer<_$KobanDatabase, DroppedNotifications> {
  $DroppedNotificationsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dedupKey =>
      $composableBuilder(column: $table.dedupKey, builder: (column) => column);

  GeneratedColumn<String> get notificationKey => $composableBuilder(
    column: $table.notificationKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get droppedAt =>
      $composableBuilder(column: $table.droppedAt, builder: (column) => column);
}

class $DroppedNotificationsTableManager
    extends
        RootTableManager<
          _$KobanDatabase,
          DroppedNotifications,
          DroppedNotification,
          $DroppedNotificationsFilterComposer,
          $DroppedNotificationsOrderingComposer,
          $DroppedNotificationsAnnotationComposer,
          $DroppedNotificationsCreateCompanionBuilder,
          $DroppedNotificationsUpdateCompanionBuilder,
          (
            DroppedNotification,
            BaseReferences<
              _$KobanDatabase,
              DroppedNotifications,
              DroppedNotification
            >,
          ),
          DroppedNotification,
          PrefetchHooks Function()
        > {
  $DroppedNotificationsTableManager(
    _$KobanDatabase db,
    DroppedNotifications table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DroppedNotificationsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DroppedNotificationsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DroppedNotificationsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> dedupKey = const Value.absent(),
                Value<String?> notificationKey = const Value.absent(),
                Value<int> droppedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DroppedNotificationsCompanion(
                dedupKey: dedupKey,
                notificationKey: notificationKey,
                droppedAt: droppedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dedupKey,
                Value<String?> notificationKey = const Value.absent(),
                required int droppedAt,
                Value<int> rowid = const Value.absent(),
              }) => DroppedNotificationsCompanion.insert(
                dedupKey: dedupKey,
                notificationKey: notificationKey,
                droppedAt: droppedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<DroppedNotifications, DroppedNotification>(table),
                  BaseReferences<
                    _$KobanDatabase,
                    DroppedNotifications,
                    DroppedNotification
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $DroppedNotificationsProcessedTableManager =
    ProcessedTableManager<
      _$KobanDatabase,
      DroppedNotifications,
      DroppedNotification,
      $DroppedNotificationsFilterComposer,
      $DroppedNotificationsOrderingComposer,
      $DroppedNotificationsAnnotationComposer,
      $DroppedNotificationsCreateCompanionBuilder,
      $DroppedNotificationsUpdateCompanionBuilder,
      (
        DroppedNotification,
        BaseReferences<
          _$KobanDatabase,
          DroppedNotifications,
          DroppedNotification
        >,
      ),
      DroppedNotification,
      PrefetchHooks Function()
    >;
typedef $SplitBillsCreateCompanionBuilder = SplitBillsCompanion Function({
  required String id,
  Value<String?> merchant,
  required int billTime,
  required String currency,
  Value<Decimal?> printedTotal,
  required Decimal serviceCharge,
  required Decimal tax,
  required Decimal discount,
  required Decimal rounding,
  Value<String?> linkedExpenseId,
  required int createdAt,
  Value<bool> manual,
  Value<int> rowid,
});
typedef $SplitBillsUpdateCompanionBuilder = SplitBillsCompanion Function({
  Value<String> id,
  Value<String?> merchant,
  Value<int> billTime,
  Value<String> currency,
  Value<Decimal?> printedTotal,
  Value<Decimal> serviceCharge,
  Value<Decimal> tax,
  Value<Decimal> discount,
  Value<Decimal> rounding,
  Value<String?> linkedExpenseId,
  Value<int> createdAt,
  Value<bool> manual,
  Value<int> rowid,
});

class $SplitBillsFilterComposer extends Composer<_$KobanDatabase, SplitBills> {
  $SplitBillsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get billTime => $composableBuilder(
    column: $table.billTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal?, Decimal, String> get printedTotal =>
      $composableBuilder(
        column: $table.printedTotal,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get serviceCharge =>
      $composableBuilder(
        column: $table.serviceCharge,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get tax =>
      $composableBuilder(
        column: $table.tax,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get discount =>
      $composableBuilder(
        column: $table.discount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get rounding =>
      $composableBuilder(
        column: $table.rounding,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get linkedExpenseId => $composableBuilder(
    column: $table.linkedExpenseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<bool, bool, int> get manual =>
      $composableBuilder(
        column: $table.manual,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $SplitBillsOrderingComposer
    extends Composer<_$KobanDatabase, SplitBills> {
  $SplitBillsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get billTime => $composableBuilder(
    column: $table.billTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get printedTotal => $composableBuilder(
    column: $table.printedTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serviceCharge => $composableBuilder(
    column: $table.serviceCharge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rounding => $composableBuilder(
    column: $table.rounding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedExpenseId => $composableBuilder(
    column: $table.linkedExpenseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manual => $composableBuilder(
    column: $table.manual,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SplitBillsAnnotationComposer
    extends Composer<_$KobanDatabase, SplitBills> {
  $SplitBillsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<int> get billTime =>
      $composableBuilder(column: $table.billTime, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal?, String> get printedTotal =>
      $composableBuilder(
        column: $table.printedTotal,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal, String> get serviceCharge =>
      $composableBuilder(
        column: $table.serviceCharge,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal, String> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get discount =>
      $composableBuilder(column: $table.discount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get rounding =>
      $composableBuilder(column: $table.rounding, builder: (column) => column);

  GeneratedColumn<String> get linkedExpenseId => $composableBuilder(
    column: $table.linkedExpenseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<bool, int> get manual =>
      $composableBuilder(column: $table.manual, builder: (column) => column);
}

class $SplitBillsTableManager
    extends
        RootTableManager<
          _$KobanDatabase,
          SplitBills,
          SplitBill,
          $SplitBillsFilterComposer,
          $SplitBillsOrderingComposer,
          $SplitBillsAnnotationComposer,
          $SplitBillsCreateCompanionBuilder,
          $SplitBillsUpdateCompanionBuilder,
          (SplitBill, BaseReferences<_$KobanDatabase, SplitBills, SplitBill>),
          SplitBill,
          PrefetchHooks Function()
        > {
  $SplitBillsTableManager(_$KobanDatabase db, SplitBills table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SplitBillsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SplitBillsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SplitBillsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                Value<int> billTime = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<Decimal?> printedTotal = const Value.absent(),
                Value<Decimal> serviceCharge = const Value.absent(),
                Value<Decimal> tax = const Value.absent(),
                Value<Decimal> discount = const Value.absent(),
                Value<Decimal> rounding = const Value.absent(),
                Value<String?> linkedExpenseId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<bool> manual = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SplitBillsCompanion(
                id: id,
                merchant: merchant,
                billTime: billTime,
                currency: currency,
                printedTotal: printedTotal,
                serviceCharge: serviceCharge,
                tax: tax,
                discount: discount,
                rounding: rounding,
                linkedExpenseId: linkedExpenseId,
                createdAt: createdAt,
                manual: manual,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> merchant = const Value.absent(),
                required int billTime,
                required String currency,
                Value<Decimal?> printedTotal = const Value.absent(),
                required Decimal serviceCharge,
                required Decimal tax,
                required Decimal discount,
                required Decimal rounding,
                Value<String?> linkedExpenseId = const Value.absent(),
                required int createdAt,
                Value<bool> manual = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SplitBillsCompanion.insert(
                id: id,
                merchant: merchant,
                billTime: billTime,
                currency: currency,
                printedTotal: printedTotal,
                serviceCharge: serviceCharge,
                tax: tax,
                discount: discount,
                rounding: rounding,
                linkedExpenseId: linkedExpenseId,
                createdAt: createdAt,
                manual: manual,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SplitBills, SplitBill>(table),
                  BaseReferences<_$KobanDatabase, SplitBills, SplitBill>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SplitBillsProcessedTableManager =
    ProcessedTableManager<
      _$KobanDatabase,
      SplitBills,
      SplitBill,
      $SplitBillsFilterComposer,
      $SplitBillsOrderingComposer,
      $SplitBillsAnnotationComposer,
      $SplitBillsCreateCompanionBuilder,
      $SplitBillsUpdateCompanionBuilder,
      (SplitBill, BaseReferences<_$KobanDatabase, SplitBills, SplitBill>),
      SplitBill,
      PrefetchHooks Function()
    >;
typedef $SplitItemsCreateCompanionBuilder = SplitItemsCompanion Function({
  required String id,
  required String billId,
  required String name,
  required int quantity,
  required Decimal price,
  required int position,
  Value<int> rowid,
});
typedef $SplitItemsUpdateCompanionBuilder = SplitItemsCompanion Function({
  Value<String> id,
  Value<String> billId,
  Value<String> name,
  Value<int> quantity,
  Value<Decimal> price,
  Value<int> position,
  Value<int> rowid,
});

class $SplitItemsFilterComposer extends Composer<_$KobanDatabase, SplitItems> {
  $SplitItemsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get billId => $composableBuilder(
    column: $table.billId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get price =>
      $composableBuilder(
        column: $table.price,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $SplitItemsOrderingComposer
    extends Composer<_$KobanDatabase, SplitItems> {
  $SplitItemsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get billId => $composableBuilder(
    column: $table.billId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SplitItemsAnnotationComposer
    extends Composer<_$KobanDatabase, SplitItems> {
  $SplitItemsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get billId =>
      $composableBuilder(column: $table.billId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $SplitItemsTableManager
    extends
        RootTableManager<
          _$KobanDatabase,
          SplitItems,
          SplitItem,
          $SplitItemsFilterComposer,
          $SplitItemsOrderingComposer,
          $SplitItemsAnnotationComposer,
          $SplitItemsCreateCompanionBuilder,
          $SplitItemsUpdateCompanionBuilder,
          (SplitItem, BaseReferences<_$KobanDatabase, SplitItems, SplitItem>),
          SplitItem,
          PrefetchHooks Function()
        > {
  $SplitItemsTableManager(_$KobanDatabase db, SplitItems table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SplitItemsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SplitItemsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SplitItemsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> billId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<Decimal> price = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SplitItemsCompanion(
                id: id,
                billId: billId,
                name: name,
                quantity: quantity,
                price: price,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String billId,
                required String name,
                required int quantity,
                required Decimal price,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => SplitItemsCompanion.insert(
                id: id,
                billId: billId,
                name: name,
                quantity: quantity,
                price: price,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SplitItems, SplitItem>(table),
                  BaseReferences<_$KobanDatabase, SplitItems, SplitItem>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SplitItemsProcessedTableManager =
    ProcessedTableManager<
      _$KobanDatabase,
      SplitItems,
      SplitItem,
      $SplitItemsFilterComposer,
      $SplitItemsOrderingComposer,
      $SplitItemsAnnotationComposer,
      $SplitItemsCreateCompanionBuilder,
      $SplitItemsUpdateCompanionBuilder,
      (SplitItem, BaseReferences<_$KobanDatabase, SplitItems, SplitItem>),
      SplitItem,
      PrefetchHooks Function()
    >;
typedef $SplitPeopleCreateCompanionBuilder = SplitPeopleCompanion Function({
  required String id,
  required String name,
  required int lastUsedAt,
  Value<String?> qrPath,
  Value<bool> archived,
  Value<String?> suggestedSettleExpenseId,
  Value<int> rowid,
});
typedef $SplitPeopleUpdateCompanionBuilder = SplitPeopleCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> lastUsedAt,
  Value<String?> qrPath,
  Value<bool> archived,
  Value<String?> suggestedSettleExpenseId,
  Value<int> rowid,
});

class $SplitPeopleFilterComposer
    extends Composer<_$KobanDatabase, SplitPeople> {
  $SplitPeopleFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qrPath => $composableBuilder(
    column: $table.qrPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<bool, bool, int> get archived =>
      $composableBuilder(
        column: $table.archived,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get suggestedSettleExpenseId => $composableBuilder(
    column: $table.suggestedSettleExpenseId,
    builder: (column) => ColumnFilters(column),
  );
}

class $SplitPeopleOrderingComposer
    extends Composer<_$KobanDatabase, SplitPeople> {
  $SplitPeopleOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qrPath => $composableBuilder(
    column: $table.qrPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedSettleExpenseId => $composableBuilder(
    column: $table.suggestedSettleExpenseId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SplitPeopleAnnotationComposer
    extends Composer<_$KobanDatabase, SplitPeople> {
  $SplitPeopleAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get qrPath =>
      $composableBuilder(column: $table.qrPath, builder: (column) => column);

  GeneratedColumnWithTypeConverter<bool, int> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<String> get suggestedSettleExpenseId => $composableBuilder(
    column: $table.suggestedSettleExpenseId,
    builder: (column) => column,
  );
}

class $SplitPeopleTableManager
    extends
        RootTableManager<
          _$KobanDatabase,
          SplitPeople,
          SplitPeopleData,
          $SplitPeopleFilterComposer,
          $SplitPeopleOrderingComposer,
          $SplitPeopleAnnotationComposer,
          $SplitPeopleCreateCompanionBuilder,
          $SplitPeopleUpdateCompanionBuilder,
          (
            SplitPeopleData,
            BaseReferences<_$KobanDatabase, SplitPeople, SplitPeopleData>,
          ),
          SplitPeopleData,
          PrefetchHooks Function()
        > {
  $SplitPeopleTableManager(_$KobanDatabase db, SplitPeople table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SplitPeopleFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SplitPeopleOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SplitPeopleAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> lastUsedAt = const Value.absent(),
                Value<String?> qrPath = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String?> suggestedSettleExpenseId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SplitPeopleCompanion(
                id: id,
                name: name,
                lastUsedAt: lastUsedAt,
                qrPath: qrPath,
                archived: archived,
                suggestedSettleExpenseId: suggestedSettleExpenseId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int lastUsedAt,
                Value<String?> qrPath = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String?> suggestedSettleExpenseId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SplitPeopleCompanion.insert(
                id: id,
                name: name,
                lastUsedAt: lastUsedAt,
                qrPath: qrPath,
                archived: archived,
                suggestedSettleExpenseId: suggestedSettleExpenseId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SplitPeople, SplitPeopleData>(table),
                  BaseReferences<_$KobanDatabase, SplitPeople, SplitPeopleData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SplitPeopleProcessedTableManager =
    ProcessedTableManager<
      _$KobanDatabase,
      SplitPeople,
      SplitPeopleData,
      $SplitPeopleFilterComposer,
      $SplitPeopleOrderingComposer,
      $SplitPeopleAnnotationComposer,
      $SplitPeopleCreateCompanionBuilder,
      $SplitPeopleUpdateCompanionBuilder,
      (
        SplitPeopleData,
        BaseReferences<_$KobanDatabase, SplitPeople, SplitPeopleData>,
      ),
      SplitPeopleData,
      PrefetchHooks Function()
    >;
typedef $SplitItemSharesCreateCompanionBuilder =
    SplitItemSharesCompanion Function({
      required String itemId,
      required String personId,
      Value<int> rowid,
    });
typedef $SplitItemSharesUpdateCompanionBuilder =
    SplitItemSharesCompanion Function({
      Value<String> itemId,
      Value<String> personId,
      Value<int> rowid,
    });

class $SplitItemSharesFilterComposer
    extends Composer<_$KobanDatabase, SplitItemShares> {
  $SplitItemSharesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnFilters(column),
  );
}

class $SplitItemSharesOrderingComposer
    extends Composer<_$KobanDatabase, SplitItemShares> {
  $SplitItemSharesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SplitItemSharesAnnotationComposer
    extends Composer<_$KobanDatabase, SplitItemShares> {
  $SplitItemSharesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get personId =>
      $composableBuilder(column: $table.personId, builder: (column) => column);
}

class $SplitItemSharesTableManager
    extends
        RootTableManager<
          _$KobanDatabase,
          SplitItemShares,
          SplitItemShare,
          $SplitItemSharesFilterComposer,
          $SplitItemSharesOrderingComposer,
          $SplitItemSharesAnnotationComposer,
          $SplitItemSharesCreateCompanionBuilder,
          $SplitItemSharesUpdateCompanionBuilder,
          (
            SplitItemShare,
            BaseReferences<_$KobanDatabase, SplitItemShares, SplitItemShare>,
          ),
          SplitItemShare,
          PrefetchHooks Function()
        > {
  $SplitItemSharesTableManager(_$KobanDatabase db, SplitItemShares table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SplitItemSharesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SplitItemSharesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SplitItemSharesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SplitItemSharesCompanion(
                itemId: itemId,
                personId: personId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required String personId,
                Value<int> rowid = const Value.absent(),
              }) => SplitItemSharesCompanion.insert(
                itemId: itemId,
                personId: personId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SplitItemShares, SplitItemShare>(table),
                  BaseReferences<
                    _$KobanDatabase,
                    SplitItemShares,
                    SplitItemShare
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SplitItemSharesProcessedTableManager =
    ProcessedTableManager<
      _$KobanDatabase,
      SplitItemShares,
      SplitItemShare,
      $SplitItemSharesFilterComposer,
      $SplitItemSharesOrderingComposer,
      $SplitItemSharesAnnotationComposer,
      $SplitItemSharesCreateCompanionBuilder,
      $SplitItemSharesUpdateCompanionBuilder,
      (
        SplitItemShare,
        BaseReferences<_$KobanDatabase, SplitItemShares, SplitItemShare>,
      ),
      SplitItemShare,
      PrefetchHooks Function()
    >;
typedef $SplitDebtsCreateCompanionBuilder = SplitDebtsCompanion Function({
  required String id,
  required String billId,
  required String personId,
  required Decimal amount,
  required DebtStatus status,
  Value<String?> repaymentExpenseId,
  Value<String?> suggestedRepaymentExpenseId,
  Value<int?> paidAt,
  Value<int> rowid,
});
typedef $SplitDebtsUpdateCompanionBuilder = SplitDebtsCompanion Function({
  Value<String> id,
  Value<String> billId,
  Value<String> personId,
  Value<Decimal> amount,
  Value<DebtStatus> status,
  Value<String?> repaymentExpenseId,
  Value<String?> suggestedRepaymentExpenseId,
  Value<int?> paidAt,
  Value<int> rowid,
});

class $SplitDebtsFilterComposer extends Composer<_$KobanDatabase, SplitDebts> {
  $SplitDebtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get billId => $composableBuilder(
    column: $table.billId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DebtStatus, DebtStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get repaymentExpenseId => $composableBuilder(
    column: $table.repaymentExpenseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedRepaymentExpenseId => $composableBuilder(
    column: $table.suggestedRepaymentExpenseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $SplitDebtsOrderingComposer
    extends Composer<_$KobanDatabase, SplitDebts> {
  $SplitDebtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get billId => $composableBuilder(
    column: $table.billId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repaymentExpenseId => $composableBuilder(
    column: $table.repaymentExpenseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedRepaymentExpenseId => $composableBuilder(
    column: $table.suggestedRepaymentExpenseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SplitDebtsAnnotationComposer
    extends Composer<_$KobanDatabase, SplitDebts> {
  $SplitDebtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get billId =>
      $composableBuilder(column: $table.billId, builder: (column) => column);

  GeneratedColumn<String> get personId =>
      $composableBuilder(column: $table.personId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DebtStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get repaymentExpenseId => $composableBuilder(
    column: $table.repaymentExpenseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedRepaymentExpenseId => $composableBuilder(
    column: $table.suggestedRepaymentExpenseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);
}

class $SplitDebtsTableManager
    extends
        RootTableManager<
          _$KobanDatabase,
          SplitDebts,
          SplitDebt,
          $SplitDebtsFilterComposer,
          $SplitDebtsOrderingComposer,
          $SplitDebtsAnnotationComposer,
          $SplitDebtsCreateCompanionBuilder,
          $SplitDebtsUpdateCompanionBuilder,
          (SplitDebt, BaseReferences<_$KobanDatabase, SplitDebts, SplitDebt>),
          SplitDebt,
          PrefetchHooks Function()
        > {
  $SplitDebtsTableManager(_$KobanDatabase db, SplitDebts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SplitDebtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SplitDebtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SplitDebtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> billId = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<Decimal> amount = const Value.absent(),
                Value<DebtStatus> status = const Value.absent(),
                Value<String?> repaymentExpenseId = const Value.absent(),
                Value<String?> suggestedRepaymentExpenseId =
                    const Value.absent(),
                Value<int?> paidAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SplitDebtsCompanion(
                id: id,
                billId: billId,
                personId: personId,
                amount: amount,
                status: status,
                repaymentExpenseId: repaymentExpenseId,
                suggestedRepaymentExpenseId: suggestedRepaymentExpenseId,
                paidAt: paidAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String billId,
                required String personId,
                required Decimal amount,
                required DebtStatus status,
                Value<String?> repaymentExpenseId = const Value.absent(),
                Value<String?> suggestedRepaymentExpenseId =
                    const Value.absent(),
                Value<int?> paidAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SplitDebtsCompanion.insert(
                id: id,
                billId: billId,
                personId: personId,
                amount: amount,
                status: status,
                repaymentExpenseId: repaymentExpenseId,
                suggestedRepaymentExpenseId: suggestedRepaymentExpenseId,
                paidAt: paidAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SplitDebts, SplitDebt>(table),
                  BaseReferences<_$KobanDatabase, SplitDebts, SplitDebt>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SplitDebtsProcessedTableManager =
    ProcessedTableManager<
      _$KobanDatabase,
      SplitDebts,
      SplitDebt,
      $SplitDebtsFilterComposer,
      $SplitDebtsOrderingComposer,
      $SplitDebtsAnnotationComposer,
      $SplitDebtsCreateCompanionBuilder,
      $SplitDebtsUpdateCompanionBuilder,
      (SplitDebt, BaseReferences<_$KobanDatabase, SplitDebts, SplitDebt>),
      SplitDebt,
      PrefetchHooks Function()
    >;
typedef $OwedItemsCreateCompanionBuilder = OwedItemsCompanion Function({
  required String id,
  required String personId,
  required String description,
  required Decimal amount,
  required int itemDate,
  required int createdAt,
  required DebtStatus status,
  Value<int?> paidAt,
  Value<int> rowid,
});
typedef $OwedItemsUpdateCompanionBuilder = OwedItemsCompanion Function({
  Value<String> id,
  Value<String> personId,
  Value<String> description,
  Value<Decimal> amount,
  Value<int> itemDate,
  Value<int> createdAt,
  Value<DebtStatus> status,
  Value<int?> paidAt,
  Value<int> rowid,
});

class $OwedItemsFilterComposer extends Composer<_$KobanDatabase, OwedItems> {
  $OwedItemsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get itemDate => $composableBuilder(
    column: $table.itemDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DebtStatus, DebtStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $OwedItemsOrderingComposer extends Composer<_$KobanDatabase, OwedItems> {
  $OwedItemsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemDate => $composableBuilder(
    column: $table.itemDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $OwedItemsAnnotationComposer
    extends Composer<_$KobanDatabase, OwedItems> {
  $OwedItemsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get personId =>
      $composableBuilder(column: $table.personId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Decimal, String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get itemDate =>
      $composableBuilder(column: $table.itemDate, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DebtStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);
}

class $OwedItemsTableManager
    extends
        RootTableManager<
          _$KobanDatabase,
          OwedItems,
          OwedItem,
          $OwedItemsFilterComposer,
          $OwedItemsOrderingComposer,
          $OwedItemsAnnotationComposer,
          $OwedItemsCreateCompanionBuilder,
          $OwedItemsUpdateCompanionBuilder,
          (OwedItem, BaseReferences<_$KobanDatabase, OwedItems, OwedItem>),
          OwedItem,
          PrefetchHooks Function()
        > {
  $OwedItemsTableManager(_$KobanDatabase db, OwedItems table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $OwedItemsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $OwedItemsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $OwedItemsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<Decimal> amount = const Value.absent(),
                Value<int> itemDate = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<DebtStatus> status = const Value.absent(),
                Value<int?> paidAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OwedItemsCompanion(
                id: id,
                personId: personId,
                description: description,
                amount: amount,
                itemDate: itemDate,
                createdAt: createdAt,
                status: status,
                paidAt: paidAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String personId,
                required String description,
                required Decimal amount,
                required int itemDate,
                required int createdAt,
                required DebtStatus status,
                Value<int?> paidAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OwedItemsCompanion.insert(
                id: id,
                personId: personId,
                description: description,
                amount: amount,
                itemDate: itemDate,
                createdAt: createdAt,
                status: status,
                paidAt: paidAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<OwedItems, OwedItem>(table),
                  BaseReferences<_$KobanDatabase, OwedItems, OwedItem>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $OwedItemsProcessedTableManager =
    ProcessedTableManager<
      _$KobanDatabase,
      OwedItems,
      OwedItem,
      $OwedItemsFilterComposer,
      $OwedItemsOrderingComposer,
      $OwedItemsAnnotationComposer,
      $OwedItemsCreateCompanionBuilder,
      $OwedItemsUpdateCompanionBuilder,
      (OwedItem, BaseReferences<_$KobanDatabase, OwedItems, OwedItem>),
      OwedItem,
      PrefetchHooks Function()
    >;

class $KobanDatabaseManager {
  final _$KobanDatabase _db;
  $KobanDatabaseManager(this._db);
  $ExpensesTableManager get expenses =>
      $ExpensesTableManager(_db, _db.expenses);
  $CategoriesTableManager get categories =>
      $CategoriesTableManager(_db, _db.categories);
  $MerchantCategoryMapTableManager get merchantCategoryMap =>
      $MerchantCategoryMapTableManager(_db, _db.merchantCategoryMap);
  $PendingPaymentsTableManager get pendingPayments =>
      $PendingPaymentsTableManager(_db, _db.pendingPayments);
  $DroppedNotificationsTableManager get droppedNotifications =>
      $DroppedNotificationsTableManager(_db, _db.droppedNotifications);
  $SplitBillsTableManager get splitBills =>
      $SplitBillsTableManager(_db, _db.splitBills);
  $SplitItemsTableManager get splitItems =>
      $SplitItemsTableManager(_db, _db.splitItems);
  $SplitPeopleTableManager get splitPeople =>
      $SplitPeopleTableManager(_db, _db.splitPeople);
  $SplitItemSharesTableManager get splitItemShares =>
      $SplitItemSharesTableManager(_db, _db.splitItemShares);
  $SplitDebtsTableManager get splitDebts =>
      $SplitDebtsTableManager(_db, _db.splitDebts);
  $OwedItemsTableManager get owedItems =>
      $OwedItemsTableManager(_db, _db.owedItems);
}
