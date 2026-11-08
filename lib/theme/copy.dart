/// 全 App 共用文案常量（拍照 / 手输 unknown 同一套）
library;

class AppCopy {
  static const unknownTitle = '这道菜暂时无法评估';
  static const unknownDetail =
      '建议咨询医生或查阅食物成分表。本工具仅供参考，不构成医疗建议。';

  static String sourceLabel(String? source) {
    switch (source) {
      case 'local_map':
      case 'local_keyword':
        return '已收录';
      case 'llm':
        return 'AI 评估';
      case 'unknown':
        return '暂无法评估';
      default:
        return '';
    }
  }

  static bool isUnknownLight(String? light) =>
      light == null || light.isEmpty || light == 'unknown' || light == '未知';
}
