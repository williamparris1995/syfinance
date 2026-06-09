import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const YuCaiApp());
}

class YuCaiApp extends StatelessWidget {
  const YuCaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '御财 YuCai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E40AF),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('御财 YuCai — Initializing...'),
        ),
      ),
    );
  }
}
