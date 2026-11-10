import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  // â”€â”€ Init â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<Database> _init() async {
    final dbPath = join(await getDatabasesPath(), 'catat_keuangan.db');
    final db = await openDatabase(
      dbPath,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _ensureDefaultCategories(db);
    return db;
  }

  Future<void> _ensureDefaultCategories(Database db) async {
    final existing = await db.query(
      'categories',
      where: 'name = ? AND type = ?',
      whereArgs: ['Internet', 'expense'],
    );
    if (existing.isEmpty) {
      await db.insert('categories', {
        'name': 'Internet',
        'icon_code': Icons.wifi_rounded.codePoint,
        'color_value': 0xFF0284C7,
        'type': 'expense',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id  INTEGER NOT NULL,
          amount       INTEGER NOT NULL,
          month        INTEGER NOT NULL,
          year         INTEGER NOT NULL,
          created_at   INTEGER NOT NULL,
          UNIQUE (category_id, month, year)
        )
      ''');
    }
    if (oldV < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS debts (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          name        TEXT    NOT NULL,
          amount      INTEGER NOT NULL,
          type        TEXT    NOT NULL,
          due_date    INTEGER,
          notes       TEXT,
          is_paid     INTEGER NOT NULL DEFAULT 0,
          paid_at     INTEGER,
          created_at  INTEGER NOT NULL
        )
      ''');
    }
    if (oldV < 4) {
      await _ensureDefaultCategories(db);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table: categories
    await db.execute('''
      CREATE TABLE categories (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        name         TEXT    NOT NULL,
        icon_code    INTEGER NOT NULL,
        color_value  INTEGER NOT NULL,
        type         TEXT    NOT NULL,
        created_at   INTEGER NOT NULL
      )
    ''');

    // Table: transactions
    await db.execute('''
      CREATE TABLE transactions (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        title        TEXT    NOT NULL,
        amount       INTEGER NOT NULL,
        category_id  INTEGER,
        date         INTEGER NOT NULL,
        notes        TEXT,
        type         TEXT    NOT NULL,
        wallet       TEXT    NOT NULL DEFAULT 'Dompet Utama',
        created_at   INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // Table: budgets
    await db.execute('''
      CREATE TABLE budgets (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id  INTEGER NOT NULL,
        amount       INTEGER NOT NULL,
        month        INTEGER NOT NULL,
        year         INTEGER NOT NULL,
        created_at   INTEGER NOT NULL,
        UNIQUE (category_id, month, year)
      )
    ''');

    // Table: debts
    await db.execute('''
      CREATE TABLE debts (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        amount      INTEGER NOT NULL,
        type        TEXT    NOT NULL,
        due_date    INTEGER,
        notes       TEXT,
        is_paid     INTEGER NOT NULL DEFAULT 0,
        paid_at     INTEGER,
        created_at  INTEGER NOT NULL
      )
    ''');

    // Default categories
    await _seedCategories(db);
  }

  Future<void> _seedCategories(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const teal = 0xFF1A7A68;
    const blue = 0xFF2563EB;
    const purple = 0xFF7C3AED;
    const pink = 0xFFDB2777;
    const red = 0xFFDC2626;
    const amber = 0xFFD97706;
    const green = 0xFF16A34A;
    const cyan = 0xFF0891B2;

    final expenses = [
      ('Makanan',     Icons.restaurant_outlined.codePoint,     teal),
      ('Transportasi',Icons.directions_car_outlined.codePoint, blue),
      ('Belanja',     Icons.shopping_bag_outlined.codePoint,   purple),
      ('Internet',    Icons.wifi_rounded.codePoint,            0xFF0284C7),
      ('Kesehatan',   Icons.local_hospital_outlined.codePoint, red),
      ('Pendidikan',  Icons.school_outlined.codePoint,         amber),
      ('Rumah',       Icons.home_outlined.codePoint,           cyan),
      ('Hiburan',     Icons.movie_outlined.codePoint,          pink),
      ('Lainnya',     Icons.more_horiz_rounded.codePoint,      0xFF6B7280),
    ];

    final incomes = [
      ('Gaji',        Icons.attach_money_rounded.codePoint,    green),
      ('Bisnis',      Icons.business_center_outlined.codePoint,teal),
      ('Investasi',   Icons.savings_outlined.codePoint,        blue),
      ('Lainnya',     Icons.more_horiz_rounded.codePoint,      0xFF6B7280),
    ];

    for (final e in expenses) {
      await db.insert('categories', {
        'name': e.$1,
        'icon_code': e.$2,
        'color_value': e.$3,
        'type': 'expense',
        'created_at': now,
      });
    }
    for (final i in incomes) {
      await db.insert('categories', {
        'name': i.$1,
        'icon_code': i.$2,
        'color_value': i.$3,
        'type': 'income',
        'created_at': now,
      });
    }
  }

  // â”€â”€ Generic helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<int> insert(String table, Map<String, dynamic> row) async {
    final db = await database;
    return db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(String table, Map<String, dynamic> row) async {
    final db = await database;
    return db.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<int> delete(String table, int id) async {
    final db = await database;
    return db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    final db = await database;
    return db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? args,
  ]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }
}
