import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/TypeAccountModel.dart';

class AccountTypeDatabaseHelper {
  static final AccountTypeDatabaseHelper instance = AccountTypeDatabaseHelper._init();
  static Database? _database;

  AccountTypeDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('account_types.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 2, 
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE account_types (
      typeAccountId INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      categoryId INTEGER
    )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS account_types');
      await _createDB(db, newVersion);
    }
  }

  Future<void> insertAccountTypes(List<TypeAccountModel> accountTypes) async {
    final db = await instance.database;
    final batch = db.batch();

    // Clear old data first to avoid duplicates/stale data
    batch.delete('account_types');

    for (var type in accountTypes) {
      batch.insert(
        'account_types',
        type.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<TypeAccountModel>> getAllAccountTypes() async {
    final db = await instance.database;
    final result = await db.query('account_types');

    return result.map((json) => TypeAccountModel.fromJson(json)).toList();
  }
}
