/// 慢病饮食助手 - 全局状态（病种 + 模式 + 当日打卡）
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../theme/brand.dart';

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  static const _kDisease = 'chronic_disease';
  static const _kModePrefix = 'chronic_mode_'; // + disease
  static const _kMealsPrefix = 'chronic_meals_'; // + disease + _ + date

  static const diseases = ['gout', 'diabetes', 'hypertension'];
  static const diseaseLabels = {
    'gout': '痛风',
    'diabetes': '控糖',
    'hypertension': '护心',
  };

  static const modesByDisease = {
    'gout': ['发作期', '缓解期'],
    'diabetes': ['标准控糖', '强化控糖'],
    'hypertension': ['普通控制', '强化控制'],
  };

  static const defaultMode = {
    'gout': '缓解期',
    'diabetes': '标准控糖',
    'hypertension': '普通控制',
  };

  String _disease = 'gout';
  String _mode = '缓解期';
  final Map<String, List<Map<String, dynamic>>> _todayMeals = {};

  String get disease => _disease;
  String get mode => _mode;
  bool get isDiabetes => _disease == 'diabetes';
  bool get isHypertension => _disease == 'hypertension';
  List<String> get modes => modesByDisease[_disease] ?? modesByDisease['gout']!;
  Color get brandColor => Brand.colorFor(_disease);
  String get productTitle => Brand.titleFor(_disease);

  /// 当前日额度数值（嘌呤 mg / 碳水 g / 胆固醇 mg）
  int get dailyBudget {
    if (isDiabetes) return _mode == '强化控糖' ? 130 : 180;
    if (isHypertension) return _mode == '强化控制' ? 200 : 300;
    return _mode == '发作期' ? 150 : 300;
  }

  String get budgetUnit => Brand.budgetUnit(_disease);
  String get budgetLabel => Brand.budgetLabel(_disease);

  Map<String, List<Map<String, dynamic>>> get todayMeals => _todayMeals;

  static Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    // 仅 debug 允许覆盖联调 API；release 始终用默认生产/本机配置
    if (kDebugMode) {
      final savedUrl = sp.getString(ApiConfig.prefKey);
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        ApiConfig.setBaseUrl(savedUrl);
      }
    }
    var d = sp.getString(_kDisease) ?? 'gout';
    if (!diseases.contains(d)) d = 'gout';
    instance._disease = d;
    var m = sp.getString('$_kModePrefix$d') ?? defaultMode[d]!;
    if (!(modesByDisease[d] ?? []).contains(m)) m = defaultMode[d]!;
    instance._mode = m;
    await instance.loadDay(instance._todayKey());
  }

  Future<void> setApiBaseUrl(String url) async {
    if (!kDebugMode) return;
    ApiConfig.setBaseUrl(url);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(ApiConfig.prefKey, ApiConfig.baseUrl);
    notifyListeners();
  }

  Future<void> setDisease(String d) async {
    if (!diseases.contains(d) || d == _disease) return;
    _disease = d;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kDisease, d);
    var m = sp.getString('$_kModePrefix$d') ?? defaultMode[d]!;
    if (!(modesByDisease[d] ?? []).contains(m)) m = defaultMode[d]!;
    _mode = m;
    await loadDay(_todayKey());
    notifyListeners();
  }

  Future<void> setMode(String m) async {
    if (!modes.contains(m) || m == _mode) return;
    _mode = m;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('$_kModePrefix$_disease', m);
    notifyListeners();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _mealsStorageKey(String dateKey) => '$_kMealsPrefix${_disease}_$dateKey';

  Future<void> loadDay(String dateKey) async {
    _todayMeals.clear();
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_mealsStorageKey(dateKey));
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        map.forEach((k, v) {
          _todayMeals[k] = (v as List).map((e) => (e as Map<String, dynamic>)).toList();
        });
      } catch (_) {}
    }
  }

  Future<void> addMeal(String slot, List<Map<String, dynamic>> items) async {
    _todayMeals.putIfAbsent(slot, () => []).addAll(items);
    await _saveDay();
    notifyListeners();
  }

  Future<void> _saveDay() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_mealsStorageKey(_todayKey()), jsonEncode(_todayMeals));
  }
}
