import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  Map<String, double> _categoryData = {};
  Map<int, double> _dailyData = {};
  double _totalSpent = 0.0;

  final List<Color> _chartColors = [
    const Color(0xFF3D5AFE), // Royal Blue
    const Color(0xFF00E676), // Lime Green
    Colors.amber,
    Colors.purpleAccent,
    Colors.redAccent,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final catData = await DBHelper.instance.getMonthlyExpensesByCategory();
    final dailyData = await DBHelper.instance.getDailyExpensesForMonth();

    double total = 0.0;
    catData.forEach((_, value) => total += value);

    setState(() {
      _categoryData = catData;
      _dailyData = dailyData;
      _totalSpent = total;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Monthly Analytics'),
          previousPageTitle: 'Back',
        ),
        child: SafeArea(
          child: Material(type: MaterialType.transparency, child: _buildBody()),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('Monthly Analytics'), elevation: 0),
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

    if (_categoryData.isEmpty) {
      return const Center(
        child: Text(
          "No expenses recorded this month yet.",
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Expense Breakdown',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Total spent",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.currency(
                        locale: 'en_PH',
                        symbol: '₱',
                      ).format(_totalSpent),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "This month",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                PieChart(
                  PieChartData(
                    sectionsSpace: 6,
                    centerSpaceRadius: 90,
                    sections: _buildPieChartSections(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildLegend(),
          const Divider(height: 48),
          const Text(
            'Daily Spending Trend',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          SizedBox(height: 250, child: _buildLineChart()),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    int colorIndex = 0;
    return _categoryData.entries.map((entry) {
      final color = _chartColors[colorIndex % _chartColors.length];
      colorIndex++;
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '', // Hide title for clean donut look
        radius: 20,
      );
    }).toList();
  }

  Widget _buildLegend() {
    int colorIndex = 0;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: _categoryData.entries.map((entry) {
        final color = _chartColors[colorIndex % _chartColors.length];
        colorIndex++;

        final percentage = _totalSpent > 0
            ? (entry.value / _totalSpent) * 100
            : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.key}  ${percentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLineChart() {
    if (_dailyData.isEmpty) return const SizedBox();

    int daysInMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month + 1,
      0,
    ).day;
    double maxSpend = 0.0;

    List<FlSpot> spots = [];
    for (int day = 1; day <= daysInMonth; day++) {
      double amount = _dailyData[day] ?? 0.0;
      if (amount > maxSpend) maxSpend = amount;
      spots.add(FlSpot(day.toDouble(), amount));
    }

    if (maxSpend == 0.0) maxSpend = 100.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: maxSpend / 4 > 0 ? maxSpend / 4 : 1,
          verticalInterval: 5,
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withAlpha(50)),
        ),
        minX: 1,
        maxX: daysInMonth.toDouble(),
        minY: 0,
        maxY: maxSpend * 1.2, // 20% headroom
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withAlpha(50),
            ),
          ),
        ],
      ),
    );
  }
}
