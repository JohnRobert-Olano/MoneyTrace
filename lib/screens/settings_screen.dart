import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';
import '../main.dart';
import '../services/local_ai_service.dart';
import 'onboarding_screen.dart';

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
  String _currentTheme = 'dark';
  bool _isAiInstalled = false;
  bool _isInstallingAi = false;
  int _aiInstallProgress = 0;

  @override
  void initState() {
    super.initState();
    for (var cat in _categories) {
      _controllers[cat] = TextEditingController();
    }
    _loadExistingBudgets();
    _loadTheme();
    _checkAiStatus();
  }

  Future<void> _checkAiStatus() async {
    final installed = await LocalAIService.instance.isModelInstalled();
    setState(() => _isAiInstalled = installed);
  }

  Future<void> _installAi() async {
    setState(() {
      _isInstallingAi = true;
      _aiInstallProgress = 0;
    });

    try {
      // For on-device Gemma, you typically need a HF token or download a .task file.
      // We'll use a placeholder or prompt the user if needed, but here we trigger the service.
      await LocalAIService.instance.installModel(
        hfToken: 'YOUR_HF_TOKEN_HERE', // User should ideally provide this or we use a direct URL
        onProgress: (p) => setState(() => _aiInstallProgress = p),
      );
      await _checkAiStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to install AI: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isInstallingAi = false);
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('themeMode') ?? 'dark';
    });
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

  Future<void> _updateTheme(String newTheme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', newTheme);
    setState(() => _currentTheme = newTheme);

    if (newTheme == 'light') {
      appThemeNotifier.value = ThemeMode.light;
    } else if (newTheme == 'system') {
      appThemeNotifier.value = ThemeMode.system;
    } else {
      appThemeNotifier.value = ThemeMode.dark;
    }
  }

  Future<void> _resetOnboarding() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        if (Platform.isIOS) {
          return CupertinoAlertDialog(
            title: const Text('Reset Onboarding?'),
            content: const Text('Are you sure? This will permanently delete your Initial Balance and force you to start over.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context, false),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset'),
              ),
            ],
          );
        } else {
          return AlertDialog(
            title: const Text('Reset Onboarding?'),
            content: const Text('Are you sure? This will permanently delete your Initial Balance and force you to start over.'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context, false),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset'),
              ),
            ],
          );
        }
      },
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasCompletedOnboarding', false);
      await DBHelper.instance.deleteInitialBalance();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  Future<void> _exportData() async {
    setState(() => _isLoading = true);
    
    try {
      final expenses = await DBHelper.instance.getAllExpenses();
      final incomes = await DBHelper.instance.getAllIncome();

      List<List<dynamic>> rows = [];
      // Header
      rows.add(["Type", "Amount", "Category/Source", "Date", "Note"]);

      for (var inc in incomes) {
        rows.add(["Income", inc.amount, inc.source, inc.date.toIso8601String(), ""]);
      }
      
      for (var exp in expenses) {
        rows.add(["Expense", exp.amount, exp.category, exp.date.toIso8601String(), exp.note]);
      }

      String csvData = const ListToCsvConverter().convert(rows);

      final directory = await getTemporaryDirectory();
      final String path = '${directory.path}/MoneyTrace_Export.csv';
      final File file = File(path);
      await file.writeAsString(csvData);

      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(path)],
          text: 'Here is your MoneyTrace data export.',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 24.0, left: 16.0, right: 16.0, bottom: 8.0),
          child: Text('AI Assistant (Gemma)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withAlpha(50))),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                   Row(
                    children: [
                      Icon(_isAiInstalled ? Icons.check_circle : Icons.error_outline, color: _isAiInstalled ? Colors.green : Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isAiInstalled ? 'AI Model Installed & Ready' : 'AI Model Missing',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isAiInstalled 
                      ? 'All features (Receipt scan, Goal parsing) are working offline.'
                      : 'You need to download the 1.5GB Gemma model once to enable offline AI features.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (!_isAiInstalled) ...[
                    const SizedBox(height: 16),
                    if (_isInstallingAi)
                      Column(
                        children: [
                          LinearProgressIndicator(value: _aiInstallProgress / 100, borderRadius: BorderRadius.circular(8)),
                          const SizedBox(height: 8),
                          Text('Downloading: $_aiInstallProgress%'),
                        ],
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _installAi,
                        icon: const Icon(Icons.download),
                        label: const Text('Download AI Model (Gemma)'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                  ]
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 24.0, left: 16.0, right: 16.0, bottom: 8.0),
          child: Text('Appearance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Platform.isIOS
              ? CupertinoSlidingSegmentedControl<String>(
                  groupValue: _currentTheme,
                  children: const {
                    'system': Text('System'),
                    'light': Text('Light'),
                    'dark': Text('Dark'),
                  },
                  onValueChanged: (val) {
                    if (val != null) _updateTheme(val);
                  },
                )
              : SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'system', label: Text('System'), icon: Icon(Icons.brightness_auto)),
                    ButtonSegment(value: 'light', label: Text('Light'), icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: 'dark', label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {_currentTheme},
                  onSelectionChanged: (Set<String> newSelection) {
                    _updateTheme(newSelection.first);
                  },
                ),
        ),
        const Divider(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Budgets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
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
        
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _exportData,
              icon: Icon(Icons.download, color: Theme.of(context).colorScheme.primary),
              label: Text(
                'Export Data as CSV',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 32.0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _resetOnboarding,
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              label: const Text(
                'Reset App Onboarding',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
