/// 规则联调自检（仅 debug：同菜异色 + 日额度 + API 地址）
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';

class GateCheckPage extends StatefulWidget {
  const GateCheckPage({super.key});

  @override
  State<GateCheckPage> createState() => _GateCheckPageState();
}

class _GateCheckPageState extends State<GateCheckPage> {
  final _urlCtrl = TextEditingController(text: ApiConfig.baseUrl);
  bool _running = false;
  final List<_GateLine> _lines = [];

  AppState get s => AppState.instance;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    await s.setApiBaseUrl(_urlCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存 API：${ApiConfig.baseUrl}')),
    );
  }

  void _add(String name, bool ok, [String detail = '']) {
    _lines.add(_GateLine(name: name, ok: ok, detail: detail));
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _lines.clear();
    });
    try {
      await s.setApiBaseUrl(_urlCtrl.text);
      final client = ApiClient();

      // —— 痛风：白米饭绿 / 猪肝红 ——
      final gout = await client.mealAdvice(
        disease: 'gout',
        mode: '发作期',
        items: [
          {'name': '白米饭', 'weight_g': 200},
          {'name': '猪肝', 'weight_g': 100},
        ],
      );
      if (!gout.ok) {
        _add('痛风 advice', false, gout.message ?? '失败');
      } else {
        final data = gout.data as Map<String, dynamic>;
        final map = _dishMap(data);
        final rice = map['白米饭'];
        final liver = map['猪肝'];
        _add('痛风·白米饭绿灯', rice?['light'] == '绿灯', '${rice?['light']} ${rice?['advice'] ?? ''}');
        _add('痛风·猪肝红灯', liver?['light'] == '红灯', '${liver?['light']} ${liver?['advice'] ?? ''}');
        _add('痛风·有建议文案', ((liver?['advice'] as String?) ?? '').isNotEmpty);
        _add('痛风·发作期上限150', data['daily_purine_limit_mg'] == 150, '${data['daily_purine_limit_mg']}');
      }

      // —— 控糖：白米饭红 / 猪肝黄 ——
      final dia = await client.mealAdvice(
        disease: 'diabetes',
        mode: '强化控糖',
        items: [
          {'name': '白米饭', 'weight_g': 150},
          {'name': '猪肝', 'weight_g': 100},
        ],
      );
      if (!dia.ok) {
        _add('控糖 advice', false, dia.message ?? '失败');
      } else {
        final data = dia.data as Map<String, dynamic>;
        final map = _dishMap(data);
        final rice = map['白米饭'];
        final liver = map['猪肝'];
        final advice = (rice?['advice'] as String?) ?? '';
        _add('控糖·白米饭红灯（异色）', rice?['light'] == '红灯', '${rice?['light']} $advice');
        _add('控糖·猪肝黄灯（异色）', liver?['light'] == '黄灯', '${liver?['light']}');
        _add('控糖·红灯限量文案', advice.contains('限量') || advice.contains('非禁食'), advice);
        _add('控糖·强化上限130', data['daily_carb_limit_g'] == 130, '${data['daily_carb_limit_g']}');
      }

      // —— 日进度 / 模式 ——
      final dGout = await client.dailySummary(
        disease: 'gout',
        mode: '缓解期',
        date: _today(),
        meals: {
          '午餐': [
            {'name': '白米饭', 'weight_g': 200},
          ],
        },
      );
      _add(
        '痛风·缓解期日额度300',
        dGout.ok && (dGout.data as Map?)?['purine_limit_mg'] == 300,
        '${(dGout.data as Map?)?['purine_limit_mg']} / 摄入 ${(dGout.data as Map?)?['intake_purine_mg']}',
      );

      final dDia = await client.dailySummary(
        disease: 'diabetes',
        mode: '标准控糖',
        date: _today(),
        meals: {
          '午餐': [
            {'name': '白米饭', 'weight_g': 150},
          ],
        },
      );
      _add(
        '控糖·标准日额度180',
        dDia.ok && (dDia.data as Map?)?['carb_limit_g'] == 180,
        '${(dDia.data as Map?)?['carb_limit_g']} / 摄入 ${(dDia.data as Map?)?['intake_carb_g']}',
      );
    } on ApiException catch (e) {
      _add('网络/API', false, e.message);
    } catch (e) {
      _add('异常', false, '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Map<String, Map<String, dynamic>> _dishMap(Map<String, dynamic> data) {
    final list = (data['dishes'] as List?) ?? [];
    final out = <String, Map<String, dynamic>>{};
    for (final e in list) {
      if (e is Map<String, dynamic>) {
        out['${e['dish']}'] = e;
      }
    }
    return out;
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final brand = s.brandColor;
    final fail = _lines.where((e) => !e.ok).length;
    final pass = _lines.where((e) => e.ok).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('规则联调自检'),
        backgroundColor: brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '通过标准：痛风白米饭绿/猪肝红；控糖白米饭红/猪肝黄；双模式日额度正确。\n'
            '真机可用 adb reverse 或填电脑局域网地址后「跑自检」。',
            style: TextStyle(height: 1.4, color: Colors.black87),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'API Base URL（仅 debug）',
                hintText: 'http://192.168.x.x:8081',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(onPressed: _running ? null : _saveUrl, child: const Text('保存地址')),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _running ? null : _run,
                  style: FilledButton.styleFrom(backgroundColor: brand),
                  child: Text(_running ? '检测中…' : '跑自检'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _running ? null : _run,
              style: FilledButton.styleFrom(backgroundColor: brand),
              child: Text(_running ? '检测中…' : '跑自检'),
            ),
          ],
          if (_lines.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('结果：PASS $pass · FAIL $fail',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: fail == 0 ? const Color(0xFF67C23A) : const Color(0xFFE8556D),
                )),
            const SizedBox(height: 8),
            ..._lines.map((e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    e.ok ? Icons.check_circle : Icons.cancel,
                    color: e.ok ? const Color(0xFF67C23A) : const Color(0xFFE8556D),
                  ),
                  title: Text(e.name),
                  subtitle: e.detail.isEmpty ? null : Text(e.detail, maxLines: 3),
                )),
          ],
        ],
      ),
    );
  }
}

class _GateLine {
  final String name;
  final bool ok;
  final String detail;
  _GateLine({required this.name, required this.ok, this.detail = ''});
}
