import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../database/db_helper.dart';
import '../models/subscription.dart';
import '../services/local_ai_service.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  _SubscriptionsScreenState createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  List<Subscription> _subscriptions = [];
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
    final subs = await DBHelper.instance.getAllSubscriptions();
    setState(() {
      _subscriptions = subs;
      _isLoading = false;
    });
  }

  Future<void> _processSubInput(String text) async {
    if (text.trim().isEmpty) return;
    
    setState(() => _isProcessingAI = true);

    try {
      final data = await LocalAIService.instance.parseSubscription(text);

      final sub = Subscription(
        name: data['name'] as String,
        amount: (data['amount'] as num).toDouble(),
        category: data['category'] as String,
        billingDate: (data['billing_date'] as num).toInt().clamp(1, 31),
      );

      await DBHelper.instance.insertSubscription(sub);
      
      if (mounted) {
        _textController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Added: ${sub.name} (on-device)')),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to parse subscription: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAI = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Subscriptions'),
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
          title: const Text('Subscriptions'),
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
          child: _subscriptions.isEmpty
            ? const Center(child: Text("No recurring subscriptions set.", style: TextStyle(fontSize: 16)))
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _subscriptions.length,
                itemBuilder: (context, index) {
                  final sub = _subscriptions[index];
                  final daySuffix = _getDaySuffix(sub.billingDate);

                  return Dismissible(
                    key: Key('sub_${sub.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      if (sub.id != null) {
                        DBHelper.instance.deleteSubscription(sub.id!);
                      }
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.event_repeat, color: Colors.white),
                        ),
                        title: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${sub.category} • Bills on the ${sub.billingDate}$daySuffix'),
                        trailing: Text(
                          formatCurrency.format(sub.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                      hintText: "E.g 'I pay 500 for Netflix on the 10th'",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(128),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (val) => _processSubInput(val),
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
                  onPressed: _isProcessingAI ? null : () => _processSubInput(_textController.text),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
}
