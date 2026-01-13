import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/AgenceModel.dart';

class AgenceDatabaseHelper {
  static final AgenceDatabaseHelper instance = AgenceDatabaseHelper._init();
  static Database? _database;

  AgenceDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('agencies.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const intType = 'INTEGER';
    const textType = 'TEXT';

    await db.execute('''
      CREATE TABLE agencies (
        id $idType,
        agenceId $intType,
        userId $intType,
        name $textType,
        description $textType,
        phone1 $textType,
        phone2 $textType,
        address $textType,
        logo $textType
      )
    ''');

    print('✅ [AgenceDatabaseHelper] Database and table created');
  }

  /// Insert multiple agencies (batch operation)
  Future<void> insertAgencies(List<AgenceModel> agencies) async {
    final db = await instance.database;
    
    // Clear existing agencies before inserting new ones
    await db.delete('agencies');
    
    final batch = db.batch();
    for (var agency in agencies) {
      batch.insert(
        'agencies',
        {
          'agenceId': agency.id,
          'userId': agency.userId,
          'name': agency.name,
          'description': agency.description,
          'phone1': agency.phone1,
          'phone2': agency.phone2,
          'address': agency.address,
          'logo': agency.logo,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
    print('✅ [AgenceDatabaseHelper] Inserted ${agencies.length} agencies');
  }

  /// Get agencies by user ID
  Future<List<AgenceModel>> getAgenciesByUserId(int userId) async {
    final db = await instance.database;
    
    final result = await db.query(
      'agencies',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    print('📥 [AgenceDatabaseHelper] Found ${result.length} agencies for user $userId');
    
    return result.map((json) => AgenceModel.fromJson({
      'id': json['agenceId'],
      'userId': json['userId'],
      'name': json['name'],
      'description': json['description'],
      'phone1': json['phone1'],
      'phone2': json['phone2'],
      'address': json['address'],
      'logo': json['logo'],
    })).toList();
  }

  /// Get all agencies
  Future<List<AgenceModel>> getAllAgencies() async {
    final db = await instance.database;
    
    final result = await db.query('agencies');

    print('📥 [AgenceDatabaseHelper] Found ${result.length} total agencies');
    
    return result.map((json) => AgenceModel.fromJson({
      'id': json['agenceId'],
      'userId': json['userId'],
      'name': json['name'],
      'description': json['description'],
      'phone1': json['phone1'],
      'phone2': json['phone2'],
      'address': json['address'],
      'logo': json['logo'],
    })).toList();
  }

  /// Clear all agencies
  Future<void> clearAgencies() async {
    final db = await instance.database;
    await db.delete('agencies');
    print('🧹 [AgenceDatabaseHelper] All agencies cleared');
  }

  /// Close database
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
    print('🔒 [AgenceDatabaseHelper] Database closed');
  }
}
