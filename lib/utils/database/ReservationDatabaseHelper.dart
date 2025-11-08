import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/ReservationModel.dart';

class ReservationDatabaseHelper {
  static const _databaseName = "reservations.db";
  static const _databaseVersion = 1;
  static const table = 'reservations';

  static const columnId = 'id';
  static const columnUserId = 'userId';
  static const columnData = 'data';
  static const columnStatus = 'status';
  static const columnStartDate = 'startDate';
  static const columnEndDate = 'endDate';

  // Singleton
  ReservationDatabaseHelper._privateConstructor();
  static final ReservationDatabaseHelper instance = ReservationDatabaseHelper._privateConstructor();

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
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId TEXT PRIMARY KEY,
        $columnUserId TEXT NOT NULL,
        $columnData TEXT NOT NULL,
        $columnStatus TEXT NOT NULL,
        $columnStartDate TEXT NOT NULL,
        $columnEndDate TEXT NOT NULL
      )
    ''');

    // Création des index pour améliorer les performances
    await db.execute('''
      CREATE INDEX idx_user ON $table ($columnUserId)
    ''');
    await db.execute('''
      CREATE INDEX idx_status ON $table ($columnStatus)
    ''');
    await db.execute('''
      CREATE INDEX idx_dates ON $table ($columnStartDate, $columnEndDate)
    ''');
  }

  // Insérer ou mettre à jour une réservation
  Future<int> insertOrUpdateReservation(ReservationModel reservation, String userId) async {
    final db = await database;
    return await db.insert(
      table,
      {
        columnId: reservation.reservationId?.toString(),
        columnUserId: userId,
        columnData: reservationToJsonString(reservation),
        columnStatus: reservation.status ?? 'PENDING',
        columnStartDate: reservation.startDate ?? '',
        columnEndDate: reservation.endDate ?? '',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insérer ou mettre à jour plusieurs réservations
  Future<void> insertOrUpdateReservations(List<ReservationModel> reservations, String userId) async {
    final db = await database;
    final batch = db.batch();

    for (final reservation in reservations) {
      batch.insert(
        table,
        {
          columnId: reservation.reservationId?.toString(),
          columnUserId: userId,
          columnData: reservationToJsonString(reservation),
          columnStatus: reservation.status ?? 'PENDING',
          columnStartDate: reservation.startDate ?? '',
          columnEndDate: reservation.endDate ?? '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  // Récupérer toutes les réservations d'un utilisateur
  Future<List<ReservationModel>> getReservationsByUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnUserId = ?',
      whereArgs: [userId],
      orderBy: '$columnStartDate DESC',
    );

    return List.generate(maps.length, (i) {
      return reservationFromJsonString(maps[i][columnData]);
    });
  }

  // Récupérer les réservations par statut
  Future<List<ReservationModel>> getReservationsByStatus(String userId, String status) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnUserId = ? AND $columnStatus = ?',
      whereArgs: [userId, status],
      orderBy: '$columnStartDate DESC',
    );

    return List.generate(maps.length, (i) {
      return reservationFromJsonString(maps[i][columnData]);
    });
  }

  // Récupérer les réservations à venir
  Future<List<ReservationModel>> getUpcomingReservations(String userId) async {
    final db = await database;
    final currentDate = DateTime.now().toIso8601String().split('T')[0];

    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnUserId = ? AND $columnStartDate >= ?',
      whereArgs: [userId, currentDate],
      orderBy: '$columnStartDate ASC',
    );

    return List.generate(maps.length, (i) {
      return reservationFromJsonString(maps[i][columnData]);
    });
  }

  // Récupérer une réservation spécifique
  Future<ReservationModel?> getReservationById(String reservationId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnId = ?',
      whereArgs: [reservationId],
    );

    if (maps.isNotEmpty) {
      return reservationFromJsonString(maps.first[columnData]);
    }
    return null;
  }

  // Mettre à jour le statut d'une réservation
  Future<int> updateReservationStatus(String reservationId, String status) async {
    final db = await database;

    // D'abord récupérer la réservation existante
    final reservation = await getReservationById(reservationId);
    if (reservation != null) {
      reservation.status = status;

      return await db.update(
        table,
        {
          columnData: reservationToJsonString(reservation),
          columnStatus: status,
        },
        where: '$columnId = ?',
        whereArgs: [reservationId],
      );
    }
    return 0;
  }

  // Supprimer une réservation
  Future<int> deleteReservation(String reservationId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [reservationId],
    );
  }

  // Supprimer toutes les réservations d'un utilisateur
  Future<int> clearUserReservations(String userId) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnUserId = ?',
      whereArgs: [userId],
    );
  }

  // Supprimer les réservations par statut
  Future<int> deleteReservationsByStatus(String userId, String status) async {
    final db = await database;
    return await db.delete(
      table,
      where: '$columnUserId = ? AND $columnStatus = ?',
      whereArgs: [userId, status],
    );
  }

  // Compter le nombre de réservations
  Future<int> getReservationCount(String userId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $table WHERE $columnUserId = ?',
      [userId],
    ));
    return count ?? 0;
  }

  // Vérifier si une réservation existe
  Future<bool> reservationExists(String reservationId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $table WHERE $columnId = ?',
      [reservationId],
    ));
    return (count ?? 0) > 0;
  }

  // Méthodes utilitaires pour la conversion JSON
  String reservationToJsonString(ReservationModel reservation) {
    return json.encode(reservation.toJson());
  }

  ReservationModel reservationFromJsonString(String jsonString) {
    return ReservationModel.fromJson(json.decode(jsonString));
  }
}