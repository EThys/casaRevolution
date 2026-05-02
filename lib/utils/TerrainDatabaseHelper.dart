import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/TerrainModel.dart';

class TerrainDatabaseHelper {
  static final TerrainDatabaseHelper instance = TerrainDatabaseHelper._init();
  static Database? _database;

  TerrainDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('terrains.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Ajout de l'avatar annonceur (champ API: "image")
          await db.execute('ALTER TABLE terrains ADD COLUMN image TEXT');
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const intType = 'INTEGER';
    const realType = 'REAL';
    const textType = 'TEXT';

    await db.execute('''
      CREATE TABLE terrains (
        id $idType,
        terrainId $intType,
        userId $intType,
        title $textType,
        description $textType,
        price $realType,
        surface $textType,
        transactionType $textType,
        available $intType,
        postBy $textType,
        image $textType,
        address $textType,
        communeValue $textType,
        quartierValue $textType,
        cityValue $textType,
        countryValue $textType,
        postalCode $textType,
        deviseId $intType,
        deviseName $textType,
        deviseCode $textType,
        deviseTauxLocal $realType,
        propertyTypeId $intType,
        propertyTypeName $textType,
        images $textType,
        createdAt $textType
      )
    ''');

    print('✅ [TerrainDatabaseHelper] Database and table created');
  }

  /// Insert multiple terrains (batch operation)
  Future<void> insertTerrains(List<Map<String, dynamic>> terrains) async {
    final db = await instance.database;
    
    // Clear existing terrains before inserting new ones
    await db.delete('terrains');
    
    final batch = db.batch();
    for (var terrain in terrains) {
      final terrainData = terrain['terrain'] ?? {};
      final devise = terrain['devise'] ?? {};
      final address = terrain['address'] ?? {};
      final typeProperty = terrain['typeProperty'] ?? {};
      final images = terrain['images'] ?? [];
      
      batch.insert(
        'terrains',
        {
          'terrainId': terrainData['id'],
          'userId': terrainData['userId'],
          'title': terrainData['title'],
          'description': terrainData['description'],
          'price': terrainData['price'],
          'surface': terrainData['surface'],
          'transactionType': terrainData['transactionType'],
          'available': terrainData['available'] == true ? 1 : 0,
          'postBy': terrain['postBy'],
          'image': terrain['image'],
          'address': address['address'],
          'communeValue': address['communeValue'],
          'quartierValue': address['quartierValue'],
          'cityValue': address['cityValue'],
          'countryValue': address['countryValue'],
          'postalCode': address['postalCode'],
          'deviseId': devise['id'],
          'deviseName': devise['name'],
          'deviseCode': devise['code'],
          'deviseTauxLocal': devise['tauxLocal'],
          'propertyTypeId': typeProperty['propertyTypeId'],
          'propertyTypeName': typeProperty['name'],
          'images': images.map((img) => img['path']).join('|||'), // Store as delimited string
          'createdAt': terrainData['createdAt'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
    print('✅ [TerrainDatabaseHelper] Inserted ${terrains.length} terrains');
  }

  /// Get all terrains
  Future<List<Map<String, dynamic>>> getAllTerrains() async {
    final db = await instance.database;
    
    final result = await db.query('terrains', orderBy: 'terrainId DESC');

    print('📥 [TerrainDatabaseHelper] Found ${result.length} terrains');
    
    // Reconstruct the API response format
    return result.map((row) {
      final imagePaths = (row['images'] as String?)?.split('|||') ?? [];
      
      return {
        'terrain': {
          'id': row['terrainId'],
          'userId': row['userId'],
          'title': row['title'],
          'description': row['description'],
          'price': row['price'],
          'surface': row['surface'],
          'transactionType': row['transactionType'],
          'createdAt': row['createdAt'],
          'available': row['available'] == 1,
        },
        'devise': {
          'id': row['deviseId'],
          'name': row['deviseName'],
          'code': row['deviseCode'],
          'tauxLocal': row['deviseTauxLocal'],
        },
        'postBy': row['postBy'],
        'image': row['image'],
        'address': {
          'address': row['address'],
          'communeValue': row['communeValue'],
          'quartierValue': row['quartierValue'],
          'cityValue': row['cityValue'],
          'countryValue': row['countryValue'],
          'postalCode': row['postalCode'],
        },
        'localAddress': {
          'city': null,
          'commune': null,
          'quartier': null,
        },
        'geoZone': {
          'lat': 0.0,
          'lng': 0.0,
        },
        'images': imagePaths.map((path) => {'path': path}).toList(),
        'typeProperty': {
          'propertyTypeId': row['propertyTypeId'],
          'name': row['propertyTypeName'],
        },
      };
    }).toList();
  }

  /// Clear all terrains
  Future<void> clearTerrains() async {
    final db = await instance.database;
    await db.delete('terrains');
    print('🧹 [TerrainDatabaseHelper] All terrains cleared');
  }

  /// Close database
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
    print('🔒 [TerrainDatabaseHelper] Database closed');
  }
}
