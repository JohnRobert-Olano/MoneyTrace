import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../database/db_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> _categories = [
    'Food',
    'Transport',
    'Utilities',
    'Entertainment',
    'Shopping',
    'Other'
  ];

  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    for (var cat in _categories) {
      _controllers[cat] = TextEditingController();
    }
    _loadExistingBudgets();
  }

  Future<void> _loadExistingBudgets() async {
    final budgets = await DBHelper.instance.getAllBudgets();
    for (var budget in budgets) {
      if (_controllers.containsKey(budget.category)) {
        _controllers[budget.category]?.text = budget.monthlyLimit.toString();
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveBudgets() async {
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    
    for (var category in _categories) {
      final text = _controllers[category]?.text.trim();
      if (text != null && text.isNotEmpty) {
        final amount = double.tryParse(text);
        if (amount != null) {
          await DBHelper.instance.upsertBudget(category, amount);
        }
      }
    }
    
    if (mounted) {
      Navigator.pop(context); // Go back to Dashboard and refresh
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Budget Settings'),
          previousPageTitle: 'Back',
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _saveBudgets,
            child: const Text('Save'),
          ),
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
          title: const Text('Budget Settings'),
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

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Define your monthly limit for each category. These limits power the Predictive Burn Rate warnings on your Dashboard.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        category,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Platform.isIOS
                          ? CupertinoTextField(
                              controller: _controllers[category],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              placeholder: 'Limit (₱)',
                              prefix: const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Text('₱'),
                              ),
                              style: const TextStyle(color: Colors.white),
                            )
                          : TextField(
                              controller: _controllers[category],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: '₱ ',
                                hintText: '0.00',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                isDense: true,
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (!Platform.isIOS)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveBudgets,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Budgets',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
