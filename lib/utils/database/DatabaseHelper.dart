import 'package:casa/models/PropertyModel.dart';
import 'package:casa/models/SollicitationModel.dart';
import 'package:casa/models/ReservationModel.dart';
import 'package:casa/models/ServiceRequestModel.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class DatabaseHelper {
  static const _databaseName = "properties.db";
  static const _databaseVersion = 9;
  static const table = 'properties';
  static const tableBureaux = 'bureaux';
  static const tableFestives = 'festives';
  static const tableFuneraires = 'funeraires';
  static const tableVacances = 'vacances';
  static const tableHotels = 'hotels';
  static const tableHotelRooms = 'hotel_rooms';
  static const tableSolicitationsUser = 'solicitations_user';
  static const tableSolicitationsHost = 'solicitations_host';
  static const tableReservationsUser = 'reservations_user';
  static const tableReservationsHost = 'reservations_host';
  static const tableServiceRequests = 'service_requests';
  static const propertyTypesTable = 'property_types';
  static const featuresTable = 'features';

  static const columnId = 'id';
  static const columnData = 'data'; // Stockage JSON sérialisé
  
  // Property Types columns
  static const columnPropertyTypeId = 'propertyTypeId';
  static const columnName = 'name';
  static const columnDescription = 'description';
  static const columnUpdatedAt = 'updated_at';
  
  // Features columns
  static const columnFeatureId = 'featureId';

  // Singleton
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add property_types table
      await db.execute('''
        CREATE TABLE $propertyTypesTable (
          $columnPropertyTypeId INTEGER PRIMARY KEY,
          $columnName TEXT NOT NULL,
          $columnDescription TEXT,
          $columnUpdatedAt INTEGER NOT NULL
        )
      ''');
      
      // Add features table
      await db.execute('''
        CREATE TABLE $featuresTable (
          $columnFeatureId INTEGER PRIMARY KEY,
          $columnName TEXT NOT NULL,
          $columnUpdatedAt INTEGER NOT NULL
        )
      ''');
    }
    
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE $tableBureaux (
          $columnId INTEGER PRIMARY KEY,
          $columnData TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE $tableFestives (
          $columnId INTEGER PRIMARY KEY,
          $columnData TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE $tableFuneraires (
          $columnId INTEGER PRIMARY KEY,
          $columnData TEXT NOT NULL
        )
      ''');
    }
    
    if (oldVersion < 4) {
      // Add solicitations tables
      await db.execute('''
        CREATE TABLE $tableSolicitationsUser (
          $columnId INTEGER PRIMARY KEY,
          $columnData TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE $tableSolicitationsHost (
          $columnId INTEGER PRIMARY KEY,
          $columnData TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 5) {
      // Add reservations tables
      await db.execute('''
        CREATE TABLE $tableReservationsUser (
          $columnId INTEGER PRIMARY KEY,
          $columnData TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE $tableReservationsHost (
          $columnId INTEGER PRIMARY KEY,
          $columnData TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 6) {
      // Add service requests table
      await db.execute('''
        CREATE TABLE $tableServiceRequests (
          $columnId INTEGER PRIMARY KEY,
          $columnData TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE $tableHotels (
          $columnId INTEGER PRIMARY KEY,
          $columnData TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE $tableVacances (
          $columnId INTEGER PRIMARY KEY,
          $columnData TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE $tableHotelRooms (
          $columnId INTEGER PRIMARY KEY,
          $columnData TEXT NOT NULL
        )
      ''');
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableBureaux (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableFestives (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableFuneraires (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $tableSolicitationsUser (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSolicitationsHost (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableReservationsUser (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableReservationsHost (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableServiceRequests (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableHotels (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $tableVacances (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableHotelRooms (
        $columnId INTEGER PRIMARY KEY,
        $columnData TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $propertyTypesTable (
        $columnPropertyTypeId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnDescription TEXT,
        $columnUpdatedAt INTEGER NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $featuresTable (
        $columnFeatureId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnUpdatedAt INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertOrUpdateProperty(PropertyModel property) async {
    final db = await database;
    return await db.insert(
      table,
      {
        columnId: property.propertyId,
        columnData: json.encode(property.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PropertyModel>> getAllProperties() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(table);

    return maps.map((map) {
      final jsonData = json.decode(map[columnData]);
      return PropertyModel.fromJson(jsonData);
    }).toList();
  }

  Future<PropertyModel?> getPropertyById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final jsonData = json.decode(maps.first[columnData]);
      return PropertyModel.fromJson(jsonData);
    }
    return null;
  }

  Future<int> deleteProperty(int id) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearProperties() async {
    final db = await database;
    return await db.delete(table);
  }

  // Méthode pour insérer plusieurs propriétés en une seule transaction
  Future<void> insertMultipleProperties(List<PropertyModel> properties) async {
    final db = await database;
    final batch = db.batch();

    for (final property in properties) {
      batch.insert(
        table,
        {
          columnId: property.propertyId,
          columnData: json.encode(property.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  // Méthode pour vérifier si une propriété existe
  Future<bool> propertyExists(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // Méthode générique pour insérer ou mettre à jour dans n'importe quelle table de propriétés
  Future<int> insertOrUpdateInCategory(String tableName, PropertyModel property) async {
    final db = await database;
    return await db.insert(
      tableName,
      {
        columnId: property.propertyId,
        columnData: json.encode(property.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Cache une chambre d’hôtel (clé = chambreId).
  Future<int> insertOrUpdateHotelRoom(HotelRoomStructure structure) async {
    final id = structure.chambre?.id;
    if (id == null) return 0;
    final db = await database;
    return await db.insert(
      tableHotelRooms,
      {
        columnId: id,
        columnData: json.encode(structure.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Renvoie une chambre depuis le cache (par chambreId), sinon `null`.
  Future<HotelRoomStructure?> getHotelRoomById(int chambreId) async {
    final db = await database;
    final maps = await db.query(
      tableHotelRooms,
      where: '$columnId = ?',
      whereArgs: [chambreId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final raw = maps.first[columnData];
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw as String);
      if (decoded is Map) {
        return HotelRoomStructure.fromJson(Map<String, dynamic>.from(decoded));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Une entrée par id (liste ou détail hôtel / autre catégorie).
  Future<PropertyModel?> getCategoryPropertyById(String tableName, int id) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final raw = maps.first[columnData];
    if (raw == null) return null;
    try {
      return PropertyModel.fromJson(json.decode(raw as String));
    } catch (_) {
      return null;
    }
  }

  // Méthode générique pour récupérer les propriétés d'une table spécifique
  Future<List<PropertyModel>> getFromCategory(String tableName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);

    return maps.map((map) {
      final jsonData = json.decode(map[columnData]);
      return PropertyModel.fromJson(jsonData);
    }).toList();
  }

  // Méthode pour vider une catégorie spécifique
  Future<int> clearCategory(String tableName) async {
    final db = await database;
    return await db.delete(tableName);
  }

  Future<int> clearHotelRooms() async {
    final db = await database;
    return await db.delete(tableHotelRooms);
  }

  // Méthode pour compter le nombre de propriétés
  Future<int> getPropertiesCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $table')
    );
    return count ?? 0;
  }

  // ========== Property Types Methods ==========
  
  /// Insert or update multiple property types
  Future<void> insertPropertyTypes(List<Map<String, dynamic>> types) async {
    final db = await database;
    final batch = db.batch();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (final type in types) {
      batch.insert(
        propertyTypesTable,
        {
          columnPropertyTypeId: type['propertyTypeId'],
          columnName: type['name'],
          columnDescription: type['description'],
          columnUpdatedAt: timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all property types
  Future<List<Map<String, dynamic>>> getAllPropertyTypes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      propertyTypesTable,
      orderBy: '$columnPropertyTypeId ASC',
    );
    
    return maps.map((map) => {
      'propertyTypeId': map[columnPropertyTypeId],
      'name': map[columnName],
      'description': map[columnDescription],
    }).toList();
  }

  /// Clear all property types
  Future<int> clearPropertyTypes() async {
    final db = await database;
    return await db.delete(propertyTypesTable);
  }

  /// Get property types count
  Future<int> getPropertyTypesCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $propertyTypesTable')
    );
    return count ?? 0;
  }

  // ========== Features Methods ==========
  
  /// Insert or update multiple features
  Future<void> insertFeatures(List<Map<String, dynamic>> features) async {
    final db = await database;
    final batch = db.batch();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (final feature in features) {
      batch.insert(
        featuresTable,
        {
          columnFeatureId: feature['featureId'],
          columnName: feature['name'],
          columnUpdatedAt: timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all features
  Future<List<Map<String, dynamic>>> getAllFeatures() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      featuresTable,
      orderBy: '$columnFeatureId ASC',
    );
    
    return maps.map((map) => {
      'featureId': map[columnFeatureId],
      'name': map[columnName],
    }).toList();
  }

  /// Clear all features
  Future<int> clearFeatures() async {
    final db = await database;
    return await db.delete(featuresTable);
  }

  /// Get features count
  Future<int> getFeaturesCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $featuresTable')
    );
    return count ?? 0;
  }

  // ========== Solicitations Methods ==========

  /// Insert or update multiple user solicitations
  Future<void> insertMultipleUserSolicitations(List<SollicitationModel> solicitations) async {
    final db = await database;
    final batch = db.batch();

    for (final solicitation in solicitations) {
      batch.insert(
        tableSolicitationsUser,
        {
          columnId: solicitation.id,
          columnData: json.encode(solicitation.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all user solicitations
  Future<List<SollicitationModel>> getAllUserSolicitations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableSolicitationsUser);

    return maps.map((map) {
      final jsonData = json.decode(map[columnData]);
      return SollicitationModel.fromJson(jsonData);
    }).toList();
  }

  /// Clear user solicitations
  Future<int> clearUserSolicitations() async {
    final db = await database;
    return await db.delete(tableSolicitationsUser);
  }

  /// Insert or update multiple host solicitations
  Future<void> insertMultipleHostSolicitations(List<SollicitationModel> solicitations) async {
    final db = await database;
    final batch = db.batch();

    for (final solicitation in solicitations) {
      batch.insert(
        tableSolicitationsHost,
        {
          columnId: solicitation.id,
          columnData: json.encode(solicitation.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all host solicitations
  Future<List<SollicitationModel>> getAllHostSolicitations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableSolicitationsHost);

    return maps.map((map) {
      final jsonData = json.decode(map[columnData]);
      return SollicitationModel.fromJson(jsonData);
    }).toList();
  }

  /// Clear host solicitations
  Future<int> clearHostSolicitations() async {
    final db = await database;
    return await db.delete(tableSolicitationsHost);
  }

  // ========== Reservations Methods ==========

  /// Insert or update multiple user reservations
  Future<void> insertMultipleUserReservations(List<ReservationModel> reservations) async {
    final db = await database;
    final batch = db.batch();

    for (final reservation in reservations) {
      batch.insert(
        tableReservationsUser,
        {
          columnId: reservation.reservationId,
          columnData: json.encode(reservation.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all user reservations
  Future<List<ReservationModel>> getAllUserReservations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableReservationsUser);

    return maps.map((map) {
      final jsonData = json.decode(map[columnData]);
      return ReservationModel.fromJson(jsonData);
    }).toList();
  }

  /// Clear user reservations
  Future<int> clearUserReservations() async {
    final db = await database;
    return await db.delete(tableReservationsUser);
  }

  /// Insert or update multiple host reservations
  Future<void> insertMultipleHostReservations(List<ReservationModel> reservations) async {
    final db = await database;
    final batch = db.batch();

    for (final reservation in reservations) {
      batch.insert(
        tableReservationsHost,
        {
          columnId: reservation.reservationId,
          columnData: json.encode(reservation.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all host reservations
  Future<List<ReservationModel>> getAllHostReservations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableReservationsHost);

    return maps.map((map) {
      final jsonData = json.decode(map[columnData]);
      return ReservationModel.fromJson(jsonData);
    }).toList();
  }

  /// Clear host reservations
  Future<int> clearHostReservations() async {
    final db = await database;
    return await db.delete(tableReservationsHost);
  }

  // ========== Service Requests Methods ==========

  /// Insert or update multiple service requests
  Future<void> insertMultipleServiceRequests(List<ServiceRequestModel> requests) async {
    final db = await database;
    final batch = db.batch();

    for (final request in requests) {
      batch.insert(
        tableServiceRequests,
        {
          columnId: request.requestId,
          columnData: json.encode(request.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all service requests
  Future<List<ServiceRequestModel>> getAllServiceRequests() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableServiceRequests);

    return maps.map((map) {
      final jsonData = json.decode(map[columnData]);
      return ServiceRequestModel.fromJson(jsonData);
    }).toList();
  }

  /// Clear service requests
  Future<int> clearServiceRequests() async {
    final db = await database;
    return await db.delete(tableServiceRequests);
  }
}