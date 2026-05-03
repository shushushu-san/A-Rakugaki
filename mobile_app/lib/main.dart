import 'package:flutter/material.dart';
import 'unity_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A-Rakugaki',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const ARakugakiHome(),
    );
  }
}

class ARakugakiHome extends StatelessWidget {
  const ARakugakiHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: UnityARView(),
    );
  }
}
