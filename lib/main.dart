import 'package:adb_connector/pages/home_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const AdbConnectorApp());
}

class AdbConnectorApp extends StatelessWidget {
  const AdbConnectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB Connector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
