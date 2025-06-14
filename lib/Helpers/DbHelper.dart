// import 'package:path/path.dart';
// import 'package:sqflite/sqflite.dart';
//
// import '../Model/MeetingModel.dart';
//
// class DatabaseHelper {
//   static Database? _database;
//   static const String tableName = 'meetings';
//
//   // Singleton pattern: Open database only once
//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await initDatabase();
//     return _database!;
//   }
//
//   // Initialize the database
//   Future<Database> initDatabase() async {
//     String path = join(await getDatabasesPath(), 'meetings.db');
//     return await openDatabase(
//       path,
//       version: 2,  // Increment version to trigger migration if needed
//       onCreate: (db, version) async {
//         // Create the table
//         await db.execute('''
//           CREATE TABLE $tableName(
//             id INTEGER PRIMARY KEY AUTOINCREMENT,
//             meetingName TEXT,
//             bmId TEXT,
//             meetingDate TEXT,
//             meetingTime TEXT,
//             notes TEXT
//           )
//         ''');
//       },
//       onUpgrade: (db, oldVersion, newVersion) async {
//         if (oldVersion < 2) {
//           // If the schema is from version 1, add the missing bmId column
//           await db.execute('''
//             ALTER TABLE $tableName ADD COLUMN bmId TEXT;
//           ''');
//         }
//       },
//     );
//   }
//
//   // Insert a meeting into the database
//   Future<int> insertMeeting(MeetingData meeting) async {
//     final db = await database;
//     return await db.insert(
//       tableName,
//       meeting.toMap(),
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }
//
//   Future<int> deleteMeetingById(int id) async {
//     final db = await database;
//     // The 'id' is the primary key, and we delete the row that matches the provided ID
//     return await db.delete(
//       tableName,
//       where: 'id = ?', // Condition to match the row to be deleted
//       whereArgs: [id], // Arguments for the condition (in this case, the id)
//     );
//   }
//
//   // Retrieve all meetings from the database for a given bmId
//   Future<List<MeetingData>> getMeetings(String bmId) async {
//     final db = await database;
//     final List<Map<String, dynamic>> maps = await db.query(
//       tableName,
//       where: 'bmId = ?',
//       whereArgs: [bmId],
//     );
//
//     return List.generate(maps.length, (i) {
//       return MeetingData.fromMap(maps[i]);
//     });
//   }
// }
