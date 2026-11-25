/// Macronutrients summary (Protein, Carbs, Fat)
class Macronutrients {
  Macronutrients({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  double proteinG;
  double carbsG;
  double fatG;

  factory Macronutrients.fromJson(Map<String, dynamic> json) => Macronutrients(
        proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
        carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
        fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };

  Macronutrients copyWith({double? proteinG, double? carbsG, double? fatG}) {
    return Macronutrients(
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
    );
  }
}

/// A segmented ingredient in the food dish
class FoodIngredient {
  FoodIngredient({
    required this.name,
    required this.estimatedWeightG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  String name;
  double estimatedWeightG;
  int calories;
  double proteinG;
  double carbsG;
  double fatG;

  factory FoodIngredient.fromJson(Map<String, dynamic> json) => FoodIngredient(
        name: json['name'] as String? ?? 'Ingredient',
        estimatedWeightG: (json['estimated_weight_g'] as num?)?.toDouble() ?? 100.0,
        calories: (json['calories'] as num?)?.round() ?? 0,
        proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
        carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
        fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'estimated_weight_g': estimatedWeightG,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };

  /// Recalculates calories and macros proportionally when weight in grams is modified by user
  FoodIngredient updateWeight(double newWeightG) {
    if (estimatedWeightG <= 0 || newWeightG <= 0) {
      return copyWith(estimatedWeightG: newWeightG);
    }
    final ratio = newWeightG / estimatedWeightG;
    return FoodIngredient(
      name: name,
      estimatedWeightG: newWeightG,
      calories: (calories * ratio).round(),
      proteinG: (proteinG * ratio * 10).round() / 10,
      carbsG: (carbsG * ratio * 10).round() / 10,
      fatG: (fatG * ratio * 10).round() / 10,
    );
  }

  FoodIngredient copyWith({
    String? name,
    double? estimatedWeightG,
    int? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
  }) {
    return FoodIngredient(
      name: name ?? this.name,
      estimatedWeightG: estimatedWeightG ?? this.estimatedWeightG,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
    );
  }
}

/// Complete AI Food Nutrition Analysis Result
class NutritionAnalysisResult {
  NutritionAnalysisResult({
    required this.dishName,
    required this.confidenceScore,
    required this.totalCalories,
    required this.totalMacros,
    required this.ingredients,
  });

  String dishName;
  double confidenceScore;
  int totalCalories;
  Macronutrients totalMacros;
  List<FoodIngredient> ingredients;

  factory NutritionAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawIngredients = (json['ingredients'] as List? ?? []);
    final ingredientsList = rawIngredients
        .map((i) => FoodIngredient.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList();

    return NutritionAnalysisResult(
      dishName: json['dish_name'] as String? ?? 'Noma\'lum taom',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      totalCalories: (json['total_calories'] as num?)?.round() ?? 0,
      totalMacros: Macronutrients.fromJson(
        Map<String, dynamic>.from(json['total_macronutrients'] as Map? ?? {}),
      ),
      ingredients: ingredientsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'dish_name': dishName,
        'confidence_score': confidenceScore,
        'total_calories': totalCalories,
        'total_macronutrients': totalMacros.toJson(),
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
      };

  /// Recalculates total calories and macronutrients from current ingredients
  void recalculateTotals() {
    int cals = 0;
    double p = 0;
    double c = 0;
    double f = 0;

    for (final ing in ingredients) {
      cals += ing.calories;
      p += ing.proteinG;
      c += ing.carbsG;
      f += ing.fatG;
    }

    totalCalories = cals;
    totalMacros = Macronutrients(
      proteinG: (p * 10).round() / 10,
      carbsG: (c * 10).round() / 10,
      fatG: (f * 10).round() / 10,
    );
  }
}
