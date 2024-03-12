import 'package:flutter/foundation.dart';
import 'package:mynotes/services/auth/crud/crud_exceptios.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart'
    show MissingPlatformDirectoryException, getApplicationDocumentsDirectory;
import 'package:path/path.dart' show join;

class NoteService {
  Database? _db;
  Database get db {
    if (_db == null) throw DatabaseIsNotOpenException();
    return _db!;
  }

  set db(value) {
    if (_db != null && value != null) throw DatabaseAlreadyOpenException();
    _db = value;
  }

  Future<void> open() async {
    try {
      final docsPath = await getApplicationDocumentsDirectory();
      final dbPath = join(docsPath.path, dBname);
      db = await openDatabase(dbPath);

      await db.execute(createUserTable);
      await db.execute(createNoteTable);
    } on MissingPlatformDirectoryException {
      throw UnableToGetDocumentsDirectory();
    }
  }

  Future<void> close() async {
    await db.close();
    db = null;
  }

  Future<DatabaseNote> createNote(DatabaseUser owner) async {
    final DatabaseUser dbUser = await getUser(owner.email);
    if (dbUser != owner) {
      throw CouldNotFindUser();
    }
    const text = '';

    final int noteId = await db.insert(noteTable, {
      userIdColumn: dbUser.id,
      textColumn: text,
      isSyncedWithCloudColumn: 1
    });
    return DatabaseNote(
        id: noteId, text: text, isSyncedWithCloud: false, userId: dbUser.id);
  }

  Future<DatabaseNote> updateNote(DatabaseNote note, String text) async {
    getNote(note.id);
    final int updatedNotes = await db.update(noteTable, {textColumn: text},
        where: '$idColumn = ?', whereArgs: [note.id]);
    if (updatedNotes != 1) throw CouldNotUpdateNote();
    return getNote(note.id);
  }

  Future<DatabaseNote> getNote(int id) async {
    final notes =
        await db.query(noteTable, where: '$id = ?', limit: 1, whereArgs: [id]);
    if (notes.isEmpty) throw CouldNotFindNote();
    return DatabaseNote.fromRow(notes.first);
  }

  Future<Iterable<DatabaseNote>> getAllNotes() async {
    final dbNotes = await db.query(noteTable);
    return dbNotes.map((note) => DatabaseNote.fromRow(note));
  }

  Future<int> deleteAllNotes() async {
    return await db.delete(noteTable);
  }

  Future<void> deleteNote(DatabaseNote note) async {
    final notes = await db.query(noteTable,
        where: '$idColumn = ?', limit: 1, whereArgs: [note.id]);
    if (notes.isEmpty) throw CouldNotFindNote();

    await db.delete(noteTable, where: 'id = ?', whereArgs: [note.id]);
  }

  Future<DatabaseUser> createUser(String email) async {
    final List userFound = await db.query(userTable,
        where: 'email = ?', limit: 1, whereArgs: [email.toLowerCase()]);
    if (userFound.isNotEmpty) throw UserAlreadyExist();

    final int userId = await db.insert(userTable, {emailColumn: email});
    return DatabaseUser(id: userId, email: email);
  }

  Future<void> deleteUser(String email) async {
    final int deletedRows =
        await db.delete(userTable, where: 'email = ?', whereArgs: [
      email.toLowerCase(),
    ]);

    if (deletedRows != 1) throw CouldNotDeleteUserException();
  }

  Future<DatabaseUser> getUser(String email) async {
    final List results = await db.query(
      userTable,
      where: 'email = ?',
      limit: 1,
      whereArgs: [email.toLowerCase()],
    );
    if (results.isEmpty) throw CouldNotFindUser();
    return DatabaseUser.fromRow(results.first);
  }
}

@immutable
class DatabaseUser {
  final int id;
  final String email;

  const DatabaseUser({
    required this.id,
    required this.email,
  });

  DatabaseUser.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        email = map[emailColumn] as String;

  @override
  String toString() => 'User, id: $id email: $email';

  @override
  bool operator ==(covariant DatabaseUser other) {
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}

class DatabaseNote {
  final int id;
  final int userId;
  final String text;
  final bool isSyncedWithCloud;

  DatabaseNote(
      {required this.id,
      required this.userId,
      required this.text,
      required this.isSyncedWithCloud});

  DatabaseNote.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        userId = map[userIdColumn] as int,
        text = map[textColumn] as String,
        isSyncedWithCloud = (map[isSyncedWithCloudColumn] as int) == 1;

  @override
  bool operator ==(covariant DatabaseNote other) => other.id == id;
  @override
  String toString() =>
      'Note, id: $id\nuserId: $userId\nisSyncedWithCloud:\n$isSyncedWithCloud';

  @override
  int get hashCode => id.hashCode;
}

const String dBname = 'notes.db';
const String noteTable = 'note';
const String userTable = 'user';
const String idColumn = 'id';
const String userIdColumn = 'user_id';
const String emailColumn = 'email';
const String textColumn = 'text';
const String isSyncedWithCloudColumn = 'is_synced_with_cloud';

const String createUserTable = '''
  CREATE TABLE IF NOT EXIST "user" (
  "id"	INTEGER,
  "email"	TEXT NOT NULL UNIQUE,
  PRIMARY KEY("id" AUTOINCREMENT));
  ''';

const String createNoteTable = '''
  CREATE TABLE IF NOT EXIST "note" (
  "id"	INTEGER,
  "user_id"	INTEGER NOT NULL,
  "text"	TEXT,
  "is_synced_with_cloud"	INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY("id" AUTOINCREMENT),
  FOREIGN KEY("user_id") REFERENCES "user"("id"));
  ''';
