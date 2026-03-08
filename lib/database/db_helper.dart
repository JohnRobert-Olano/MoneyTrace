import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';

class DBHelper {
  DBHelper._();
  static final DBHelper instance = DBHelper._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('moneytrace.db');
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
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        monthly_limit REAL NOT NULL
      )
    ''');
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getRecentExpenses(int limit) async {
    final db = await instance.database;
    final result = await db.query(
      'expenses',
      orderBy: 'date DESC',
      limit: limit,
    );
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<double> getMonthlyTotalBalance() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total 
      FROM expenses 
      WHERE date >= ?
    ''', [startOfMonth]);
    
    var total = result.first['total'];
    return total != null ? (total as num).toDouble() : 0.0;
  }

  Future<Map<String, double>> getWeeklyExpensesByCategory() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfWeek = now.subtract(const Duration(days: 7)).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total 
      FROM expenses 
      WHERE date >= ?
      GROUP BY category
    ''', [startOfWeek]);
    
    Map<String, double> categorySums = {};
    for (var row in result) {
      categorySums[row['category'] as String] = (row['total'] as num).toDouble();
    }
    return categorySums;
  }
}
