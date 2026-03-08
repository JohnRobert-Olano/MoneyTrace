import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../models/budget.dart';
import '../models/income.dart';

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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
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

    await db.execute('''
      CREATE TABLE income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        source TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE income (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          source TEXT NOT NULL,
          date TEXT NOT NULL
        )
      ''');
    }
  }

  Future<int> insertIncome(Income income) async {
    final db = await instance.database;
    return await db.insert('income', income.toMap());
  }

  Future<double> getMonthlyTotalIncome() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total 
      FROM income 
      WHERE date >= ?
    ''', [startOfMonth]);
    
    var total = result.first['total'];
    return total != null ? (total as num).toDouble() : 0.0;
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

  Future<List<Expense>> getAllExpenses() async {
    final db = await instance.database;
    final result = await db.query(
      'expenses',
      orderBy: 'date DESC',
    );
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
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

  Future<double> getTotalMonthlyBudget() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT SUM(monthly_limit) as total FROM budgets');
    var total = result.first['total'];
    return total != null ? (total as num).toDouble() : 0.0;
  }

  Future<List<Budget>> getAllBudgets() async {
    final db = await instance.database;
    final result = await db.query('budgets');
    return result.map((json) => Budget.fromMap(json)).toList();
  }

  Future<void> upsertBudget(String category, double limit) async {
    final db = await instance.database;
    final existingParams = await db.query(
      'budgets',
      where: 'category = ?',
      whereArgs: [category],
    );

    if (existingParams.isNotEmpty) {
      // Update
      await db.update(
        'budgets',
        {'monthly_limit': limit},
        where: 'category = ?',
        whereArgs: [category],
      );
    } else {
      // Insert
      await db.insert('budgets', {
        'category': category,
        'monthly_limit': limit,
      });
    }
  }

  Future<double> getProjectedMonthlySpend() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    
    // Get total spent so far this month
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total 
      FROM expenses 
      WHERE date >= ?
    ''', [startOfMonth]);
    
    var totalSpent = result.first['total'];
    if (totalSpent == null) return 0.0;
    
    double spent = (totalSpent as num).toDouble();
    
    // Calculate days passed and total days
    int daysPassed = now.day;
    int totalDays = DateTime(now.year, now.month + 1, 0).day; // Last day of month
    
    // Predictive math: (spent / days_passed) * total_days
    double averageDailySpend = spent / daysPassed;
    return averageDailySpend * totalDays;
  }
}
