/// 慢病饮食助手 API（多病种：disease + mode）
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class ApiConfig {
  /// 模拟器/桌面默认本机；真机请改为电脑局域网 IP，如 http://192.168.x.x:8081
  static String baseUrl = 'http://127.0.0.1:8081';
  static const prefKey = 'api_base_url';

  static void setBaseUrl(String url) {
    final t = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (t.isNotEmpty) baseUrl = t;
  }
}

class ApiResult<T> {
  final int code;
  final T? data;
  final String? message;
  final String? requestId;

  ApiResult({required this.code, this.data, this.message, this.requestId});

  bool get ok => code == 0;

  factory ApiResult.fromJson(Map<String, dynamic> json) {
    return ApiResult(
      code: (json['code'] as num?)?.toInt() ?? -1,
      data: json['data'] as dynamic,
      message: json['message'] as String?,
      requestId: json['request_id'] as String?,
    );
  }
}

class ApiCode {
  static const int ok = 0;
  static const int visionTimeout = 4001;
  static const int lowConfidence = 4002;
  static const int nutritionMiss = 4003;
  static const int badParam = 4004;
  static const int serverError = 5000;
}

class ApiException implements Exception {
  final int code;
  final String message;
  ApiException(this.code, this.message);

  @override
  String toString() => 'ApiException($code): $message';
}

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  ApiClient._();
  factory ApiClient() => _instance;

  final http.Client _http = http.Client();
  static const Duration _timeout = Duration(seconds: 20);

  Future<ApiResult<dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final resp = await _http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw ApiException(ApiCode.serverError, '响应格式异常');
      }
      return ApiResult.fromJson(decoded);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(ApiCode.serverError, '网络请求失败: $e');
    }
  }

  Future<ApiResult<dynamic>> _get(String path, Map<String, String> query) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);
      final resp = await _http.get(uri).timeout(_timeout);
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw ApiException(ApiCode.serverError, '响应格式异常');
      }
      return ApiResult.fromJson(decoded);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(ApiCode.serverError, '网络请求失败: $e');
    }
  }

  Future<ApiResult<dynamic>> recognizeSubmit({
    required String imageBase64,
    required String mode,
    required String disease,
  }) {
    return _post('/v1/meal/recognize', {
      'image_base64': imageBase64,
      'mode': mode,
      'disease': disease,
    });
  }

  Future<ApiResult<dynamic>> recognizeStatus(String taskId) {
    return _get('/v1/meal/recognize/status', {'task_id': taskId});
  }

  Future<ApiResult<dynamic>> mealAdvice({
    required List<Map<String, dynamic>> items,
    required String mode,
    required String disease,
  }) {
    return _post('/v1/meal/advice', {'items': items, 'mode': mode, 'disease': disease});
  }

  Future<ApiResult<dynamic>> nutritionLookup(
    String name, {
    double weightG = 100,
    required String disease,
  }) {
    return _post('/v1/nutrition/lookup', {
      'name': name,
      'weight_g': weightG,
      'disease': disease,
    });
  }

  Future<ApiResult<dynamic>> dailySummary({
    required String date,
    required String mode,
    required String disease,
    required Map<String, List<Map<String, dynamic>>> meals,
  }) {
    return _post('/v1/nutrition/daily', {
      'date': date,
      'mode': mode,
      'disease': disease,
      'meals': meals,
    });
  }

  Future<Map<String, dynamic>> recognizeFlow({
    required String imageBase64,
    required String mode,
    required String disease,
    void Function(String status, Duration elapsed)? onProgress,
  }) async {
    final submit = await recognizeSubmit(
      imageBase64: imageBase64,
      mode: mode,
      disease: disease,
    );
    if (!submit.ok) {
      throw ApiException(submit.code, submit.message ?? '提交识别失败');
    }
    final data = submit.data as Map<String, dynamic>;
    if ((data['cached'] as bool?) == true) {
      return (data['result'] as Map<String, dynamic>);
    }
    final taskId = data['task_id'] as String;
    final started = DateTime.now();
    while (true) {
      final elapsed = DateTime.now().difference(started);
      if (elapsed.inSeconds > 360) {
        throw ApiException(ApiCode.visionTimeout, '识别超时（>360s），请稍后重试');
      }
      final st = await recognizeStatus(taskId);
      if (!st.ok) {
        throw ApiException(st.code, st.message ?? '识别失败');
      }
      final stData = st.data as Map<String, dynamic>;
      final status = stData['status'] as String;
      onProgress?.call(status, elapsed);
      if (status == 'done') {
        return (stData['result'] as Map<String, dynamic>);
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }
}

class ImageUtil {
  static String compressToBase64(Uint8List bytes, {int targetKb = 1024, int quality = 80}) {
    if (bytes.length <= targetKb * 1024) {
      return base64Encode(bytes);
    }
    try {
      final original = img.decodeImage(bytes);
      if (original == null) {
        return base64Encode(bytes);
      }
      var current = original;
      for (var q = quality; q >= 40; q -= 10) {
        final encoded = img.encodeJpg(current, quality: q);
        if (encoded.length <= targetKb * 1024) {
          return base64Encode(encoded);
        }
        final longest = current.width >= current.height ? current.width : current.height;
        final w = (current.width * 0.8).round();
        if (longest < 200 || w < 100) break;
        current = img.copyResize(current, width: w);
      }
      return base64Encode(img.encodeJpg(current, quality: 40));
    } catch (_) {
      return base64Encode(bytes);
    }
  }
}
