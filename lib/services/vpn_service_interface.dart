abstract class VpnService {
  bool get isConnected;
  Future<void> startVpn(String config);
  Future<void> stopVpn();
  Future<void> toggleVpn(String config);
  Future<String?> getStatus();
}
