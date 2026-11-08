/// 慢病饮食助手 - 数据模型（痛风 / 控糖 / 护心）
library;

class RecognizedDish {
  final String name;
  final double weightG;
  final double confidence;

  RecognizedDish({required this.name, required this.weightG, required this.confidence});

  factory RecognizedDish.fromJson(Map<String, dynamic> json) => RecognizedDish(
        name: (json['name'] as String?) ?? '',
        weightG: (json['estimate_weight_g'] as num?)?.toDouble() ?? 100,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.6,
      );

  Map<String, dynamic> toAdviceItem() => {'name': name, 'weight_g': weightG};
}

class RecognizeResult {
  final List<RecognizedDish> items;
  final String model;
  final int latencyMs;
  final String mode;
  final String disease;

  RecognizeResult({
    required this.items,
    required this.model,
    required this.latencyMs,
    required this.mode,
    required this.disease,
  });

  factory RecognizeResult.fromJson(Map<String, dynamic> json) => RecognizeResult(
        items: (json['items'] as List? ?? [])
            .map((e) => RecognizedDish.fromJson(e as Map<String, dynamic>))
            .toList(),
        model: (json['model'] as String?) ?? '',
        latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
        mode: (json['mode'] as String?) ?? '',
        disease: (json['disease'] as String?) ?? 'gout',
      );
}

class Nutrition {
  final String name;
  final double kcal, carbG, proteinG, fatG;
  final double? purineMg;
  final double? gi;
  final double? cholesterolMg;
  final double? sodiumMg;
  final double? satFatG;

  Nutrition({
    required this.name,
    required this.kcal,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    this.purineMg,
    this.gi,
    this.cholesterolMg,
    this.sodiumMg,
    this.satFatG,
  });

  factory Nutrition.fromJson(Map<String, dynamic> json) => Nutrition(
        name: (json['name'] as String?) ?? '',
        kcal: (json['kcal'] as num?)?.toDouble() ?? 0,
        carbG: (json['carb_g'] as num?)?.toDouble() ?? 0,
        proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
        fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
        purineMg: (json['purine_mg'] as num?)?.toDouble(),
        gi: (json['gi'] as num?)?.toDouble(),
        cholesterolMg: (json['cholesterol_mg'] as num?)?.toDouble(),
        sodiumMg: (json['sodium_mg'] as num?)?.toDouble(),
        satFatG: (json['sat_fat_g'] as num?)?.toDouble(),
      );
}

class DishAdvice {
  final String dish;
  final double weightG;
  final double? purineMg;
  final double? gi;
  final double? carbG;
  final double? cholesterolMg;
  final double? sodiumMg;
  final double? satFatG;
  final String? sodiumNote;
  final Nutrition? nutrition;
  final String? advice;
  final String? light;
  final String? reason;
  final String? replacement;
  final String? ruleId;
  final String? lightSemantics;
  final String? source;

  DishAdvice({
    required this.dish,
    required this.weightG,
    this.purineMg,
    this.gi,
    this.carbG,
    this.cholesterolMg,
    this.sodiumMg,
    this.satFatG,
    this.sodiumNote,
    this.nutrition,
    this.advice,
    this.light,
    this.reason,
    this.replacement,
    this.ruleId,
    this.lightSemantics,
    this.source,
  });

  factory DishAdvice.fromJson(Map<String, dynamic> json) => DishAdvice(
        dish: (json['dish'] as String?) ?? '',
        weightG: (json['weight_g'] as num?)?.toDouble() ?? 0,
        purineMg: (json['purine_mg'] as num?)?.toDouble(),
        gi: (json['gi'] as num?)?.toDouble(),
        carbG: (json['carb_g'] as num?)?.toDouble(),
        cholesterolMg: (json['cholesterol_mg'] as num?)?.toDouble(),
        sodiumMg: (json['sodium_mg'] as num?)?.toDouble(),
        satFatG: (json['sat_fat_g'] as num?)?.toDouble(),
        sodiumNote: json['sodium_note'] as String?,
        nutrition: json['nutrition'] == null
            ? null
            : Nutrition.fromJson(json['nutrition'] as Map<String, dynamic>),
        advice: json['advice'] as String?,
        light: json['light'] as String?,
        reason: json['reason'] as String?,
        replacement: json['replacement'] as String?,
        ruleId: json['rule_id'] as String?,
        lightSemantics: json['light_semantics'] as String?,
        source: json['source'] as String?,
      );
}

