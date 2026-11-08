/// 多病种品牌色与文案
///
/// 命名分层（H5 正式统一前先预留口径）：
/// - 伞品牌 [umbrella]：商店名 / 关于页系列背书
/// - 子品牌 [titleFor]：应用内当前病种标题
library;

import 'package:flutter/material.dart';

class Brand {
  /// 伞品牌（一套应用 · 商店名）
  static const umbrella = '慢病餐伴侣';

  /// 关于页 / 商店简介短文案（H5 可原样用于上架）
  static const umbrellaTagline = '一套应用，多病种饮食红黄绿参考';
  static const umbrellaAbout =
      '「慢病餐伴侣」是系列伞品牌：应用内可切换痛风餐伴侣、控糖餐伴侣、护心餐伴侣。'
      '本工具仅提供食养参考，不构成医疗建议，不能替代诊治与用药。';
  static const storeShortDesc =
      '慢病餐伴侣：拍照/手动记录餐食，按病种给出红黄绿灯与每日额度参考'
      '（痛风嘌呤 / 控糖碳水 / 护心胆固醇）。非诊疗软件。';

  static const gout = Color(0xFF0D9488); // 青绿
  static const diabetes = Color(0xFFEA580C); // 暖橙
  /// 护心（高血压/高血脂）预留色，H5 启用
  static const heart = Color(0xFFBE123C);

  static Color colorFor(String disease) {
    switch (disease) {
      case 'diabetes':
        return diabetes;
      case 'hypertension':
        return heart;
      default:
        return gout;
    }
  }

  static String titleFor(String disease) {
    switch (disease) {
      case 'diabetes':
        return '控糖餐伴侣';
      case 'hypertension':
        return '护心餐伴侣';
      default:
        return '痛风餐伴侣';
    }
  }

  static String subtitleFor(String disease) {
    switch (disease) {
      case 'diabetes':
        return '拍一张餐食，看 GI 红黄绿与碳水额度';
      case 'hypertension':
        return '拍一张餐食，看胆固醇额度与高盐提醒';
      default:
        return '拍一张餐食，看嘌呤红黄绿与每日额度';
    }
  }

  static String budgetUnit(String disease) {
    switch (disease) {
      case 'diabetes':
        return 'g';
      case 'hypertension':
        return 'mg';
      default:
        return 'mg';
    }
  }

  static String budgetLabel(String disease) {
    switch (disease) {
      case 'diabetes':
        return '碳水';
      case 'hypertension':
        return '胆固醇';
      default:
        return '嘌呤';
    }
  }
}
