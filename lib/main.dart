import 'package:flutter/material.dart';
import 'package:v2ray_stk/services/preferences_service.dart';
import 'package:v2ray_stk/services/vpn_service.dart';
import 'package:v2ray_stk/services/config_service.dart';
import 'package:v2ray_stk/services/notification_service.dart';
import 'package:v2ray_stk/ui/dashboard.dart';
import 'dart:convert';
import 'dart:core';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V2RAY stk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
