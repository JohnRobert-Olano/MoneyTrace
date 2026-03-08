import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/expense.dart';
import 'add_expense_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _monthlyTotal = 0.0;
  List<Expense> _recentExpenses = [];
  Map<String, double> _weeklyCategoryData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final db = DBHelper.instance;
    
    final total = await db.getMonthlyTotalBalance();
    final recent = await db.getRecentExpenses(5);
    final categoryData = await db.getWeeklyExpensesByCategory();

    setState(() {
      _monthlyTotal = total;
      _recentExpenses = recent;
      _weeklyCategoryData = categoryData;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Dashboard'),
        ),
        child: SafeArea(
          child: Material(
            type: MaterialType.transparency,
            child: _buildBody(context),
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          elevation: 0,
        ),
        body: _buildBody(context),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
            ).then((_) => _loadDashboardData()); // Refresh on return
          },
          child: const Icon(Icons.add),
        ),
      );
    }
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Platform.isIOS 
            ? const CupertinoActivityIndicator() 
            : const CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHeroSection(),
          const SizedBox(height: 32),
          _buildPieChartSection(),
          const SizedBox(height: 32),
          _buildRecentTransactions(),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final formatCurrency = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Monthly Balance',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(204),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrency.format(_monthlyTotal),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection() {
    if (_weeklyCategoryData.isEmpty) {
      return const Center(child: Text('No expenses this week.'));
    }

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;
    final colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal
    ];

    _weeklyCategoryData.forEach((category, amount) {
      sections.add(
        PieChartSectionData(
          color: colors[colorIndex % colors.length],
          value: amount,
          title: category,
          radius: 50,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        )
      );
      colorIndex++;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This Week\'s Expenses',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    final formatCurrency = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Transactions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_recentExpenses.isEmpty)
          const Text('No recent transactions.'),
        ..._recentExpenses.map((expense) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.receipt),
              ),
              title: Text(expense.category),
              subtitle: Text(dateFormat.format(expense.date)),
              trailing: Text(
                formatCurrency.format(expense.amount),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          );
        }),
      ],
    );
  }
}
