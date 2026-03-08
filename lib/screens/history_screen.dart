import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/expense.dart';
import '../models/income.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Expense> _expenses = [];
  List<Income> _incomes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final expenses = await DBHelper.instance.getAllExpenses();
    final incomes = await DBHelper.instance.getAllIncome();
    setState(() {
      _expenses = expenses;
      _incomes = incomes;
      _isLoading = false;
    });
  }

  Future<void> _deleteExpense(Expense expense) async {
    if (expense.id != null) {
      await DBHelper.instance.deleteExpense(expense.id!);
      await _loadData();
    }
  }

  Future<void> _deleteIncome(Income income) async {
    if (income.id != null) {
      await DBHelper.instance.deleteIncome(income.id!);
      await _loadData();
    }
  }

  void _showEditExpenseModal(Expense expense) {
    final amountController = TextEditingController(text: expense.amount.toString());
    final categoryController = TextEditingController(text: expense.category);
    final noteController = TextEditingController(text: expense.note);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Edit Expense',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final newAmount = double.tryParse(amountController.text) ?? expense.amount;
                  final newCategory = categoryController.text.trim();
                  final newNote = noteController.text.trim();

                  final updatedExpenseData = {
                    'id': expense.id,
                    'amount': newAmount,
                    'category': newCategory.isNotEmpty ? newCategory : expense.category,
                    'note': newNote,
                    'date': expense.date.toIso8601String(),
                  };

                  await DBHelper.instance.updateExpense(updatedExpenseData);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadData(); // Refresh UI
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('Save Changes'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showEditIncomeModal(Income income) {
    final amountController = TextEditingController(text: income.amount.toString());
    final sourceController = TextEditingController(text: income.source);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Edit Income',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: sourceController,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final newAmount = double.tryParse(amountController.text) ?? income.amount;
                  final newSource = sourceController.text.trim();

                  final updatedIncomeData = {
                    'id': income.id,
                    'amount': newAmount,
                    'source': newSource.isNotEmpty ? newSource : income.source,
                    'date': income.date.toIso8601String(),
                  };

                  await DBHelper.instance.updateIncome(updatedIncomeData);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadData(); // Refresh UI
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Changes'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return DefaultTabController(
        length: 2,
        child: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Transactions History'),
            previousPageTitle: 'Back',
          ),
          child: SafeArea(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: "Expenses"),
                      Tab(text: "Income"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildExpensesTab(),
                        _buildIncomeTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Transactions History'),
            elevation: 0,
            bottom: const TabBar(
              tabs: [
                Tab(text: "Expenses"),
                Tab(text: "Income"),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildExpensesTab(),
              _buildIncomeTab(),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildExpensesTab() {
    if (_isLoading) {
      return Center(
        child: Platform.isIOS 
            ? const CupertinoActivityIndicator() 
            : const CircularProgressIndicator(),
      );
    }

    if (_expenses.isEmpty) {
      return const Center(
        child: Text('No expenses found.'),
      );
    }

    final formatCurrency = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final dateFormat = DateFormat('MMM dd, yyyy • h:mm a');

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _expenses.length,
        itemBuilder: (context, index) {
          final expense = _expenses[index];
          
          return Dismissible(
            key: Key('exp_${expense.id.toString()}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.redAccent,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) {
              _deleteExpense(expense);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Expense deleted')),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: ListTile(
                onTap: () => _showEditExpenseModal(expense),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  expense.category,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    if (expense.note.isNotEmpty) Text(expense.note),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(expense.date),
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                    ),
                  ],
                ),
                trailing: Text(
                  '- ${formatCurrency.format(expense.amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                isThreeLine: expense.note.isNotEmpty,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIncomeTab() {
    if (_isLoading) {
      return Center(
        child: Platform.isIOS 
            ? const CupertinoActivityIndicator() 
            : const CircularProgressIndicator(),
      );
    }

    if (_incomes.isEmpty) {
      return const Center(
        child: Text('No income found.'),
      );
    }

    final formatCurrency = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final dateFormat = DateFormat('MMM dd, yyyy • h:mm a');

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _incomes.length,
        itemBuilder: (context, index) {
          final income = _incomes[index];
          
          return Dismissible(
            key: Key('inc_${income.id.toString()}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.redAccent,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) {
              _deleteIncome(income);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Income deleted')),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: ListTile(
                onTap: () => _showEditIncomeModal(income),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.green,
                  ),
                ),
                title: Text(
                  income.source,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    dateFormat.format(income.date),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                  ),
                ),
                trailing: Text(
                  '+ ${formatCurrency.format(income.amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
