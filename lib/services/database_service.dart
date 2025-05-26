import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/document_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('documents.db');
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

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
    CREATE TABLE documents (
      id $idType,
      imagePath $textType,
      paperSize $textType,
      fontSize $realType,
      topMargin $realType,
      bottomMargin $realType,
      leftMargin $realType,
      rightMargin $realType,
      createdAt $integerType
    )
    ''');
  }

  Future<int> createDocument(DocumentAnalysis document) async {
    final db = await instance.database;
    return await db.insert('documents', document.toMap());
  }

  Future<List<DocumentAnalysis>> getAllDocuments() async {
    final db = await instance.database;
    const orderBy = 'createdAt DESC';
    final result = await db.query('documents', orderBy: orderBy);

    return result.map((json) => DocumentAnalysis.fromMap(json)).toList();
  }

  Future<DocumentAnalysis?> getDocument(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      return DocumentAnalysis.fromMap(result.first);
    }
    return null;
  }

  Future<void> deleteDocument(int id) async {
    final db = await instance.database;
    await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}