class MealSummary {
  final String? overallLight;
  final double totalPurineMg;
  final double purinePctOfDaily;
  final double totalCarbG;
  final double carbPctOfDaily;
  final double totalCholesterolMg;
  final double cholesterolPctOfDaily;
  final double totalSatFatG;
  final Map<String, double> totalNutrition;

  MealSummary({
    required this.overallLight,
    required this.totalPurineMg,
    required this.purinePctOfDaily,
    required this.totalCarbG,
    required this.carbPctOfDaily,
    required this.totalCholesterolMg,
    required this.cholesterolPctOfDaily,
    required this.totalSatFatG,
    required this.totalNutrition,
  });

  factory MealSummary.fromJson(Map<String, dynamic> json) => MealSummary(
        overallLight: json['overall_light'] as String?,
        totalPurineMg: (json['total_purine_mg'] as num?)?.toDouble() ?? 0,
        purinePctOfDaily: (json['purine_pct_of_daily'] as num?)?.toDouble() ?? 0,
        totalCarbG: (json['total_carb_g'] as num?)?.toDouble() ?? 0,
        carbPctOfDaily: (json['carb_pct_of_daily'] as num?)?.toDouble() ?? 0,
        totalCholesterolMg: (json['total_cholesterol_mg'] as num?)?.toDouble() ?? 0,
        cholesterolPctOfDaily: (json['cholesterol_pct_of_daily'] as num?)?.toDouble() ?? 0,
        totalSatFatG: (json['total_sat_fat_g'] as num?)?.toDouble() ?? 0,
        totalNutrition: (json['total_nutrition'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0)),
      );
}

class AdviceResult {
  final String disease;
  final String mode;
  final double dailyPurineLimitMg;
  final double dailyCarbLimitG;
  final double dailyCholesterolLimitMg;
  final List<DishAdvice> dishes;
  final MealSummary summary;

  AdviceResult({
    required this.disease,
    required this.mode,
    required this.dailyPurineLimitMg,
    required this.dailyCarbLimitG,
    required this.dailyCholesterolLimitMg,
    required this.dishes,
    required this.summary,
  });

  bool get isDiabetes => disease == 'diabetes';
  bool get isHypertension => disease == 'hypertension';

  double get budgetLimit {
    if (isDiabetes) return dailyCarbLimitG;
    if (isHypertension) return dailyCholesterolLimitMg;
    return dailyPurineLimitMg;
  }

  double get budgetIntake {
    if (isDiabetes) return summary.totalCarbG;
    if (isHypertension) return summary.totalCholesterolMg;
    return summary.totalPurineMg;
  }

  double get budgetPct {
    if (isDiabetes) return summary.carbPctOfDaily;
    if (isHypertension) return summary.cholesterolPctOfDaily;
    return summary.purinePctOfDaily;
  }

