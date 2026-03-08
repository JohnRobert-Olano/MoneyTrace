import 'dart:convert';
import 'dart:io';

void main() async {
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  String apiKey = '';
  for (final line in lines) {
    if (line.startsWith('GEMINI_API_KEY=')) {
      apiKey = line.substring('GEMINI_API_KEY='.length).trim();
      break;
    }
  }
  
  if (apiKey.isEmpty) {
    print('No API key found in .env');
    return;
  }
  print('Found API Key: \${apiKey.substring(0, 5)}...');
  
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
