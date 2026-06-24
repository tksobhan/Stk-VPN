import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V2RAY stk',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const SettingsPage(),
    const AdminPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'خانه'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'تنظیمات'),
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'ادمین'),
        ],
      ),
    );
  }
}

// ========== صفحه خانه ==========
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isConnected = false;

  void _toggleConnection() {
    setState(() {
      _isConnected = !_isConnected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('V2RAY stk'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
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

// ========== صفحه تنظیمات ==========
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isPersian = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // دکمه تغییر زبان
            Card(
              child: ListTile(
                leading: const Icon(Icons.language),
                title: Text(_isPersian ? 'زبان: فارسی' : 'زبان: انگلیسی'),
                trailing: Switch(
                  value: _isPersian,
                  onChanged: (value) {
                    setState(() {
                      _isPersian = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            // سایر تنظیمات (فعلاً فقط یک placeholder)
            Card(
              child: ListTile(
                leading: const Icon(Icons.vpn_key),
                title: const Text('مدیریت کانفیگ‌ها'),
                subtitle: const Text('افزودن، ویرایش و حذف کانفیگ‌ها'),
                onTap: () {
                  // در آینده
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('تنظیمات اتصال'),
                subtitle: const Text('Kill Switch، Mux و ...'),
                onTap: () {
                  // در آینده
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== صفحه ادمین ==========
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('پنل ادمین'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('پنل ادمین به زودی...'),
      ),
    );
  }
}
