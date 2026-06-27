import 'package:flutter_v2ray_client/flutter_v2ray.dart';

class VpnService {
  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;
  VpnService._internal();

  final V2ray _v2ray = V2ray(
    onStatusChanged: (status) {
      print('V2Ray status: ${status.state}');
    },
  );

  bool _isConnected = false;
  bool _isInitialized = false;

  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _v2ray.initialize(
      notificationIconResourceType: "mipmap",
      notificationIconResourceName: "ic_launcher",
    );
    _isInitialized = true;
  }

  Future<void> connect(String config) async {
    if (!_isInitialized) await initialize();
    try {
      await _v2ray.startV2Ray(
        remark: 'V2RAY stk',
        config: config,
        useSystemProxy: false,
      );
      _isConnected = true;
    } catch (e) {
      _isConnected = false;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      await _v2ray.stopV2Ray();
      _isConnected = false;
    } catch (e) {
      rethrow;
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
