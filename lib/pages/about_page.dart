/// 关于页：伞品牌文案 +（仅 debug）开发调试入口
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';
import '../theme/brand.dart';
import 'gate_check_page.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final brand = s.brandColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
        backgroundColor: brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            Brand.umbrella,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: brand,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Brand.umbrellaTagline,
            style: const TextStyle(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Text(
            Brand.umbrellaAbout,
            style: const TextStyle(fontSize: 15, height: 1.55),
          ),
          const SizedBox(height: 24),
          const Text('当前子品牌', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('${s.productTitle}（应用内标题随病种切换）'),
          const SizedBox(height: 20),
          const Text('系列子品牌', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(Brand.titleFor('gout')),
          Text(Brand.titleFor('diabetes')),
          Text(Brand.titleFor('hypertension')),
          const SizedBox(height: 24),
          const Text('免责声明', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            '本应用提供食养参考，不构成医疗建议，不能替代医生诊断与用药。',
            style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          const Text('商店简介口径', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SelectableText(
            Brand.storeShortDesc,
            style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: Brand.storeShortDesc));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制商店简介口径')),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('复制商店简介'),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '开发调试（仅 debug 包可见）',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              'API：${ApiConfig.baseUrl}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fact_check, color: Color(0xFF0F766E)),
              title: const Text('规则联调自检'),
              subtitle: const Text('同菜异色 / 日额度 / 可改联调 API 地址'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GateCheckPage()),
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            '商店名使用伞品牌「${Brand.umbrella}」；应用内标题为当前病种子品牌。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
