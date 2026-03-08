import 'dart:convert';
import 'package:flutter/services.dart';

class DictionaryService {
  DictionaryService._internal();
  static final DictionaryService instance = DictionaryService._internal();

  Map<String, List<String>> _dictionary = {};
  Map<String, List<String>> get dictionary => _dictionary;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> initialize() async {
    if (_isLoaded) return;
    try {
      final jsonString = await rootBundle.loadString('assets/dictionary.json');
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

      _dictionary = jsonMap.map((key, value) {
        return MapEntry(key, List<String>.from(value));
      });
      _isLoaded = true;
    } catch (e) {
      print('Failed to load dictionary: $e');
    }
  }
}
