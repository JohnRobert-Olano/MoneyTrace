import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../models/budget.dart';
import '../models/income.dart';
import '../models/goal.dart';
import '../models/subscription.dart';

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
      version: 3,
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

    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        target_amount REAL NOT NULL,
        saved_amount REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE subscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        billing_date INTEGER NOT NULL,
        last_processed_date TEXT
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
    
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          target_amount REAL NOT NULL,
          saved_amount REAL NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE subscriptions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          billing_date INTEGER NOT NULL,
          last_processed_date TEXT
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

  Future<List<Income>> getAllIncome() async {
    final db = await instance.database;
    final result = await db.query(
      'income',
      orderBy: 'date DESC',
    );
    return result.map((json) => Income.fromMap(json)).toList();
  }

  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteIncome(int id) async {
    final db = await instance.database;
    return await db.delete(
      'income',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteInitialBalance() async {
    final db = await instance.database;
    return await db.delete(
      'income',
      where: 'source = ?',
      whereArgs: ['Initial Balance'],
    );
  }

  Future<int> updateExpense(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update(
      'expenses',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateIncome(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update(
      'income',
      row,
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

  Future<Map<String, double>> getMonthlyExpensesByCategory() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total 
      FROM expenses 
      WHERE date >= ?
      GROUP BY category
    ''', [startOfMonth]);
    
    Map<String, double> categorySums = {};
    for (var row in result) {
      categorySums[row['category'] as String] = (row['total'] as num).toDouble();
    }
    return categorySums;
  }

  Future<Map<int, double>> getDailyExpensesForMonth() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT date, amount 
      FROM expenses 
      WHERE date >= ?
    ''', [startOfMonth]);
    
    // Group by day of month (1-31)
    Map<int, double> dailySums = {};
    for (var row in result) {
      DateTime rowDate = DateTime.parse(row['date'] as String);
      int day = rowDate.day;
      double amount = (row['amount'] as num).toDouble();
      dailySums[day] = (dailySums[day] ?? 0) + amount;
    }
    return dailySums;
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

  // --- GOALS CRUD ---

  Future<int> insertGoal(Goal goal) async {
    final db = await instance.database;
    return await db.insert('goals', goal.toMap());
  }

  Future<List<Goal>> getAllGoals() async {
    final db = await instance.database;
    final result = await db.query('goals');
    return result.map((json) => Goal.fromMap(json)).toList();
  }

  Future<int> updateGoal(Goal goal) async {
    final db = await instance.database;
    return await db.update(
      'goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteGoal(int id) async {
    final db = await instance.database;
    return await db.delete(
      'goals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- SUBSCRIPTIONS CRUD & LOGIC ---

  Future<int> insertSubscription(Subscription sub) async {
    final db = await instance.database;
    return await db.insert('subscriptions', sub.toMap());
  }

  Future<List<Subscription>> getAllSubscriptions() async {
    final db = await instance.database;
    final result = await db.query('subscriptions');
    return result.map((json) => Subscription.fromMap(json)).toList();
  }

  Future<int> updateSubscription(Subscription sub) async {
    final db = await instance.database;
    return await db.update(
      'subscriptions',
      sub.toMap(),
      where: 'id = ?',
      whereArgs: [sub.id],
    );
  }

  Future<int> deleteSubscription(int id) async {
    final db = await instance.database;
    return await db.delete(
      'subscriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> processDueSubscriptions() async {
    final subs = await getAllSubscriptions();
    final now = DateTime.now();

    for (var sub in subs) {
      if (sub.lastProcessedDate == null) {
        // Initialize newly created subscriptions to start billing from next cycle
        sub.lastProcessedDate = now;
        await updateSubscription(sub);
      } else {
        DateTime nextBilling = DateTime(
          sub.lastProcessedDate!.year,
          sub.lastProcessedDate!.month + 1,
          sub.billingDate,
        );

        while (now.isAfter(nextBilling) || now.isAtSameMomentAs(nextBilling)) {
          // Log automated expense
          await insertExpense(Expense(
            amount: sub.amount,
            category: sub.category,
            note: 'Auto-payment: ${sub.name}',
            date: nextBilling,
          ));

          sub.lastProcessedDate = nextBilling;
          await updateSubscription(sub);

          // Prepare for next loop evaluation
          nextBilling = DateTime(
            nextBilling.year,
            nextBilling.month + 1,
            sub.billingDate,
          );
        }
      }
    }
  }
}
