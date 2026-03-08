import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../database/db_helper.dart';
import '../models/goal.dart';
import '../services/local_ai_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  _GoalsScreenState createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<Goal> _goals = [];
  bool _isLoading = true;
  bool _isProcessingAI = false;
  
  final TextEditingController _textController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _textController.text = val.recognizedWords;
          }),
        );
      }
    }
  }

  void _stopListening() {
    if (_isListening) {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _loadData() async {
    final goals = await DBHelper.instance.getAllGoals();
    setState(() {
      _goals = goals;
      _isLoading = false;
    });
  }

  Future<void> _processGoalInput(String text) async {
    if (text.trim().isEmpty) return;
    
    setState(() => _isProcessingAI = true);

    try {
      final data = await LocalAIService.instance.parseGoal(text);
      
      final goal = Goal(
        title: data['title'] as String,
        targetAmount: (data['target_amount'] as num).toDouble(),
        savedAmount: 0.0,
      );

      await DBHelper.instance.insertGoal(goal);
      
      if (mounted) {
        _textController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Added Goal: ${goal.title} (on-device)')),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to parse goal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAI = false);
    }
  }

  void _showAddFundsModal(Goal goal) {
    final amountController = TextEditingController();

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
              Text(
                'Add Funds to ${goal.title}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount to Add (₱)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final amountToAdd = double.tryParse(amountController.text) ?? 0.0;
                  if (amountToAdd > 0) {
                    final updatedGoal = Goal(
                      id: goal.id,
                      title: goal.title,
                      targetAmount: goal.targetAmount,
                      savedAmount: goal.savedAmount + amountToAdd,
                    );
                    await DBHelper.instance.updateGoal(updatedGoal);
                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadData();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Funds'),
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
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Savings Goals'),
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
          title: const Text('Savings Goals'),
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

    final formatCurrency = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

    return Column(
      children: [
        Expanded(
          child: _goals.isEmpty
            ? const Center(child: Text("No savings goals set yet.", style: TextStyle(fontSize: 16)))
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _goals.length,
                itemBuilder: (context, index) {
                  final goal = _goals[index];
                  final progress = goal.targetAmount > 0 ? (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0) : 0.0;

                  return Dismissible(
                    key: Key('goal_${goal.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      if (goal.id != null) {
                        DBHelper.instance.deleteGoal(goal.id!);
                      }
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    goal.title,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: Colors.green),
                                  onPressed: () => _showAddFundsModal(goal),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              color: progress >= 1.0 ? Colors.green : Theme.of(context).colorScheme.primary,
                              minHeight: 12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(progress * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(color: progress >= 1.0 ? Colors.green : Colors.grey),
                                ),
                                Text(
                                  '${formatCurrency.format(goal.savedAmount)} / ${formatCurrency.format(goal.targetAmount)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
        ),
        
        // Input Area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: "E.g 'I want 50k for a Laptop'",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(128),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (val) => _processGoalInput(val),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTapDown: (_) => _startListening(),
                  onTapUp: (_) => _stopListening(),
                  onTapCancel: _stopListening,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.redAccent : Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _isProcessingAI 
                        ? const SizedBox(
                            width: 24, 
                            height: 24, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: _isProcessingAI ? null : () => _processGoalInput(_textController.text),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
