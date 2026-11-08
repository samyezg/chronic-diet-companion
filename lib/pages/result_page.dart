/// 建议结果页：红黄绿 + 嘌呤/碳水/胆固醇进度条
library;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/copy.dart';

class ResultPage extends StatefulWidget {
  final RecognizeResult recognized;
  final String mode;
  final String disease;

  const ResultPage({
    super.key,
    required this.recognized,
    required this.mode,
    required this.disease,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late Future<AdviceResult> _future;

  bool get _dia => widget.disease == 'diabetes';
  bool get _ht => widget.disease == 'hypertension';
  Color get _brand => AppState.instance.brandColor;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdviceResult> _load() async {
    final r = await ApiClient().mealAdvice(
      items: widget.recognized.items.map((d) => d.toAdviceItem()).toList(),
      mode: widget.mode,
      disease: widget.disease,
    );
    if (!r.ok) throw ApiException(r.code, r.message ?? '获取建议失败');
    return AdviceResult.fromJson(r.data as Map<String, dynamic>);
  }

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

  IconData _lightIcon(String? light) {
    if (AppCopy.isUnknownLight(light)) return Icons.help_outline;
    switch (light) {
      case '红灯':
        return Icons.cancel;
      case '黄灯':
        return Icons.warning_amber;
      case '绿灯':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _lightLabel(String? light) {
    if (AppCopy.isUnknownLight(light)) return AppCopy.unknownTitle;
    return light ?? AppCopy.unknownTitle;
  }

  String get _budgetLabel => _dia ? '碳水' : (_ht ? '胆固醇' : '嘌呤');
  String get _budgetUnit => _dia ? 'g' : 'mg';
  String get _disclaimer => _dia
      ? 'GI/碳值为估算，红灯=严格限量（非禁食），不构成医疗建议'
      : _ht
          ? '胆固醇为估算值；钠为定性提醒（识别估盐不准）；红灯=严格限量非禁食；不构成医疗建议'
          : '嘌呤为估算值，仅供参考，不构成医疗建议';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_dia ? '血糖饮食建议' : (_ht ? '护心饮食建议' : '嘌呤饮食建议')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<AdviceResult>(
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
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _future = _load()),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          final result = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _summaryBanner(result),
              const SizedBox(height: 12),
              ...result.dishes.map(_dishCard),
              const SizedBox(height: 24),
              Text(
                '${widget.mode} · ${widget.recognized.items.length} 道菜 · ${widget.recognized.model}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(_disclaimer, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryBanner(AdviceResult result) {
    final color = _lightColor(result.summary.overallLight);
    final intake = result.budgetIntake;
    final limit = result.budgetLimit;
    final pct = result.budgetPct.clamp(0, 200);

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_lightIcon(result.summary.overallLight), color: color, size: 28),
                const SizedBox(width: 8),
                Text(_lightLabel(result.summary.overallLight),
                    style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('本餐整体判断', style: TextStyle(fontSize: 13, color: Colors.black54)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '本餐$_budgetLabel约 ${intake.toStringAsFixed(0)} $_budgetUnit / 日额度 ${limit.toStringAsFixed(0)} $_budgetUnit'
              '（${pct.toStringAsFixed(0)}%）',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (_ht && result.summary.totalSatFatG > 0) ...[
              const SizedBox(height: 4),
              Text(
                '本餐饱和脂肪约 ${result.summary.totalSatFatG.toStringAsFixed(1)} g（卡片明细）',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (_ht) ...[
              const SizedBox(height: 4),
              const Text(
                '钠：按菜品红黄绿定性提醒（非数字进度条）',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  pct >= 100
                      ? const Color(0xFFE8556D)
                      : pct >= 70
                          ? const Color(0xFFE6A23C)
                          : _brand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dishCard(DishAdvice d) {
    final color = _lightColor(d.light);
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_lightIcon(d.light), color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${d.dish}（${d.weightG.toStringAsFixed(0)}g）',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                if (AppCopy.sourceLabel(d.source).isNotEmpty)
                  Text(AppCopy.sourceLabel(d.source),
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text(_lightLabel(d.light),
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
            if (AppCopy.isUnknownLight(d.light)) ...[
              const SizedBox(height: 6),
              Text(AppCopy.unknownDetail,
                  style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4)),
            ] else ...[
              if (_dia && d.gi != null) ...[
                const SizedBox(height: 4),
                Text('GI ${d.gi!.toStringAsFixed(0)}'
                    '${d.carbG != null ? ' · 碳水 ${d.carbG!.toStringAsFixed(1)} g' : ''}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
              if (_ht && d.cholesterolMg != null) ...[
                const SizedBox(height: 4),
                Text('胆固醇约 ${d.cholesterolMg!.toStringAsFixed(0)} mg',
                    style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
              if (_ht && d.satFatG != null) ...[
                const SizedBox(height: 4),
                Text('饱和脂肪约 ${d.satFatG!.toStringAsFixed(1)} g',
                    style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
              if (_ht && d.sodiumNote != null) ...[
                const SizedBox(height: 4),
                Text(d.sodiumNote!, style: TextStyle(fontSize: 13, color: color)),
              ],
              if (!_dia && !_ht && d.purineMg != null) ...[
                const SizedBox(height: 4),
                Text('嘌呤约 ${d.purineMg!.toStringAsFixed(0)} mg',
                    style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
              if (d.advice != null) ...[
                const SizedBox(height: 8),
                Text('建议：${d.advice}', style: const TextStyle(fontSize: 14)),
              ],
              if (d.reason != null) ...[
                const SizedBox(height: 4),
                Text('理由：${d.reason}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
              if (d.replacement != null && d.replacement!.isNotEmpty && d.replacement != '-') ...[
                const SizedBox(height: 4),
                Text('替换：${d.replacement}', style: TextStyle(fontSize: 13, color: _brand)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
