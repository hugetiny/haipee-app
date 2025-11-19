// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HistoriesTable extends Histories
    with TableInfo<$HistoriesTable, History> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastWatchTimeMeta =
      const VerificationMeta('lastWatchTime');
  @override
  late final GeneratedColumn<DateTime> lastWatchTime =
      GeneratedColumn<DateTime>('last_watch_time', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, json, lastWatchTime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'histories';
  @override
  VerificationContext validateIntegrity(Insertable<History> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('last_watch_time')) {
      context.handle(
          _lastWatchTimeMeta,
          lastWatchTime.isAcceptableOrUnknown(
              data['last_watch_time']!, _lastWatchTimeMeta));
    } else if (isInserting) {
      context.missing(_lastWatchTimeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  History map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return History(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      lastWatchTime: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_watch_time'])!,
    );
  }

  @override
  $HistoriesTable createAlias(String alias) {
    return $HistoriesTable(attachedDatabase, alias);
  }
}

class History extends DataClass implements Insertable<History> {
  final int id;
  final String json;
  final DateTime lastWatchTime;
  const History(
      {required this.id, required this.json, required this.lastWatchTime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['json'] = Variable<String>(json);
    map['last_watch_time'] = Variable<DateTime>(lastWatchTime);
    return map;
  }

  HistoriesCompanion toCompanion(bool nullToAbsent) {
    return HistoriesCompanion(
      id: Value(id),
      json: Value(json),
      lastWatchTime: Value(lastWatchTime),
    );
  }

  factory History.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return History(
      id: serializer.fromJson<int>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      lastWatchTime: serializer.fromJson<DateTime>(json['lastWatchTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'json': serializer.toJson<String>(json),
      'lastWatchTime': serializer.toJson<DateTime>(lastWatchTime),
    };
  }

  History copyWith({int? id, String? json, DateTime? lastWatchTime}) => History(
        id: id ?? this.id,
        json: json ?? this.json,
        lastWatchTime: lastWatchTime ?? this.lastWatchTime,
      );
  History copyWithCompanion(HistoriesCompanion data) {
    return History(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      lastWatchTime: data.lastWatchTime.present
          ? data.lastWatchTime.value
          : this.lastWatchTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('History(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('lastWatchTime: $lastWatchTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json, lastWatchTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is History &&
          other.id == this.id &&
          other.json == this.json &&
          other.lastWatchTime == this.lastWatchTime);
}

class HistoriesCompanion extends UpdateCompanion<History> {
  final Value<int> id;
  final Value<String> json;
  final Value<DateTime> lastWatchTime;
  const HistoriesCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.lastWatchTime = const Value.absent(),
  });
  HistoriesCompanion.insert({
    this.id = const Value.absent(),
    required String json,
    required DateTime lastWatchTime,
  })  : json = Value(json),
        lastWatchTime = Value(lastWatchTime);
  static Insertable<History> custom({
    Expression<int>? id,
    Expression<String>? json,
    Expression<DateTime>? lastWatchTime,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (lastWatchTime != null) 'last_watch_time': lastWatchTime,
    });
  }

  HistoriesCompanion copyWith(
      {Value<int>? id, Value<String>? json, Value<DateTime>? lastWatchTime}) {
    return HistoriesCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      lastWatchTime: lastWatchTime ?? this.lastWatchTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (lastWatchTime.present) {
      map['last_watch_time'] = Variable<DateTime>(lastWatchTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoriesCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('lastWatchTime: $lastWatchTime')
          ..write(')'))
        .toString();
  }
}

class $CollectiblesTable extends Collectibles
    with TableInfo<$CollectiblesTable, Collectible> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectiblesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
      'type', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updateTimeMeta =
      const VerificationMeta('updateTime');
  @override
  late final GeneratedColumn<DateTime> updateTime = GeneratedColumn<DateTime>(
      'update_time', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, json, type, updateTime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collectibles';
  @override
  VerificationContext validateIntegrity(Insertable<Collectible> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('update_time')) {
      context.handle(
          _updateTimeMeta,
          updateTime.isAcceptableOrUnknown(
              data['update_time']!, _updateTimeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Collectible map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Collectible(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!,
      updateTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}update_time']),
    );
  }

  @override
  $CollectiblesTable createAlias(String alias) {
    return $CollectiblesTable(attachedDatabase, alias);
  }
}

class Collectible extends DataClass implements Insertable<Collectible> {
  final int id;
  final String json;
  final int type;
  final DateTime? updateTime;
  const Collectible(
      {required this.id,
      required this.json,
      required this.type,
      this.updateTime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['json'] = Variable<String>(json);
    map['type'] = Variable<int>(type);
    if (!nullToAbsent || updateTime != null) {
      map['update_time'] = Variable<DateTime>(updateTime);
    }
    return map;
  }

  CollectiblesCompanion toCompanion(bool nullToAbsent) {
    return CollectiblesCompanion(
      id: Value(id),
      json: Value(json),
      type: Value(type),
      updateTime: updateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(updateTime),
    );
  }

  factory Collectible.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Collectible(
      id: serializer.fromJson<int>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      type: serializer.fromJson<int>(json['type']),
      updateTime: serializer.fromJson<DateTime?>(json['updateTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'json': serializer.toJson<String>(json),
      'type': serializer.toJson<int>(type),
      'updateTime': serializer.toJson<DateTime?>(updateTime),
    };
  }

  Collectible copyWith(
          {int? id,
          String? json,
          int? type,
          Value<DateTime?> updateTime = const Value.absent()}) =>
      Collectible(
        id: id ?? this.id,
        json: json ?? this.json,
        type: type ?? this.type,
        updateTime: updateTime.present ? updateTime.value : this.updateTime,
      );
  Collectible copyWithCompanion(CollectiblesCompanion data) {
    return Collectible(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      type: data.type.present ? data.type.value : this.type,
      updateTime:
          data.updateTime.present ? data.updateTime.value : this.updateTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Collectible(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('type: $type, ')
          ..write('updateTime: $updateTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json, type, updateTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Collectible &&
          other.id == this.id &&
          other.json == this.json &&
          other.type == this.type &&
          other.updateTime == this.updateTime);
}

class CollectiblesCompanion extends UpdateCompanion<Collectible> {
  final Value<int> id;
  final Value<String> json;
  final Value<int> type;
  final Value<DateTime?> updateTime;
  const CollectiblesCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.type = const Value.absent(),
    this.updateTime = const Value.absent(),
  });
  CollectiblesCompanion.insert({
    this.id = const Value.absent(),
    required String json,
    required int type,
    this.updateTime = const Value.absent(),
  })  : json = Value(json),
        type = Value(type);
  static Insertable<Collectible> custom({
    Expression<int>? id,
    Expression<String>? json,
    Expression<int>? type,
    Expression<DateTime>? updateTime,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (type != null) 'type': type,
      if (updateTime != null) 'update_time': updateTime,
    });
  }

  CollectiblesCompanion copyWith(
      {Value<int>? id,
      Value<String>? json,
      Value<int>? type,
      Value<DateTime?>? updateTime}) {
    return CollectiblesCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      type: type ?? this.type,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (updateTime.present) {
      map['update_time'] = Variable<DateTime>(updateTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectiblesCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('type: $type, ')
          ..write('updateTime: $updateTime')
          ..write(')'))
        .toString();
  }
}

class $CollectChangesTable extends CollectChanges
    with TableInfo<$CollectChangesTable, CollectChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bangumiIdMeta =
      const VerificationMeta('bangumiId');
  @override
  late final GeneratedColumn<int> bangumiId = GeneratedColumn<int>(
      'bangumi_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, json, bangumiId, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collect_changes';
  @override
  VerificationContext validateIntegrity(Insertable<CollectChange> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('bangumi_id')) {
      context.handle(_bangumiIdMeta,
          bangumiId.isAcceptableOrUnknown(data['bangumi_id']!, _bangumiIdMeta));
    } else if (isInserting) {
      context.missing(_bangumiIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CollectChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectChange(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      bangumiId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bangumi_id'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $CollectChangesTable createAlias(String alias) {
    return $CollectChangesTable(attachedDatabase, alias);
  }
}

class CollectChange extends DataClass implements Insertable<CollectChange> {
  final int id;
  final String json;
  final int bangumiId;
  final DateTime timestamp;
  const CollectChange(
      {required this.id,
      required this.json,
      required this.bangumiId,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['json'] = Variable<String>(json);
    map['bangumi_id'] = Variable<int>(bangumiId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  CollectChangesCompanion toCompanion(bool nullToAbsent) {
    return CollectChangesCompanion(
      id: Value(id),
      json: Value(json),
      bangumiId: Value(bangumiId),
      timestamp: Value(timestamp),
    );
  }

  factory CollectChange.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectChange(
      id: serializer.fromJson<int>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      bangumiId: serializer.fromJson<int>(json['bangumiId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'json': serializer.toJson<String>(json),
      'bangumiId': serializer.toJson<int>(bangumiId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  CollectChange copyWith(
          {int? id, String? json, int? bangumiId, DateTime? timestamp}) =>
      CollectChange(
        id: id ?? this.id,
        json: json ?? this.json,
        bangumiId: bangumiId ?? this.bangumiId,
        timestamp: timestamp ?? this.timestamp,
      );
  CollectChange copyWithCompanion(CollectChangesCompanion data) {
    return CollectChange(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      bangumiId: data.bangumiId.present ? data.bangumiId.value : this.bangumiId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectChange(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json, bangumiId, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectChange &&
          other.id == this.id &&
          other.json == this.json &&
          other.bangumiId == this.bangumiId &&
          other.timestamp == this.timestamp);
}

class CollectChangesCompanion extends UpdateCompanion<CollectChange> {
  final Value<int> id;
  final Value<String> json;
  final Value<int> bangumiId;
  final Value<DateTime> timestamp;
  const CollectChangesCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.bangumiId = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  CollectChangesCompanion.insert({
    this.id = const Value.absent(),
    required String json,
    required int bangumiId,
    required DateTime timestamp,
  })  : json = Value(json),
        bangumiId = Value(bangumiId),
        timestamp = Value(timestamp);
  static Insertable<CollectChange> custom({
    Expression<int>? id,
    Expression<String>? json,
    Expression<int>? bangumiId,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (bangumiId != null) 'bangumi_id': bangumiId,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  CollectChangesCompanion copyWith(
      {Value<int>? id,
      Value<String>? json,
      Value<int>? bangumiId,
      Value<DateTime>? timestamp}) {
    return CollectChangesCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      bangumiId: bangumiId ?? this.bangumiId,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (bangumiId.present) {
      map['bangumi_id'] = Variable<int>(bangumiId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectChangesCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoriesTable extends SearchHistories
    with TableInfo<$SearchHistoriesTable, SearchHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keywordMeta =
      const VerificationMeta('keyword');
  @override
  late final GeneratedColumn<String> keyword = GeneratedColumn<String>(
      'keyword', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [keyword, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_histories';
  @override
  VerificationContext validateIntegrity(Insertable<SearchHistory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('keyword')) {
      context.handle(_keywordMeta,
          keyword.isAcceptableOrUnknown(data['keyword']!, _keywordMeta));
    } else if (isInserting) {
      context.missing(_keywordMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {keyword};
  @override
  SearchHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistory(
      keyword: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}keyword'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $SearchHistoriesTable createAlias(String alias) {
    return $SearchHistoriesTable(attachedDatabase, alias);
  }
}

class SearchHistory extends DataClass implements Insertable<SearchHistory> {
  final String keyword;
  final DateTime timestamp;
  const SearchHistory({required this.keyword, required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['keyword'] = Variable<String>(keyword);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  SearchHistoriesCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoriesCompanion(
      keyword: Value(keyword),
      timestamp: Value(timestamp),
    );
  }

  factory SearchHistory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistory(
      keyword: serializer.fromJson<String>(json['keyword']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'keyword': serializer.toJson<String>(keyword),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  SearchHistory copyWith({String? keyword, DateTime? timestamp}) =>
      SearchHistory(
        keyword: keyword ?? this.keyword,
        timestamp: timestamp ?? this.timestamp,
      );
  SearchHistory copyWithCompanion(SearchHistoriesCompanion data) {
    return SearchHistory(
      keyword: data.keyword.present ? data.keyword.value : this.keyword,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistory(')
          ..write('keyword: $keyword, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(keyword, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistory &&
          other.keyword == this.keyword &&
          other.timestamp == this.timestamp);
}

class SearchHistoriesCompanion extends UpdateCompanion<SearchHistory> {
  final Value<String> keyword;
  final Value<DateTime> timestamp;
  final Value<int> rowid;
  const SearchHistoriesCompanion({
    this.keyword = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchHistoriesCompanion.insert({
    required String keyword,
    required DateTime timestamp,
    this.rowid = const Value.absent(),
  })  : keyword = Value(keyword),
        timestamp = Value(timestamp);
  static Insertable<SearchHistory> custom({
    Expression<String>? keyword,
    Expression<DateTime>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (keyword != null) 'keyword': keyword,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchHistoriesCompanion copyWith(
      {Value<String>? keyword, Value<DateTime>? timestamp, Value<int>? rowid}) {
    return SearchHistoriesCompanion(
      keyword: keyword ?? this.keyword,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (keyword.present) {
      map['keyword'] = Variable<String>(keyword.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoriesCompanion(')
          ..write('keyword: $keyword, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KeyValueCacheTable extends KeyValueCache
    with TableInfo<$KeyValueCacheTable, KeyValueCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValueCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _boxNameMeta =
      const VerificationMeta('boxName');
  @override
  late final GeneratedColumn<String> boxName = GeneratedColumn<String>(
      'box_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [boxName, key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_value_cache';
  @override
  VerificationContext validateIntegrity(Insertable<KeyValueCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('box_name')) {
      context.handle(_boxNameMeta,
          boxName.isAcceptableOrUnknown(data['box_name']!, _boxNameMeta));
    } else if (isInserting) {
      context.missing(_boxNameMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {boxName, key};
  @override
  KeyValueCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValueCacheData(
      boxName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}box_name'])!,
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $KeyValueCacheTable createAlias(String alias) {
    return $KeyValueCacheTable(attachedDatabase, alias);
  }
}

class KeyValueCacheData extends DataClass
    implements Insertable<KeyValueCacheData> {
  final String boxName;
  final String key;
  final String value;
  const KeyValueCacheData(
      {required this.boxName, required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['box_name'] = Variable<String>(boxName);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KeyValueCacheCompanion toCompanion(bool nullToAbsent) {
    return KeyValueCacheCompanion(
      boxName: Value(boxName),
      key: Value(key),
      value: Value(value),
    );
  }

  factory KeyValueCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValueCacheData(
      boxName: serializer.fromJson<String>(json['boxName']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'boxName': serializer.toJson<String>(boxName),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  KeyValueCacheData copyWith({String? boxName, String? key, String? value}) =>
      KeyValueCacheData(
        boxName: boxName ?? this.boxName,
        key: key ?? this.key,
        value: value ?? this.value,
      );
  KeyValueCacheData copyWithCompanion(KeyValueCacheCompanion data) {
    return KeyValueCacheData(
      boxName: data.boxName.present ? data.boxName.value : this.boxName,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValueCacheData(')
          ..write('boxName: $boxName, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(boxName, key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyValueCacheData &&
          other.boxName == this.boxName &&
          other.key == this.key &&
          other.value == this.value);
}

class KeyValueCacheCompanion extends UpdateCompanion<KeyValueCacheData> {
  final Value<String> boxName;
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KeyValueCacheCompanion({
    this.boxName = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValueCacheCompanion.insert({
    required String boxName,
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : boxName = Value(boxName),
        key = Value(key),
        value = Value(value);
  static Insertable<KeyValueCacheData> custom({
    Expression<String>? boxName,
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (boxName != null) 'box_name': boxName,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValueCacheCompanion copyWith(
      {Value<String>? boxName,
      Value<String>? key,
      Value<String>? value,
      Value<int>? rowid}) {
    return KeyValueCacheCompanion(
      boxName: boxName ?? this.boxName,
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (boxName.present) {
      map['box_name'] = Variable<String>(boxName.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValueCacheCompanion(')
          ..write('boxName: $boxName, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $HistoriesTable histories = $HistoriesTable(this);
  late final $CollectiblesTable collectibles = $CollectiblesTable(this);
  late final $CollectChangesTable collectChanges = $CollectChangesTable(this);
  late final $SearchHistoriesTable searchHistories =
      $SearchHistoriesTable(this);
  late final $KeyValueCacheTable keyValueCache = $KeyValueCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        settings,
        histories,
        collectibles,
        collectChanges,
        searchHistories,
        keyValueCache
      ];
}

typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;
typedef $$HistoriesTableCreateCompanionBuilder = HistoriesCompanion Function({
  Value<int> id,
  required String json,
  required DateTime lastWatchTime,
});
typedef $$HistoriesTableUpdateCompanionBuilder = HistoriesCompanion Function({
  Value<int> id,
  Value<String> json,
  Value<DateTime> lastWatchTime,
});

class $$HistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $HistoriesTable> {
  $$HistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastWatchTime => $composableBuilder(
      column: $table.lastWatchTime, builder: (column) => ColumnFilters(column));
}

class $$HistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $HistoriesTable> {
  $$HistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastWatchTime => $composableBuilder(
      column: $table.lastWatchTime,
      builder: (column) => ColumnOrderings(column));
}

class $$HistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistoriesTable> {
  $$HistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get lastWatchTime => $composableBuilder(
      column: $table.lastWatchTime, builder: (column) => column);
}

class $$HistoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HistoriesTable,
    History,
    $$HistoriesTableFilterComposer,
    $$HistoriesTableOrderingComposer,
    $$HistoriesTableAnnotationComposer,
    $$HistoriesTableCreateCompanionBuilder,
    $$HistoriesTableUpdateCompanionBuilder,
    (History, BaseReferences<_$AppDatabase, $HistoriesTable, History>),
    History,
    PrefetchHooks Function()> {
  $$HistoriesTableTableManager(_$AppDatabase db, $HistoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<DateTime> lastWatchTime = const Value.absent(),
          }) =>
              HistoriesCompanion(
            id: id,
            json: json,
            lastWatchTime: lastWatchTime,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String json,
            required DateTime lastWatchTime,
          }) =>
              HistoriesCompanion.insert(
            id: id,
            json: json,
            lastWatchTime: lastWatchTime,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HistoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HistoriesTable,
    History,
    $$HistoriesTableFilterComposer,
    $$HistoriesTableOrderingComposer,
    $$HistoriesTableAnnotationComposer,
    $$HistoriesTableCreateCompanionBuilder,
    $$HistoriesTableUpdateCompanionBuilder,
    (History, BaseReferences<_$AppDatabase, $HistoriesTable, History>),
    History,
    PrefetchHooks Function()>;
typedef $$CollectiblesTableCreateCompanionBuilder = CollectiblesCompanion
    Function({
  Value<int> id,
  required String json,
  required int type,
  Value<DateTime?> updateTime,
});
typedef $$CollectiblesTableUpdateCompanionBuilder = CollectiblesCompanion
    Function({
  Value<int> id,
  Value<String> json,
  Value<int> type,
  Value<DateTime?> updateTime,
});

class $$CollectiblesTableFilterComposer
    extends Composer<_$AppDatabase, $CollectiblesTable> {
  $$CollectiblesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updateTime => $composableBuilder(
      column: $table.updateTime, builder: (column) => ColumnFilters(column));
}

class $$CollectiblesTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectiblesTable> {
  $$CollectiblesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updateTime => $composableBuilder(
      column: $table.updateTime, builder: (column) => ColumnOrderings(column));
}

class $$CollectiblesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectiblesTable> {
  $$CollectiblesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get updateTime => $composableBuilder(
      column: $table.updateTime, builder: (column) => column);
}

class $$CollectiblesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CollectiblesTable,
    Collectible,
    $$CollectiblesTableFilterComposer,
    $$CollectiblesTableOrderingComposer,
    $$CollectiblesTableAnnotationComposer,
    $$CollectiblesTableCreateCompanionBuilder,
    $$CollectiblesTableUpdateCompanionBuilder,
    (
      Collectible,
      BaseReferences<_$AppDatabase, $CollectiblesTable, Collectible>
    ),
    Collectible,
    PrefetchHooks Function()> {
  $$CollectiblesTableTableManager(_$AppDatabase db, $CollectiblesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectiblesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectiblesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectiblesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> type = const Value.absent(),
            Value<DateTime?> updateTime = const Value.absent(),
          }) =>
              CollectiblesCompanion(
            id: id,
            json: json,
            type: type,
            updateTime: updateTime,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String json,
            required int type,
            Value<DateTime?> updateTime = const Value.absent(),
          }) =>
              CollectiblesCompanion.insert(
            id: id,
            json: json,
            type: type,
            updateTime: updateTime,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CollectiblesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CollectiblesTable,
    Collectible,
    $$CollectiblesTableFilterComposer,
    $$CollectiblesTableOrderingComposer,
    $$CollectiblesTableAnnotationComposer,
    $$CollectiblesTableCreateCompanionBuilder,
    $$CollectiblesTableUpdateCompanionBuilder,
    (
      Collectible,
      BaseReferences<_$AppDatabase, $CollectiblesTable, Collectible>
    ),
    Collectible,
    PrefetchHooks Function()>;
typedef $$CollectChangesTableCreateCompanionBuilder = CollectChangesCompanion
    Function({
  Value<int> id,
  required String json,
  required int bangumiId,
  required DateTime timestamp,
});
typedef $$CollectChangesTableUpdateCompanionBuilder = CollectChangesCompanion
    Function({
  Value<int> id,
  Value<String> json,
  Value<int> bangumiId,
  Value<DateTime> timestamp,
});

class $$CollectChangesTableFilterComposer
    extends Composer<_$AppDatabase, $CollectChangesTable> {
  $$CollectChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bangumiId => $composableBuilder(
      column: $table.bangumiId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$CollectChangesTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectChangesTable> {
  $$CollectChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bangumiId => $composableBuilder(
      column: $table.bangumiId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$CollectChangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectChangesTable> {
  $$CollectChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get bangumiId =>
      $composableBuilder(column: $table.bangumiId, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$CollectChangesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CollectChangesTable,
    CollectChange,
    $$CollectChangesTableFilterComposer,
    $$CollectChangesTableOrderingComposer,
    $$CollectChangesTableAnnotationComposer,
    $$CollectChangesTableCreateCompanionBuilder,
    $$CollectChangesTableUpdateCompanionBuilder,
    (
      CollectChange,
      BaseReferences<_$AppDatabase, $CollectChangesTable, CollectChange>
    ),
    CollectChange,
    PrefetchHooks Function()> {
  $$CollectChangesTableTableManager(
      _$AppDatabase db, $CollectChangesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> bangumiId = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              CollectChangesCompanion(
            id: id,
            json: json,
            bangumiId: bangumiId,
            timestamp: timestamp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String json,
            required int bangumiId,
            required DateTime timestamp,
          }) =>
              CollectChangesCompanion.insert(
            id: id,
            json: json,
            bangumiId: bangumiId,
            timestamp: timestamp,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CollectChangesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CollectChangesTable,
    CollectChange,
    $$CollectChangesTableFilterComposer,
    $$CollectChangesTableOrderingComposer,
    $$CollectChangesTableAnnotationComposer,
    $$CollectChangesTableCreateCompanionBuilder,
    $$CollectChangesTableUpdateCompanionBuilder,
    (
      CollectChange,
      BaseReferences<_$AppDatabase, $CollectChangesTable, CollectChange>
    ),
    CollectChange,
    PrefetchHooks Function()>;
typedef $$SearchHistoriesTableCreateCompanionBuilder = SearchHistoriesCompanion
    Function({
  required String keyword,
  required DateTime timestamp,
  Value<int> rowid,
});
typedef $$SearchHistoriesTableUpdateCompanionBuilder = SearchHistoriesCompanion
    Function({
  Value<String> keyword,
  Value<DateTime> timestamp,
  Value<int> rowid,
});

class $$SearchHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $SearchHistoriesTable> {
  $$SearchHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get keyword => $composableBuilder(
      column: $table.keyword, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$SearchHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchHistoriesTable> {
  $$SearchHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get keyword => $composableBuilder(
      column: $table.keyword, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$SearchHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchHistoriesTable> {
  $$SearchHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get keyword =>
      $composableBuilder(column: $table.keyword, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$SearchHistoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SearchHistoriesTable,
    SearchHistory,
    $$SearchHistoriesTableFilterComposer,
    $$SearchHistoriesTableOrderingComposer,
    $$SearchHistoriesTableAnnotationComposer,
    $$SearchHistoriesTableCreateCompanionBuilder,
    $$SearchHistoriesTableUpdateCompanionBuilder,
    (
      SearchHistory,
      BaseReferences<_$AppDatabase, $SearchHistoriesTable, SearchHistory>
    ),
    SearchHistory,
    PrefetchHooks Function()> {
  $$SearchHistoriesTableTableManager(
      _$AppDatabase db, $SearchHistoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchHistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> keyword = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SearchHistoriesCompanion(
            keyword: keyword,
            timestamp: timestamp,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String keyword,
            required DateTime timestamp,
            Value<int> rowid = const Value.absent(),
          }) =>
              SearchHistoriesCompanion.insert(
            keyword: keyword,
            timestamp: timestamp,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SearchHistoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SearchHistoriesTable,
    SearchHistory,
    $$SearchHistoriesTableFilterComposer,
    $$SearchHistoriesTableOrderingComposer,
    $$SearchHistoriesTableAnnotationComposer,
    $$SearchHistoriesTableCreateCompanionBuilder,
    $$SearchHistoriesTableUpdateCompanionBuilder,
    (
      SearchHistory,
      BaseReferences<_$AppDatabase, $SearchHistoriesTable, SearchHistory>
    ),
    SearchHistory,
    PrefetchHooks Function()>;
typedef $$KeyValueCacheTableCreateCompanionBuilder = KeyValueCacheCompanion
    Function({
  required String boxName,
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$KeyValueCacheTableUpdateCompanionBuilder = KeyValueCacheCompanion
    Function({
  Value<String> boxName,
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$KeyValueCacheTableFilterComposer
    extends Composer<_$AppDatabase, $KeyValueCacheTable> {
  $$KeyValueCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get boxName => $composableBuilder(
      column: $table.boxName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$KeyValueCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $KeyValueCacheTable> {
  $$KeyValueCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get boxName => $composableBuilder(
      column: $table.boxName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$KeyValueCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $KeyValueCacheTable> {
  $$KeyValueCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get boxName =>
      $composableBuilder(column: $table.boxName, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KeyValueCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $KeyValueCacheTable,
    KeyValueCacheData,
    $$KeyValueCacheTableFilterComposer,
    $$KeyValueCacheTableOrderingComposer,
    $$KeyValueCacheTableAnnotationComposer,
    $$KeyValueCacheTableCreateCompanionBuilder,
    $$KeyValueCacheTableUpdateCompanionBuilder,
    (
      KeyValueCacheData,
      BaseReferences<_$AppDatabase, $KeyValueCacheTable, KeyValueCacheData>
    ),
    KeyValueCacheData,
    PrefetchHooks Function()> {
  $$KeyValueCacheTableTableManager(_$AppDatabase db, $KeyValueCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyValueCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyValueCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyValueCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> boxName = const Value.absent(),
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              KeyValueCacheCompanion(
            boxName: boxName,
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String boxName,
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              KeyValueCacheCompanion.insert(
            boxName: boxName,
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$KeyValueCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $KeyValueCacheTable,
    KeyValueCacheData,
    $$KeyValueCacheTableFilterComposer,
    $$KeyValueCacheTableOrderingComposer,
    $$KeyValueCacheTableAnnotationComposer,
    $$KeyValueCacheTableCreateCompanionBuilder,
    $$KeyValueCacheTableUpdateCompanionBuilder,
    (
      KeyValueCacheData,
      BaseReferences<_$AppDatabase, $KeyValueCacheTable, KeyValueCacheData>
    ),
    KeyValueCacheData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$HistoriesTableTableManager get histories =>
      $$HistoriesTableTableManager(_db, _db.histories);
  $$CollectiblesTableTableManager get collectibles =>
      $$CollectiblesTableTableManager(_db, _db.collectibles);
  $$CollectChangesTableTableManager get collectChanges =>
      $$CollectChangesTableTableManager(_db, _db.collectChanges);
  $$SearchHistoriesTableTableManager get searchHistories =>
      $$SearchHistoriesTableTableManager(_db, _db.searchHistories);
  $$KeyValueCacheTableTableManager get keyValueCache =>
      $$KeyValueCacheTableTableManager(_db, _db.keyValueCache);
}
