import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/nutrition_models.dart';

class NutritionService {
  NutritionService._();

  /// Analyzes food image bytes and returns nutrition breakdown
  static Future<NutritionAnalysisResult> analyzeFoodImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final base64Image = base64Encode(imageBytes);

    // Try primary endpoint POST /api/nutrition/analyze
    final url = Uri.parse('$kServerUrl/api/nutrition/analyze');

    http.Response response;
    try {
      response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'image': base64Image,
              'mimeType': mimeType,
            }),
          )
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      debugPrint('Nutrition analyze direct error, trying action fallback: $e');
      // Fallback endpoint POST /api/analyzeNutrition
      try {
        final fallbackUrl = Uri.parse('$kServerUrl/api/analyzeNutrition');
        response = await http
            .post(
              fallbackUrl,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'image': base64Image,
                'mimeType': mimeType,
              }),
            )
            .timeout(const Duration(seconds: 25));
      } catch (err) {
        throw Exception("Server bilan bog'lanib bo'lmadi. Internet aloqasini tekshiring.");
      }
    }

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return NutritionAnalysisResult.fromJson(data);
      } catch (e) {
        throw Exception("Server javobini o'qib bo'lmadi: $e");
      }
    } else if (response.statusCode == 422) {
      // Non-food detected
      try {
        final body = jsonDecode(response.body) as Map;
        throw Exception(body['error'] ?? "Rasmda ovqat aniqlanmadi.");
      } catch (e) {
        throw Exception("Rasmda ovqat aniqlanmadi. Iltimos, taomning aniq rasmini yuklang.");
      }
    } else if (response.statusCode == 413) {
      throw Exception("Rasm hajmi juda katta (maksimal 10 MB).");
    } else {
      try {
        final body = jsonDecode(response.body) as Map;
        throw Exception(body['error'] ?? "Taom tahlilida xatolik yuz berdi (${response.statusCode})");
      } catch (e) {
        throw Exception("Taom tahlilida xatolik yuz berdi (${response.statusCode})");
      }
    }
  }

  /// Demo / Sinov uchun taomlar generatori
  static NutritionAnalysisResult getSampleDish() {
    return NutritionAnalysisResult(
      dishName: "O'zbekcha Palov",
      confidenceScore: 0.95,
      totalCalories: 680,
      totalMacros: Macronutrients(proteinG: 32.0, carbsG: 82.0, fatG: 24.0),
      ingredients: [
        FoodIngredient(
          name: "Lazer guruch",
          estimatedWeightG: 200,
          calories: 270,
          proteinG: 5.4,
          carbsG: 60.0,
          fatG: 1.0,
        ),
        FoodIngredient(
          name: "Mol go'shti (lahm)",
          estimatedWeightG: 140,
          calories: 250,
          proteinG: 26.0,
          carbsG: 0.0,
          fatG: 16.0,
        ),
        FoodIngredient(
          name: "Sariq sabzi",
          estimatedWeightG: 80,
          calories: 35,
          proteinG: 0.8,
          carbsG: 8.0,
          fatG: 0.2,
        ),
        FoodIngredient(
          name: "Zig'ir va paxta yog'i",
          estimatedWeightG: 14,
          calories: 125,
          proteinG: 0.0,
          carbsG: 0.0,
          fatG: 14.0,
        ),
      ],
    );
  }
}
