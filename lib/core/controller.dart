import 'package:flutter/services.dart';

class CoreController {
  static const MethodChannel _channel = MethodChannel('core_channel');
  static const EventChannel _logChannel = EventChannel('core_logs');
  static const EventChannel _trafficChannel = EventChannel('core_traffic');

  static Future<String> startCore(String type, String config) async {
    try {
      final result = await _channel.invokeMethod('startCore', {
        'type': type,
        'config': config,
      });
      return result.toString();
    } on PlatformException catch (e) {
      return 'Error: ${e.message}';
    }
  }

  static Future<String> stopCore() async {
    try {
      final result = await _channel.invokeMethod('stopCore');
      return result.toString();
    } on PlatformException catch (e) {
      return 'Error: ${e.message}';
    }
  }

  static Future<String> switchCore(String type, String config) async {
    try {
      final result = await _channel.invokeMethod('switchCore', {
        'type': type,
        'config': config,
      });
      return result.toString();
    } on PlatformException catch (e) {
      return 'Error: ${e.message}';
    }
  }

  static Future<List<String>> fetchSubscription(String url) async {
    try {
      final result = await _channel.invokeMethod('fetchSubscription', {
        'url': url,
      });
      if (result is String) {
        return result.split('\n').where((s) => s.isNotEmpty).toList();
      }
      return [];
    } on PlatformException catch (e) {
      print('❌ خطا در دریافت اشتراک: ${e.message}');
      return [];
    }
  }

  static Future<String> getStatus() async {
    try {
      final result = await _channel.invokeMethod('getStatus');
      return result.toString();
    } on PlatformException catch (e) {
      return 'Error: ${e.message}';
    }
  }

  // ✅ مرحله 9: دریافت لاگ‌ها
  static Stream<String> getLogs() {
    return _logChannel.receiveBroadcastStream().cast<String>();
  }

  // ✅ مرحله 9: دریافت ترافیک
  static Stream<String> getTraffic() {
    return _trafficChannel.receiveBroadcastStream().cast<String>();
  }
}
