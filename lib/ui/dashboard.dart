import 'package:flutter/material.dart';
import 'package:v2ray_stk/core/controller.dart';
import 'package:v2ray_stk/services/config_service.dart';
import 'dart:convert';

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

  // ✅ مرحله 9: دریافت لاگ‌ها
  void _listenToLogs() {
    CoreController.getLogs().listen((log) {
      setState(() {
        _logs = log;
      });
    });
  }

  // ✅ مرحله 9: دریافت ترافیک
  void _listenToTraffic() {
    CoreController.getTraffic().listen((data) {
      setState(() {
        _traffic = data;
      });
    });
  }

  // ✅ مرحله 12: تبدیل انواع لینک
  String? _convertAnyToJson(String link) {
    if (link.startsWith('vless://')) {
      return _convertVlessToJson(link);
    } else if (link.startsWith('vmess://')) {
      return _convertVmessToJson(link);
    } else if (link.startsWith('trojan://')) {
      return _convertTrojanToJson(link);
    } else if (link.startsWith('ss://')) {
      return _convertShadowsocksToJson(link);
    }
    return null;
  }

  // ✅ مرحله 15: Config معتبر sing-box
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
      final jsonConfig = {
        "log": {"level": "info"},
        "dns": {"servers": ["1.1.1.1"]},
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
            "streamSettings": {
              "network": type,
              "security": security,
              "tlsSettings": {"serverName": sni, "fingerprint": fp},
              "wsSettings": {
                "path": path,
                "headers": {"Host": host}
              }
            }
          }
        ],
        "route": {"final": "proxy"}
      };
      return const JsonEncoder.withIndent('  ').convert(jsonConfig);
    } catch (e) {
      return null;
    }
  }

  String? _convertVmessToJson(String link) {
    return '{"type":"vmess","raw":"$link"}';
  }

  String? _convertTrojanToJson(String link) {
    return '{"type":"trojan","raw":"$link"}';
  }

  String? _convertShadowsocksToJson(String link) {
    return '{"type":"ss","raw":"$link"}';
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
              // ✅ مرحله 13: رفع RangeError
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
      // ✅ مرحله 10: اصلاح وضعیت اتصال
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
