/// 手动输入页（多病种）
library;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/copy.dart';

class ManualInputPage extends StatefulWidget {
  const ManualInputPage({super.key});

  @override
  State<ManualInputPage> createState() => _ManualInputPageState();
}

class _ManualInputPageState extends State<ManualInputPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController(text: '100');
  bool _loading = false;
  String? _lookupHint;

  AppState get s => AppState.instance;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入菜品名')));
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await ApiClient().nutritionLookup(name, disease: s.disease);
      if (r.ok) {
        final data = r.data as Map<String, dynamic>;
        final hit = data['hit'] as bool? ?? false;
        if (hit) {
          final nut = Nutrition.fromJson(data['nutrition'] as Map<String, dynamic>);
          setState(() {
            if (s.isDiabetes) {
              _lookupHint = nut.gi != null
                  ? '命中库：GI ${nut.gi!.toStringAsFixed(0)} / 碳水 ${nut.carbG.toStringAsFixed(1)}g'
                  : '命中库：碳水 ${nut.carbG.toStringAsFixed(1)}g';
            } else if (s.isHypertension) {
              _lookupHint = nut.cholesterolMg != null
                  ? '命中库：胆固醇 ${nut.cholesterolMg!.toStringAsFixed(0)} mg'
                      '${nut.satFatG != null ? ' / 饱和脂肪 ${nut.satFatG!.toStringAsFixed(1)}g' : ''}'
                  : '命中库：${nut.kcal} kcal';
            } else {
              _lookupHint = nut.purineMg != null
                  ? '命中嘌呤库：约 ${nut.purineMg!.toStringAsFixed(0)} mg / ${nut.kcal} kcal'
                  : '命中库：${nut.kcal} kcal';
            }
          });
        } else {
          setState(() {
            if (s.isDiabetes) {
              _lookupHint = '未命中 GI/碳水库（仍会给建议）';
            } else if (s.isHypertension) {
              _lookupHint = '未命中护心含量库（仍会给建议）';
            } else {
              _lookupHint = '未命中嘌呤库（仍会给建议）';
            }
          });
        }
      } else {
        setState(() => _lookupHint = '查询失败：${r.message}');
      }
    } on ApiException catch (e) {
      setState(() => _lookupHint = '查询失败：${e.message}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入菜品名')));
      return;
    }
    double weight;
    try {
      weight = double.parse(_weightCtrl.text.trim());
    } catch (_) {
      weight = 100;
    }
    setState(() => _loading = true);
    try {
      final r = await ApiClient().mealAdvice(
        items: [
          {'name': name, 'weight_g': weight}
        ],
        mode: s.mode,
        disease: s.disease,
      );
      if (!r.ok) throw ApiException(r.code, r.message ?? '获取建议失败');
      final advice = AdviceResult.fromJson(r.data as Map<String, dynamic>);
      await s.addMeal('加餐', [
        {'name': name, 'weight_g': weight}
      ]);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ManualResultPage(advice: advice, mode: s.mode, disease: s.disease),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('获取建议失败：${e.message}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = s.brandColor;
    return Scaffold(
      appBar: AppBar(title: const Text('手动输入菜品'), backgroundColor: brand, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    Text(
                      '${AppState.diseaseLabels[s.disease]} · ${s.mode}（日上限 ${s.dailyBudget} ${s.budgetUnit}）',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: '菜品名',
                        hintText: s.isDiabetes
                            ? '例如：白米饭 / 苹果 / 猪肝'
                            : s.isHypertension
                                ? '例如：咸菜 / 猪肝 / 白米饭'
                                : '例如：卤猪肝 / 清蒸鲈鱼',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _weightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '克数（估算）',
                        suffixText: 'g',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _lookup,
                    child: Text(
                      s.isDiabetes
                          ? '查询 GI/碳水'
                          : s.isHypertension
                              ? '查询胆固醇'
                              : '查询嘌呤',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('获取建议'),
                  ),
                ),
              ],
            ),
            if (_lookupHint != null) ...[
              const SizedBox(height: 12),
              Text(_lookupHint!, style: const TextStyle(color: Colors.black54)),
            ],
          ],
        ),
      ),
    );
  }
}

class ManualResultPage extends StatelessWidget {
  final AdviceResult advice;
  final String mode;
  final String disease;

  const ManualResultPage({
    super.key,
    required this.advice,
    required this.mode,
    required this.disease,
  });

  Color _lightColor(String? light) {
    if (AppCopy.isUnknownLight(light)) return Colors.blueGrey;
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
    final d = advice.dishes.isNotEmpty ? advice.dishes.first : null;
    final color = _lightColor(d?.light);
    final brand = AppState.instance.brandColor;
    final dia = disease == 'diabetes';
    final ht = disease == 'hypertension';
    final unknown = d != null && AppCopy.isUnknownLight(d.light);
    return Scaffold(
      appBar: AppBar(title: const Text('建议结果'), backgroundColor: brand, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: d == null
            ? const Center(child: Text('无建议结果'))
            : Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '模式：$mode'
                        '${AppCopy.sourceLabel(d.source).isEmpty ? '' : ' · ${AppCopy.sourceLabel(d.source)}'}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Text('${d.dish}（${d.weightG.toStringAsFixed(0)}g）',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                        unknown ? AppCopy.unknownTitle : '判断：${d.light}',
                        style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      if (unknown) ...[
                        const SizedBox(height: 8),
                        const Text(AppCopy.unknownDetail, style: TextStyle(height: 1.45)),
                      ] else ...[
                        if (dia && d.gi != null) ...[
                          const SizedBox(height: 6),
                          Text('GI ${d.gi!.toStringAsFixed(0)}'
                              '${d.carbG != null ? ' · 碳水 ${d.carbG!.toStringAsFixed(1)} g' : ''}'),
                        ],
                        if (ht && d.cholesterolMg != null) ...[
                          const SizedBox(height: 6),
                          Text('胆固醇约 ${d.cholesterolMg!.toStringAsFixed(0)} mg（估算）'),
                        ],
                        if (ht && d.satFatG != null) ...[
                          const SizedBox(height: 4),
                          Text('饱和脂肪约 ${d.satFatG!.toStringAsFixed(1)} g'),
                        ],
                        if (ht && d.sodiumNote != null) ...[
                          const SizedBox(height: 4),
                          Text(d.sodiumNote!, style: TextStyle(color: color)),
                        ],
                        if (!dia && !ht && d.purineMg != null) ...[
                          const SizedBox(height: 6),
                          Text('嘌呤约 ${d.purineMg!.toStringAsFixed(0)} mg（估算）'),
                        ],
                        if (d.advice != null) ...[
                          const SizedBox(height: 8),
                          Text('建议：${d.advice}'),
                        ],
                        if (d.reason != null) ...[
                          const SizedBox(height: 6),
                          Text('理由：${d.reason}', style: const TextStyle(color: Colors.black54)),
                        ],
                        if (d.replacement != null && d.replacement!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('替换：${d.replacement}', style: TextStyle(color: brand)),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
