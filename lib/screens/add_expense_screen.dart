import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../database/db_helper.dart';
import '../models/expense.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController _inputController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _processExpense() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMessage = 'Please enter an expense description.');
      return;
    }

    // Retrieve the API key from the .env file securely
    final apiKey = dotenv.env['GEMINI_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_api_key_here') {
      setState(
        () => _errorMessage = 'API Key not found or invalid in .env file.',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.1, // Low temp for more deterministic parsing
        ),
      );

      final prompt =
          '''
You are a financial assistant extracting expense data from user text.
Analyze this text: "$input"

Return ONLY a strictly formatted JSON object with exactly these three keys:
- "amount": a double representing the cost (extract numbers, ignore currency symbols).
- "category": a short, general category string (e.g., "Food", "Transport", "Utilities", "Entertainment", "Shopping", "Other").
- "note": a short string describing the specific item or context.

Example output:
{"amount": 150.0, "category": "Food", "note": "Lunch at McDonald's"}
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text == null) {
        throw Exception('Failed to get a response from AI.');
      }

      final jsonResponse = jsonDecode(response.text!);

      final amount = (jsonResponse['amount'] as num).toDouble();
      final category = jsonResponse['category'] as String;
      final note = jsonResponse['note'] as String;

      final expense = Expense(
        amount: amount,
        category: category,
        date: DateTime.now(),
        note: note,
      );

      await DBHelper.instance.insertExpense(expense);

      if (mounted) {
        Navigator.pop(context); // Go back to Dashboard
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to parse expense: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Add Expense'),
          previousPageTitle: 'Back',
        ),
        child: SafeArea(
          child: Material(type: MaterialType.transparency, child: _buildBody()),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Expense'), elevation: 0),
        body: _buildBody(),
      );
    }
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Describe your expense',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'e.g., "Spent ₱150 on lunch at Jollibee" or "Paid ₱1200 for electricity bill"',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
            ),
          ),
          const SizedBox(height: 32),

          if (Theme.of(context).platform == TargetPlatform.iOS)
            CupertinoTextField(
              controller: _inputController,
              placeholder: 'Type your expense here...',
              maxLines: 4,
              minLines: 2,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.darkBackgroundGray,
                borderRadius: BorderRadius.circular(12),
              ),
              style: const TextStyle(color: Colors.white),
            )
          else
            TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: 'Type your expense here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
              maxLines: 4,
              minLines: 2,
            ),

          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
          ],

          const Spacer(),

          if (_isProcessing)
            Center(
              child: Theme.of(context).platform == TargetPlatform.iOS
                  ? const CupertinoActivityIndicator()
                  : const CircularProgressIndicator(),
            )
          else
            ElevatedButton(
              onPressed: _processExpense,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text(
                'Analyze & Save',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
