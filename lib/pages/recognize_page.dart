/// 识别页：异步识别（传 disease + mode）
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'manual_input_page.dart';
import 'result_page.dart';

class RecognizePage extends StatefulWidget {
  final Uint8List imageBytes;

  const RecognizePage({super.key, required this.imageBytes});

  @override
  State<RecognizePage> createState() => _RecognizePageState();
}

class _RecognizePageState extends State<RecognizePage> {
  bool _submitting = false;
  String _status = '';
  int _elapsedSec = 0;
  String? _error;

  AppState get s => AppState.instance;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _submitting = true;
      _status = '提交识别';
    });
    final b64 = ImageUtil.compressToBase64(widget.imageBytes, targetKb: 1024);
    try {
      final result = await ApiClient().recognizeFlow(
        imageBase64: b64,
        mode: s.mode,
        disease: s.disease,
        onProgress: (status, elapsed) {
          if (!mounted) return;
          setState(() {
            _status = status == 'queued'
                ? '排队中…'
                : status == 'running'
                    ? 'AI 识别中…'
                    : status;
            _elapsedSec = elapsed.inSeconds;
          });
        },
      );
      if (!mounted) return;
      final rec = RecognizeResult.fromJson(result);
      await s.addMeal('加餐', rec.items.map((d) => d.toAdviceItem()).toList());
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(recognized: rec, mode: s.mode, disease: s.disease),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '识别失败（${_codeLabel(e.code)}）：${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '发生异常: $e';
      });
    }
  }

  String _codeLabel(int code) {
    switch (code) {
      case ApiCode.visionTimeout:
        return '4001 识别超时';
      case ApiCode.lowConfidence:
        return '4002 识别不确定';
      case ApiCode.serverError:
        return '5000 服务异常';
      default:
        return '$code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = s.brandColor;
    return Scaffold(
      appBar: AppBar(title: const Text('识别餐食'), backgroundColor: brand, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(widget.imageBytes, height: 260, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 24),
            if (_error == null) ...[
              if (_submitting) const CircularProgressIndicator() else Icon(Icons.check_circle, color: brand, size: 48),
              const SizedBox(height: 16),
              Text(_status, style: const TextStyle(fontSize: 16)),
              if (_elapsedSec > 0)
                Text('已等待 $_elapsedSec 秒（视觉模型较慢，请耐心）',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                s.isDiabetes
                    ? '正在按「${s.mode}」判断 GI / 碳水风险…'
                    : '正在按「${s.mode}」判断嘌呤风险…',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ] else ...[
              const Icon(Icons.error_outline, color: Color(0xFFE8556D), size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('返回重试')),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const ManualInputPage()),
                      );
                    },
                    child: const Text('手动输入菜品'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
