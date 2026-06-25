import 'dart:async';
import 'package:v2ray_stk/services/vpn_service_interface.dart';

class SingboxService implements VpnService {
  bool _isConnected = false;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> startVpn(String config) async {
    // در آینده: با flutter_singbox_client واقعی
    await Future.delayed(const Duration(seconds: 2));
    _isConnected = true;
    print('✅ Sing-box متصل شد (شبیه‌سازی)');
  }

  @override
  Future<void> stopVpn() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _isConnected = false;
    print('❌ Sing-box قطع شد (شبیه‌سازی)');
  }

  @override
  Future<void> toggleVpn(String config) async {
    if (_isConnected) {
      await stopVpn();
    } else {
      await startVpn(config);
    }
  }

  @override
  Future<String?> getStatus() async {
    return _isConnected ? 'Connected' : 'Disconnected';
  }
}
