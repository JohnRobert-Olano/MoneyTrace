import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:image_picker/image_picker.dart';
import '../database/db_helper.dart';
import '../models/expense.dart';
import '../services/local_ai_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController _inputController = TextEditingController();
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  XFile? _selectedImage;
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _processExpense() async {
    final input = _inputController.text.trim();
    if (input.isEmpty && _selectedImage == null) {
      setState(() => _errorMessage = 'Please enter a description or take a receipt photo.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      String textToAnalyze = input;

      // If an image was selected, run ML Kit OCR first to extract the text
      if (_selectedImage != null) {
        final textRecognizer = TextRecognizer();
        final inputImage = InputImage.fromFilePath(_selectedImage!.path);
        final recognized = await textRecognizer.processImage(inputImage);
        await textRecognizer.close(); // Free memory immediately
        textToAnalyze = recognized.text.isNotEmpty ? recognized.text : input;
      }

      // Run on-device Gemma parsing
      final data = await LocalAIService.instance.parseExpense(textToAnalyze);

      final amount = (data['amount'] as num).toDouble();
      final category = data['category'] as String;
      final note = data['note'] as String;

      final expense = Expense(
        amount: amount,
        category: category,
        date: DateTime.now(),
        note: note,
      );

      await DBHelper.instance.insertExpense(expense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Processed securely on-device')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to parse expense: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (val) => setState(() {
            _inputController.text = val.recognizedWords;
          }),
        );
      }
    }
  }

  void _stopListening() {
    if (_isListening) {
      setState(() => _isListening = false);
      _speechToText.stop();
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
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
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
                  ),
                ),
                GestureDetector(
                  onTapDown: (_) => _startListening(),
                  onTapUp: (_) => _stopListening(),
                  onTapCancel: _stopListening,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Column(
                      children: [
                        Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        Text('Hold to speak', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
              ],
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
                suffixIcon: GestureDetector(
                  onTapDown: (_) => _startListening(),
                  onTapUp: (_) => _stopListening(),
                  onTapCancel: _stopListening,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : Theme.of(context).colorScheme.primary,
                        ),
                        Text('Hold to speak', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
              ),
              maxLines: 4,
              minLines: 2,
            ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.camera_alt),
                color: Theme.of(context).colorScheme.primary,
                iconSize: 32,
                onPressed: () => _pickImage(ImageSource.camera),
              ),
              IconButton(
                icon: const Icon(Icons.photo_library),
                color: Theme.of(context).colorScheme.primary,
                iconSize: 32,
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
          if (_selectedImage != null) ...[
            const SizedBox(height: 16),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_selectedImage!.path),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    onPressed: () => setState(() => _selectedImage = null),
                  ),
                ),
              ],
            ),
          ],
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
