import 'package:v2ray_flutter/v2ray_flutter.dart';

class VpnService {
  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;
  VpnService._internal();

  final V2RayFlutter _v2ray = V2RayFlutter();
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    // v2ray_flutter نیازی به مقداردهی اولیه جداگانه ندارد
    print('✅ V2RayFlutter مقداردهی اولیه شد');
  }

  Future<void> startVpn(String config) async {
    try {
      await _v2ray.startV2Ray(config: config);
      _isConnected = true;
      print('✅ V2RayFlutter متصل شد');
    } catch (e) {
      print('❌ خطا در اتصال V2RayFlutter: $e');
      _isConnected = false;
      rethrow;
    }
  }

  Future<void> stopVpn() async {
    try {
      await _v2ray.stopV2Ray();
      _isConnected = false;
      print('❌ V2RayFlutter قطع شد');
    } catch (e) {
      print('❌ خطا در قطع V2RayFlutter: $e');
      rethrow;
    }
  }

  Future<void> toggleVpn(String config) async {
    if (_isConnected) {
      await stopVpn();
    } else {
      await startVpn(config);
    }
  }

  Future<bool> isRunning() async {
    try {
      return await _v2ray.isRunning();
    } catch (e) {
      return false;
    }
  }
}
