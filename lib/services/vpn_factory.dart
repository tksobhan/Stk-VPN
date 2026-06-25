import 'package:v2ray_stk/services/vpn_service_interface.dart';
import 'package:v2ray_stk/services/singbox_service.dart';
import 'package:v2ray_stk/services/v2ray_service.dart';

enum VpnCore { singbox, v2ray }

class VpnFactory {
  static VpnService create(VpnCore core) {
    switch (core) {
      case VpnCore.singbox:
        return SingboxService();
      case VpnCore.v2ray:
        return V2rayService();
    }
  }
}
