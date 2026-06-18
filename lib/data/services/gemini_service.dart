import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/city.dart';

class GeminiService {
  ChatSession? _chatSession;
  String? _apiKey;

  Future<void> _ensureApiKey() async {
    if (_apiKey != null && _apiKey!.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('gemini_api_key');
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Gemini API key is not set. Please set it in Auth screen.');
    }
  }

  Future<void> initChat() async {
    await _ensureApiKey();

    final model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: _apiKey!,
      systemInstruction: Content.system(
        'You are an expert local travel guide for a specific place. '
        'Answer user questions in a friendly, accurate, and brief manner. '
        'Keep responses concise and informative. If users ask about attractions '
        'or what to see, suggest relevant places and guide them there with a '
        'short reason for each recommendation. Adapt suggestions to the user\'s '
        'interests when possible, and avoid making up information.',
      ),
    );
    _chatSession = model.startChat();
  }

  Future<String> sendMessage(String message) async {
    if (_chatSession == null) {
      await initChat();
    }

    try {
      final response = await _chatSession!.sendMessage(Content.text(message));
      final rawText = response.text ?? 'No response from Gemini.';
      return _stripMarkdown(rawText);
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  String _stripMarkdown(String text) {
    String stripped = text.replaceAll(RegExp(r'\*\*|\*|__'), '');
    stripped = stripped.replaceAll(RegExp(r'#+\s'), '');
    return stripped.trim();
  }

  Future<List<City>> getPlaces(String query) async {
    await _ensureApiKey();

    final model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: _apiKey!,
    );

    final prompt = '''
    I need you to act as a travel guide API. 
    The user will ask for places (e.g., "$query").
    
    You must return a JSON object with a key "places" which is a list.
    Each item in the list should have:
    - "name": The name of the place
    - "latitude": The latitude (double)
    - "longitude": The longitude (double)
    - "description": A short, interesting description (max 2 sentences)
    - "imageUrl": A URL to a high-quality public image of the place (Wikipedia or similar stable URL).

    Return ONLY the raw JSON. Do not include markdown formatting like ```json ... ```.
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final text = response.text;

      if (text == null) {
        throw Exception('No response from Gemini');
      }

      String jsonString = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> data = json.decode(jsonString);
      final List<dynamic> placesJson = data['places'];

      final List<City> cities = [];
      for (var place in placesJson) {
        cities.add(City(
          name: place['name'],
          latitude: (place['latitude'] as num).toDouble(),
          longitude: (place['longitude'] as num).toDouble(),
          description: place['description'],
          imageUrl: place['imageUrl'] ?? '',
        ));
      }

      return cities;
    } catch (e) {
      throw Exception('Failed to fetch recommendations: $e');
    }
  }
}