  factory AdviceResult.fromJson(Map<String, dynamic> json) => AdviceResult(
        disease: (json['disease'] as String?) ?? 'gout',
        mode: (json['mode'] as String?) ?? '',
        dailyPurineLimitMg: (json['daily_purine_limit_mg'] as num?)?.toDouble() ?? 300,
        dailyCarbLimitG: (json['daily_carb_limit_g'] as num?)?.toDouble() ?? 180,
        dailyCholesterolLimitMg:
            (json['daily_cholesterol_limit_mg'] as num?)?.toDouble() ?? 300,
        dishes: (json['dishes'] as List? ?? [])
            .map((e) => DishAdvice.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: MealSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
      );
}

class DailySummary {
  final String disease;
  final String mode;
  final String? date;
  final double purineLimitMg;
  final double intakePurineMg;
  final double remainingPurineMg;
  final double purineAchievementPct;
  final double carbLimitG;
  final double intakeCarbG;
  final double remainingCarbG;
  final double carbAchievementPct;
  final double cholesterolLimitMg;
  final double intakeCholesterolMg;
  final double remainingCholesterolMg;
  final double cholesterolAchievementPct;
  final double intakeSatFatG;
  final Map<String, double> intakeNutrition;
  final Map<String, String> mealLights;

  DailySummary({
    required this.disease,
    required this.mode,
    this.date,
    required this.purineLimitMg,
    required this.intakePurineMg,
    required this.remainingPurineMg,
    required this.purineAchievementPct,
    required this.carbLimitG,
    required this.intakeCarbG,
    required this.remainingCarbG,
    required this.carbAchievementPct,
    required this.cholesterolLimitMg,
    required this.intakeCholesterolMg,
    required this.remainingCholesterolMg,
    required this.cholesterolAchievementPct,
    required this.intakeSatFatG,
    required this.intakeNutrition,
    required this.mealLights,
  });

  bool get isDiabetes => disease == 'diabetes';
  bool get isHypertension => disease == 'hypertension';

  double get budgetLimit {
    if (isDiabetes) return carbLimitG;
    if (isHypertension) return cholesterolLimitMg;
    return purineLimitMg;
  }

  double get budgetIntake {
    if (isDiabetes) return intakeCarbG;
    if (isHypertension) return intakeCholesterolMg;
    return intakePurineMg;
  }

  double get budgetRemaining {
    if (isDiabetes) return remainingCarbG;
    if (isHypertension) return remainingCholesterolMg;
    return remainingPurineMg;
  }

  double get budgetPct {
    if (isDiabetes) return carbAchievementPct;
    if (isHypertension) return cholesterolAchievementPct;
    return purineAchievementPct;
  }

  factory DailySummary.fromJson(Map<String, dynamic> json) => DailySummary(
        disease: (json['disease'] as String?) ?? 'gout',
        mode: (json['mode'] as String?) ?? '',
        date: json['date'] as String?,
        purineLimitMg: (json['purine_limit_mg'] as num?)?.toDouble() ?? 300,
        intakePurineMg: (json['intake_purine_mg'] as num?)?.toDouble() ?? 0,
        remainingPurineMg: (json['remaining_purine_mg'] as num?)?.toDouble() ?? 0,
        purineAchievementPct: (json['purine_achievement_pct'] as num?)?.toDouble() ?? 0,
        carbLimitG: (json['carb_limit_g'] as num?)?.toDouble() ?? 180,
        intakeCarbG: (json['intake_carb_g'] as num?)?.toDouble() ?? 0,
        remainingCarbG: (json['remaining_carb_g'] as num?)?.toDouble() ?? 0,
        carbAchievementPct: (json['carb_achievement_pct'] as num?)?.toDouble() ?? 0,
        cholesterolLimitMg: (json['cholesterol_limit_mg'] as num?)?.toDouble() ?? 300,
        intakeCholesterolMg: (json['intake_cholesterol_mg'] as num?)?.toDouble() ?? 0,
        remainingCholesterolMg: (json['remaining_cholesterol_mg'] as num?)?.toDouble() ?? 0,
        cholesterolAchievementPct:
            (json['cholesterol_achievement_pct'] as num?)?.toDouble() ?? 0,
        intakeSatFatG: (json['intake_sat_fat_g'] as num?)?.toDouble() ?? 0,
        intakeNutrition: (json['intake_nutrition'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0)),
        mealLights: (json['meal_lights'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v.toString())),
      );
}
