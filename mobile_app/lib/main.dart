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

class ARakugakiHome extends StatefulWidget {
  const ARakugakiHome({super.key});

  @override
  State<ARakugakiHome> createState() => _ARakugakiHomeState();
}

class _ARakugakiHomeState extends State<ARakugakiHome> {
  final _unityKey = GlobalKey<UnityARViewState>();

  static const _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.white,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          UnityARView(key: _unityKey),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ..._colors.map((color) => GestureDetector(
                  onTap: () => _unityKey.currentState?.setColor(color),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                  ),
                )),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _unityKey.currentState?.clearAll(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('消去', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
