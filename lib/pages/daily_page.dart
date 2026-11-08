/// 每日打卡：嘌呤或碳水额度
library;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/app_state.dart';

class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  late Future<DailySummary> _future;

  AppState get s => AppState.instance;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DailySummary> _load() async {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (s.todayMeals.isEmpty) {
      final b = s.dailyBudget.toDouble();
      return DailySummary(
        disease: s.disease,
        mode: s.mode,
        date: date,
        purineLimitMg: s.isDiabetes || s.isHypertension ? 0 : b,
        intakePurineMg: 0,
        remainingPurineMg: s.isDiabetes || s.isHypertension ? 0 : b,
        purineAchievementPct: 0,
        carbLimitG: s.isDiabetes ? b : 0,
        intakeCarbG: 0,
        remainingCarbG: s.isDiabetes ? b : 0,
        carbAchievementPct: 0,
        cholesterolLimitMg: s.isHypertension ? b : 0,
        intakeCholesterolMg: 0,
        remainingCholesterolMg: s.isHypertension ? b : 0,
        cholesterolAchievementPct: 0,
        intakeSatFatG: 0,
        intakeNutrition: const {},
        mealLights: const {},
      );
    }
    final r = await ApiClient().dailySummary(
      date: date,
      mode: s.mode,
      disease: s.disease,
      meals: s.todayMeals,
    );
    if (!r.ok) throw ApiException(r.code, r.message ?? '获取每日汇总失败');
    return DailySummary.fromJson(r.data as Map<String, dynamic>);
  }

  Color _lightColor(String light) {
    switch (light) {
      case '红灯':
        return const Color(0xFFE8556D);
      case '黄灯':
        return const Color(0xFFE6A23C);
      case '绿灯':
        return const Color(0xFF67C23A);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = s.brandColor;
    return Scaffold(
      appBar: AppBar(
        title: Text('今日${s.budgetLabel}额度'),
        backgroundColor: brand,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DailySummary>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(() => _future = _load()),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          final d = snap.data!;
          final pct = d.budgetPct.clamp(0, 200);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${d.mode} · ${s.budgetLabel}额度',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 12),
                      Text(
                        '已摄入 ${d.budgetIntake.toStringAsFixed(0)} / ${d.budgetLimit.toStringAsFixed(0)} ${s.budgetUnit}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '剩余约 ${d.budgetRemaining.toStringAsFixed(0)} ${s.budgetUnit}（${d.budgetPct.toStringAsFixed(0)}%）',
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            pct >= 100
                                ? const Color(0xFFE8556D)
                                : pct >= 70
                                    ? const Color(0xFFE6A23C)
                                    : brand,
                          ),
                        ),
                      ),
                      if (s.isHypertension && d.intakeSatFatG > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '今日饱和脂肪合计约 ${d.intakeSatFatG.toStringAsFixed(1)} g',
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                      if (s.isHypertension) ...[
                        const SizedBox(height: 4),
                        const Text(
                          '钠按菜品红黄绿定性提醒，不做数字日进度条',
                          style: TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (d.mealLights.isNotEmpty)
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('餐次判断', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: d.mealLights.entries.map((e) {
                            final c = _lightColor(e.value);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  e.value == '红灯'
                                      ? Icons.cancel
                                      : e.value == '黄灯'
                                          ? Icons.warning_amber
                                          : Icons.check_circle,
                                  color: c,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text('${e.key} ${e.value}'),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              ..._mealDetail(),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _mealDetail() {
    final meals = s.todayMeals;
    if (meals.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('今天还没有记录', style: TextStyle(color: Colors.grey))),
        ),
      ];
    }
    return [
      Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('已记录明细', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              ...meals.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('${e.key}：${e.value.map((d) => d['name']).join('、')}'),
                  )),
            ],
          ),
        ),
      ),
    ];
  }
}
