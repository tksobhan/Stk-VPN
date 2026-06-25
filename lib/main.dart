import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V2RAY stk',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final V2ray _v2ray = V2ray(
    onStatusChanged: (status) {
      print('V2Ray status: ${status.state}');
    },
  );

  bool _isConnected = false;
  bool _isInitializing = true;

  static const String _tunConfig = '''
{
  "log": { "loglevel": "info" },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "address": ["172.19.0.1/30"],
      "mtu": 9000,
      "auto_route": true,
      "strict_route": true,
      "sniff": true,
      "sniff_override_destination": true
    }
  ],
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "104.24.75.124",
            "port": 2083,
            "users": [
              {
                "id": "528b1e29-c2a8-474a-82d7-b3300591536e",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "serverName": "delicate-mud-ce14.sobhantk.workers.dev",
          "fingerprint": "chrome"
        },
        "wsSettings": {
          "path": "/",
          "headers": {
            "Host": "delicate-mud-ce14.sobhantk.workers.dev"
          }
        }
      }
    }
  ],
  "route": {
    "rules": [
      {
        "outbound": "vless",
        "network": ["tcp", "udp"]
      }
    ]
  }
}
''';

  @override
  void initState() {
    super.initState();
    _initializeV2ray();
  }

  Future<void> _initializeV2ray() async {
    try {
      await _v2ray.initialize(
        notificationIconResourceType: "mipmap",
        notificationIconResourceName: "ic_launcher",
      );
      final hasPermission = await _v2ray.requestPermission();
      if (!hasPermission) {
        print('❌ مجوز VPN داده نشد');
      }
    } catch (e) {
      print('❌ خطا در مقداردهی اولیه: $e');
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _toggleConnection() async {
    if (_isInitializing) return;

    if (_isConnected) {
      await _v2ray.stopV2Ray();
      setState(() => _isConnected = false);
    } else {
      await _v2ray.startV2Ray(
        remark: 'V2RAY stk',
        config: _tunConfig,
      );
      setState(() => _isConnected = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('V2RAY stk')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isConnected ? Icons.vpn_lock : Icons.vpn_key,
              size: 80,
              color: _isConnected ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              _isConnected ? '✅ وصل شده' : '❌ قطع است',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _isConnected ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _toggleConnection,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Text(
                _isConnected ? 'قطع اتصال' : 'اتصال',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
