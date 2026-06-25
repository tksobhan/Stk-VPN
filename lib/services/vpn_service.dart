import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:v2ray_stk/services/notification_service.dart';

class VpnService {
  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;
  VpnService._internal();

  final V2Ray _v2ray = V2Ray();
  bool _isConnected = false;
  final NotificationService _notif = NotificationService();

  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    await _notif.init();
    print('✅ V2Ray و نوتیفیکیشن مقداردهی اولیه شدند');
  }

  Future<void> startVpn(String config) async {
    try {
      await _v2ray.startV2Ray(
        remark: 'V2RAY stk',
        config: config,
        useSystemProxy: false,
      );
      _isConnected = true;
      await _notif.showPersistentNotification(
        '✅ VPN وصل شد',
        'در حال حفاظت از اتصال شما',
      );
      print('✅ V2Ray متصل شد');
    } catch (e) {
      print('❌ خطا در اتصال V2Ray: $e');
      _isConnected = false;
      rethrow;
    }
  }

  Future<void> stopVpn() async {
    try {
      await _v2ray.stopV2Ray();
      _isConnected = false;
      await _notif.cancelAll();
      await _notif.showNotification(
        '❌ VPN قطع شد',
        'اتصال VPN قطع گردید',
      );
      print('❌ V2Ray قطع شد');
    } catch (e) {
      print('❌ خطا در قطع V2Ray: $e');
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

  Future<String?> getStatus() async {
    try {
      return await _v2ray.getStatus();
    } catch (e) {
      return null;
    }
  }
}
