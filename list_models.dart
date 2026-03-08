import 'dart:convert';
import 'dart:io';

void main() async {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print('No API key found in environment variables.');
    return;
  }
  
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=\$apiKey');
  final request = await HttpClient().getUrl(url);
  final response = await request.close();
  
  final responseBody = await response.transform(utf8.decoder).join();
  if (response.statusCode == 200) {
    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final models = json['models'] as List<dynamic>;
    
    print('Available models for generateContent:');
    for (var model in models) {
      final name = model['name'];
      final supportedMethods = model['supportedGenerationMethods'] as List<dynamic>?;
      if (supportedMethods != null && supportedMethods.contains('generateContent')) {
        print('- \$name');
      }
    }
  } else {
    print('Failed to load models: \${response.statusCode}');
    print(responseBody);
  }
}
