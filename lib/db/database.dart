import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// Tables

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()(); // JSON encoded value

  @override
  Set<Column> get primaryKey => {key};
}

class Histories extends Table {
  IntColumn get id => integer()(); // Bangumi ID
  TextColumn get json => text()(); // Full History object JSON
  DateTimeColumn get lastWatchTime => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Collectibles extends Table {
  IntColumn get id => integer()(); // Bangumi ID
  TextColumn get json => text()(); // Full CollectedBangumi object JSON
  IntColumn get type => integer()(); // Collection status
  DateTimeColumn get updateTime => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CollectChanges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get json => text()();
  IntColumn get bangumiId => integer()();
  DateTimeColumn get timestamp => dateTime()();
}

class SearchHistories extends Table {
  TextColumn get keyword => text()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {keyword};
}

// Generic cache table for other boxes (favorites, metadata, etc)
class KeyValueCache extends Table {
  TextColumn get boxName => text()();
  TextColumn get key => text()();
  TextColumn get value => text()(); // JSON

  @override
  Set<Column> get primaryKey => {boxName, key};
}

@DriftDatabase(tables: [
  Settings,
  Histories,
  Collectibles,
  CollectChanges,
  SearchHistories,
  KeyValueCache
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'kazumi.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
