/// 首页：病种切换 + 模式 + 拍照识别 + 打卡概览
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../state/app_state.dart';
import '../theme/brand.dart';
import 'about_page.dart';
import 'daily_page.dart';
import 'manual_input_page.dart';
import 'recognize_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  AppState get s => AppState.instance;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final brand = s.brandColor;
        return Scaffold(
          appBar: AppBar(
            title: Text('${s.productTitle} · 今日能不能吃'),
            backgroundColor: brand,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: '关于 ${Brand.umbrella}',
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutPage()),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _diseaseCard(brand),
                const SizedBox(height: 12),
                _modeCard(brand),
                const SizedBox(height: 16),
                _cameraCard(brand),
                const SizedBox(height: 16),
                _manualCard(),
                const SizedBox(height: 16),
                _todayOverviewCard(brand),
                // 联调入口不在首页展示；debug 见关于页「开发调试」
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _diseaseCard(Color brand) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('管理病种', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'gout', label: Text('痛风'), icon: Icon(Icons.healing, size: 16)),
                ButtonSegment(value: 'diabetes', label: Text('控糖'), icon: Icon(Icons.monitor_heart, size: 16)),
                ButtonSegment(value: 'hypertension', label: Text('护心'), icon: Icon(Icons.favorite, size: 16)),
              ],
              selected: {s.disease},
              onSelectionChanged: (set) async {
                await s.setDisease(set.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return brand;
                  return null;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeCard(Color brand) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: brand),
                const SizedBox(width: 12),
                const Text('当前模式', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                DropdownButton<String>(
                  value: s.mode,
                  items: s.modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    await s.setMode(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '每日${s.budgetLabel}上限 ${s.dailyBudget} ${s.budgetUnit}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraCard(Color brand) {
    return Card(
      elevation: 0,
      color: brand,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.photo_camera_front, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            const Text(
              '拍照识别餐食',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              Brand.subtitleFor(s.disease),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _bigButton(
                  brand: brand,
                  icon: Icons.camera_alt,
                  label: '拍照',
                  onTap: _busy ? null : () => _pickAndRecognize(ImageSource.camera),
                ),
                const SizedBox(width: 16),
                _bigButton(
                  brand: brand,
                  icon: Icons.photo_library,
                  label: '相册',
                  onTap: _busy ? null : () => _pickAndRecognize(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigButton({
    required Color brand,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: brand, size: 22),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _manualCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.edit_note, color: Color(0xFF8A6D3B)),
        title: const Text('识别失败？手动输入菜品'),
        subtitle: Text(
          s.isDiabetes
              ? '直接查 GI / 碳水并获取建议'
              : s.isHypertension
                  ? '直接查胆固醇并获取建议（钠看灯色文案）'
                  : '直接查嘌呤并获取建议',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManualInputPage()),
        ),
      ),
    );
  }

  Widget _todayOverviewCard(Color brand) {
    final meals = s.todayMeals;
    final dishCount = meals.values.fold<int>(0, (sum, list) => sum + list.length);
    final slots = meals.keys.join(' / ');
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: brand),
                const SizedBox(width: 8),
                Text('今日${s.budgetLabel}打卡',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DailyPage()),
                  ),
                  child: const Text('查看额度'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('已记录 $dishCount 道菜${slots.isEmpty ? '' : '（$slots）'}',
                style: const TextStyle(fontSize: 14, color: Colors.black87)),
            if (meals.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('今天还没打卡，拍一张餐食开始吧',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndRecognize(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await _goRecognize(bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
    }
  }

  Future<void> _goRecognize(Uint8List bytes) async {
    setState(() => _busy = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RecognizePage(imageBytes: bytes)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
