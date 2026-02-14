import 'package:flutter/material.dart';
import 'qf_mask_page.dart';
//起動
void main() {
  runApp(const QFMaskApp());
}

class QFMaskApp extends StatelessWidget {
  const QFMaskApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QF-MASK',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const QFMaskPage(),
    );
  }
}