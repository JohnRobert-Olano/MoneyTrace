import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/expense.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Expense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final expenses = await DBHelper.instance.getAllExpenses();
    setState(() {
      _expenses = expenses;
      _isLoading = false;
    });
  }

  Future<void> _deleteExpense(Expense expense) async {
    if (expense.id != null) {
      await DBHelper.instance.deleteExpense(expense.id!);
      await _loadExpenses(); // Refresh list after deletion
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Transactions History'),
          previousPageTitle: 'Back',
        ),
        child: SafeArea(
          child: Material(
            type: MaterialType.transparency,
            child: _buildBody(),
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Transactions History'),
          elevation: 0,
        ),
        body: _buildBody(),
      );
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Platform.isIOS 
            ? const CupertinoActivityIndicator() 
            : const CircularProgressIndicator(),
      );
    }

    if (_expenses.isEmpty) {
      return const Center(
        child: Text('No transactions found.'),
      );
    }

    final formatCurrency = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final dateFormat = DateFormat('MMM dd, yyyy • h:mm a');

    return RefreshIndicator(
      onRefresh: _loadExpenses,
      child: ListView.builder(
        itemCount: _expenses.length,
        itemBuilder: (context, index) {
          final expense = _expenses[index];
          
          return Dismissible(
            key: Key(expense.id.toString()),
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
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                formatCurrency.format(expense.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.redAccent,
                ),
              ),
              isThreeLine: expense.note.isNotEmpty,
            ),
          );
        },
      ),
    );
  }
}
