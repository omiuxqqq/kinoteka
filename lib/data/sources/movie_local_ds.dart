import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/movie.dart';

class MovieLocalDataSource {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kinoteka.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE movies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            year INTEGER NOT NULL,
            genre TEXT NOT NULL,
            rating REAL NOT NULL,
            is_watched INTEGER NOT NULL DEFAULT 0,
            poster_url TEXT,
            description TEXT
          )
        ''');
      },
    );
    return _database!;
  }

  Future<List<Movie>> getAllMovies() async {
    final db = await database;
    final maps = await db.query('movies', orderBy: 'id DESC');
    return maps.map((m) => Movie.fromMap(m)).toList();
  }

  Future<int> insertMovie(Movie movie) async {
    final db = await database;
    return db.insert('movies', movie.toMap());
  }

  Future<int> updateMovie(Movie movie) async {
    final db = await database;
    return db.update(
      'movies',
      movie.toMap(),
      where: 'id = ?',
      whereArgs: [movie.id],
    );
  }

  Future<int> deleteMovie(int id) async {
    final db = await database;
    return db.delete('movies', where: 'id = ?', whereArgs: [id]);
  }
}