import 'package:flutter/material.dart';
import 'package:v2ray_stk/core/controller.dart';
import 'package:v2ray_stk/services/config_service.dart';
import 'dart:convert';
import 'dart:typed_data';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String status = 'IDLE';
  String coreType = 'singbox';
  String? activeConfig;
  List<Map<String, String>> configs = [];
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _subController = TextEditingController();
  String _logs = '';
  String _traffic = '0 KB/s / 0 KB/s';

  @override
  void initState() {
    super.initState();
    _loadConfigs();
    _listenToLogs();
    _listenToTraffic();
  }

  Future<void> _loadConfigs() async {
    final loaded = await ConfigService.loadConfigs();
    final active = await ConfigService.loadActiveConfig();
    setState(() {
      configs = loaded;
      activeConfig = active;
    });
  }

  void _listenToLogs() {
    CoreController.getLogs().listen((log) {
      setState(() {
        _logs = log;
      });
    });
  }

  void _listenToTraffic() {
    CoreController.getTraffic().listen((data) {
      setState(() {
        _traffic = data;
      });
    });
  }

  // ✅ تبدیل VMESS
  String? _convertVmessToJson(String link) {
    try {
      final base64 = link.substring(8);
      final decoded = utf8.decode(base64Decode(base64));
      final json = jsonDecode(decoded);
      return jsonEncode({
        "type": "vmess",
        "tag": "proxy",
        "settings": {
          "vnext": [{
            "address": json['add'],
            "port": int.parse(json['port']),
            "users": [{
              "id": json['id'],
              "security": json['s'] ?? "auto",
              "alterId": int.parse(json['aid'] ?? "0")
            }]
          }]
        },
        "streamSettings": {
          "network": json['net'] ?? "tcp",
          "security": json['tls'] ?? "",
          "tlsSettings": {
            "serverName": json['sni'] ?? json['host'] ?? ""
          },
          "wsSettings": {
            "path": json['path'] ?? "/",
            "headers": {"Host": json['host'] ?? ""}
          }
        }
      });
    } catch (e) {
      return null;
    }
  }

  // ✅ تبدیل Trojan
  String? _convertTrojanToJson(String link) {
    try {
      final raw = link.substring(9);
      final atIndex = raw.indexOf('@');
      if (atIndex == -1) return null;
      final password = raw.substring(0, atIndex);
      final rest = raw.substring(atIndex + 1);
      final hostPort = rest.split('?')[0];
      final hostParts = hostPort.split(':');
      final address = hostParts[0];
      final port = int.tryParse(hostParts[1]) ?? 443;
      return jsonEncode({
        "type": "trojan",
        "tag": "proxy",
        "settings": {
          "servers": [{
            "address": address,
            "port": port,
            "password": password,
            "flow": ""
          }]
        },
        "streamSettings": {
          "network": "tcp",
          "security": "tls",
          "tlsSettings": {
            "serverName": "example.com",
            "fingerprint": "chrome"
          }
        }
      });
    } catch (e) {
      return null;
    }
  }

  // ✅ تبدیل Shadowsocks
  String? _convertShadowsocksToJson(String link) {
    try {
      final base64 = link.substring(5);
      final decoded = utf8.decode(base64Decode(base64));
      final parts = decoded.split('@');
      if (parts.length != 2) return null;
      final methodPass = parts[0].split(':');
      if (methodPass.length != 2) return null;
      final method = methodPass[0];
      final password = methodPass[1];
      final serverParts = parts[1].split(':');
      if (serverParts.length != 2) return null;
      final address = serverParts[0];
      final port = int.tryParse(serverParts[1]) ?? 443;
      return jsonEncode({
        "type": "shadowsocks",
        "tag": "proxy",
        "settings": {
          "servers": [{
            "address": address,
            "port": port,
            "method": method,
            "password": password
          }]
        }
      });
    } catch (e) {
      return null;
    }
  }

  // ✅ تبدیل VLESS با شرطی TLS (FIX 2)
  String? _convertVlessToJson(String link) {
    try {
      final raw = link.substring(8);
      final atIndex = raw.indexOf('@');
      if (atIndex == -1) return null;
      final userPart = raw.substring(0, atIndex);
      final rest = raw.substring(atIndex + 1);
      final hostPort = rest.split('?')[0];
      final query = rest.contains('?') ? rest.split('?')[1] : '';
      final hostParts = hostPort.split(':');
      final address = hostParts[0];
      final port = int.tryParse(hostParts[1]) ?? 443;

      Map<String, String> params = {};
      if (query.isNotEmpty) {
        query.split('&').forEach((pair) {
          final parts = pair.split('=');
          if (parts.length == 2) {
            params[parts[0]] = Uri.decodeComponent(parts[1]);
          }
        });
      }

      final path = params['path'] ?? '/';
      final security = params['security'] ?? 'tls';
      final encryption = params['encryption'] ?? 'none';
      final host = params['host'] ?? address;
      final sni = params['sni'] ?? host;
      final fp = params['fp'] ?? 'chrome';
      final type = params['type'] ?? 'ws';

      // ✅ شرطی: TLS فقط در صورت نیاز
      final streamSettings = <String, dynamic>{};
      streamSettings["network"] = type;

      if (security == "tls") {
        streamSettings["security"] = "tls";
        streamSettings["tlsSettings"] = {
          "serverName": sni,
          "fingerprint": fp
        };
      }

      if (type == "ws") {
        streamSettings["wsSettings"] = {
          "path": path,
          "headers": {"Host": host}
        };
      }

      final jsonConfig = {
        "log": {"loglevel": "info"},
        "inbounds": [
          {
            "type": "tun",
            "tag": "tun-in",
            "address": ["172.19.0.1/30"],
            "mtu": 1500,
            "auto_route": true,
            "strict_route": true,
            "sniff": true,
            "sniff_override_destination": true
          }
        ],
        "outbounds": [
          {
            "type": "vless",
            "tag": "proxy",
            "settings": {
              "vnext": [
                {
                  "address": address,
                  "port": port,
                  "users": [
                    {"id": userPart, "encryption": encryption}
                  ]
                }
              ]
            },
            "streamSettings": streamSettings
          }
        ],
        "route": {"final": "proxy"}
      };
      return const JsonEncoder.withIndent('  ').convert(jsonConfig);
    } catch (e) {
      return null;
    }
  }

  // ✅ تبدیل هر نوع لینک
  String? _convertAnyToJson(String link) {
    if (link.startsWith('vless://')) return _convertVlessToJson(link);
    if (link.startsWith('vmess://')) return _convertVmessToJson(link);
    if (link.startsWith('trojan://')) return _convertTrojanToJson(link);
    if (link.startsWith('ss://')) return _convertShadowsocksToJson(link);
    return null;
  }

  void _addConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('افزودن کانفیگ'),
        content: TextField(
          controller: _linkController,
          decoration: const InputDecoration(
            labelText: 'لینک (vless://, vmess://, trojan://, ss://)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () async {
              final link = _linkController.text.trim();
              if (link.isEmpty) return;
              final json = _convertAnyToJson(link);
              if (json == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لینک نامعتبر است')),
                );
                return;
              }
              final host = link.contains('@')
                  ? link.split('@')[1].split('?')[0]
                  : 'unknown';
              final name = link.split('://')[0].toUpperCase() + ' - ' + host;
              setState(() {
                configs.add({
                  'name': name,
                  'address': json,
                  'status': 'غیرفعال',
                });
              });
              await ConfigService.saveConfigs(configs);
              Navigator.pop(context);
              _linkController.clear();
            },
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
  }

  void _subscriptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اشتراک'),
        content: TextField(
          controller: _subController,
          decoration: const InputDecoration(
            labelText: 'لینک اشتراک',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () async {
              final url = _subController.text.trim();
              if (url.isEmpty) return;
              final nodes = await CoreController.fetchSubscription(url);
              if (nodes.isNotEmpty) {
                for (var node in nodes) {
                  final json = _convertAnyToJson(node);
                  if (json != null) {
                    final host = node.contains('@')
                        ? node.split('@')[1].split('?')[0]
                        : 'unknown';
                    final name = node.split('://')[0].toUpperCase() + ' - ' + host;
                    setState(() {
                      configs.add({
                        'name': name,
                        'address': json,
                        'status': 'غیرفعال',
                      });
                    });
                    await ConfigService.saveConfigs(configs);
                  }
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ ${nodes.length} کانفیگ اضافه شد')),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('دریافت'),
          ),
        ],
      ),
    );
  }

  void _setActive(String address) async {
    await ConfigService.saveActiveConfig(address);
    setState(() {
      activeConfig = address;
      for (var c in configs) {
        c['status'] = (c['address'] == address) ? 'فعال' : 'غیرفعال';
      }
    });
  }

  Future<void> _connect() async {
    if (activeConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً ابتدا یک کانفیگ را فعال کنید')),
      );
      return;
    }
    try {
      final result = await CoreController.startCore(coreType, activeConfig!);
      if (result.contains("Started")) {
        setState(() => status = 'CONNECTED');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ VPN متصل شد')),
        );
      } else {
        setState(() => status = 'ERROR');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطا: $result')),
        );
      }
    } catch (e) {
      setState(() => status = 'ERROR');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطا: $e')),
      );
    }
  }

  Future<void> _disconnect() async {
    try {
      final result = await CoreController.stopCore();
      setState(() => status = 'DISCONNECTED');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ VPN قطع شد')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطا: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('V2RAY STK'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addConfigDialog,
            tooltip: 'افزودن کانفیگ',
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download),
            onPressed: _subscriptionDialog,
            tooltip: 'اشتراک',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  status == 'CONNECTED' ? Icons.vpn_lock : Icons.vpn_key,
                  color: status == 'CONNECTED' ? Colors.green : Colors.grey,
                ),
                title: Text('وضعیت: $status'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('هسته: $coreType'),
                    Text('ترافیک: $_traffic', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _connect,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('اتصال'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _disconnect,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('قطع اتصال'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_logs.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _logs,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: configs.length,
                itemBuilder: (context, index) {
                  final config = configs[index];
                  final isActive = activeConfig == config['address'];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isActive ? Colors.green : Colors.grey,
                      ),
                      title: Text(config['name'] ?? 'بدون نام'),
                      subtitle: Text(
                        'طول: ${config['address']?.length ?? 0}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: isActive
                          ? const Chip(label: Text('فعال'), backgroundColor: Colors.green)
                          : const Chip(label: Text('غیرفعال'), backgroundColor: Colors.grey),
                      onTap: () => _setActive(config['address']!),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
