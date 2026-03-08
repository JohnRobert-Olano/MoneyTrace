import 'dart:async';
import 'dart:convert';
import 'package:flutter_gemma/flutter_gemma.dart';

/// LocalAIService is a singleton that manages the on-device Gemma LLM.
class LocalAIService {
  LocalAIService._internal();
  static final LocalAIService instance = LocalAIService._internal();

  bool _isReady = false;
  bool get isReady => _isReady;
  
  Completer<void>? _initCompleter;

  static const String modelAssetPath = 'assets/gemma-2b-it-gpu-int4.bin';
  static const String modelId = 'gemma-2b-it-gpu-int4.bin';

  // ── Model lifecycle ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isReady) return;
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    
    _initCompleter = Completer<void>();
    
    try {
      // flutter_gemma 0.12.5 requires setting the active inference model.
      // installModel().install() is idempotent, it skips the file copy if already installed
      // but correctly sets it as the active model for this session.
      await installFromAsset();
      _isReady = true;
      _initCompleter!.complete();
    } catch (e) {
      print('LocalAIService Init Error: $e');
      _initCompleter!.completeError(e);
    } finally {
      _initCompleter = null;
    }
  }

  /// Install the model from the bundled assets.
  Future<void> installFromAsset() async {
    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.binary,
    )
        .fromAsset(modelAssetPath)
        .install();
  }

  /// Download and install the Gemma 2B-IT model from Hugging Face.
  Future<void> installModel({
    required String hfToken,
    void Function(int progress)? onProgress,
  }) async {
    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.binary,
      ).fromNetwork(
        'https://huggingface.co/google/gemma-3-1b-it/resolve/main/gemma-3-1b-it-int4.task',
        token: hfToken,
      ).withProgress((p) {
        onProgress?.call(p);
      }).install();

    } catch (e) {
      print('Install Error: $e');
      rethrow;
    }
  }

  Future<bool> isModelInstalled() async {
    try {
      return await FlutterGemma.isModelInstalled(modelId);
    } catch (_) {
      return false;
    }
  }

  // ── Private inference helper ─────────────────────────────────────────────────

  Future<String> _runPrompt(String systemPrompt, String userText) async {
    if (!_isReady) await initialize();

    final model = await FlutterGemma.getActiveModel(
      maxTokens: 512,
      preferredBackend: PreferredBackend.gpu,
    );

    final chat = await model.createChat();
    // In 0.12.5, prepend system prompt manualy
    final formattedUserText = 'System: $systemPrompt\n\nUser: $userText';

    await chat.addQueryChunk(Message.text(
      text: formattedUserText,
      isUser: true,
    ));

    final response = await chat.generateChatResponse();
    await model.close();

    if (response is TextResponse) {
      return response.token;
    }
    return '';
  }

  // ── Typed parsing functions ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> parseExpense(String rawText) async {
    const systemPrompt =
        'Financial extractor. Return JSON: {amount: number, category: string, note: string}. Categories: Food, Transport, Utilities, Entertainment, Shopping, Other.';
    final raw = await _runPrompt(systemPrompt, 'Input: "$rawText"');
    return _extractJson(raw);
  }

  Future<Map<String, dynamic>> parseGoal(String rawText) async {
    const systemPrompt = 'Goal extractor. Return JSON: {title: string, target_amount: number}.';
    final raw = await _runPrompt(systemPrompt, 'Input: "$rawText"');
    return _extractJson(raw);
  }

  Future<Map<String, dynamic>> parseSubscription(String rawText) async {
    const systemPrompt = 'Subscription extractor. Return JSON: {name: string, amount: number, category: string, billing_date: number(1-31)}.';
    final raw = await _runPrompt(systemPrompt, 'Input: "$rawText"');
    return _extractJson(raw);
  }

  Future<Map<String, dynamic>> parseIncome(String rawText) async {
    const systemPrompt = 'Income extractor. Return JSON: {amount: number, source: string}.';
    final raw = await _runPrompt(systemPrompt, 'Input: "$rawText"');
    return _extractJson(raw);
  }

  Map<String, dynamic> _extractJson(String raw) {
    try {
      final jsonStart = raw.indexOf('{');
      final jsonEnd = raw.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return {};
      final jsonStr = raw.substring(jsonStart, jsonEnd + 1);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
