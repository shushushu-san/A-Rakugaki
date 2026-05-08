import 'package:flutter/material.dart';
import 'unity_view.dart';

import 'models/post.dart';
import 'screens/map_screen.dart';
import 'screens/sns_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A-Rakugaki',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _unityKey = GlobalKey<UnityARViewState>();
  List<Post> _posts = [];

  static const _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.white,
  ];

  void _onPostAdded(Post post) {
    setState(() => _posts = [post, ..._posts]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildARTab(),
          MapScreen(posts: _posts),
          SNSScreen(posts: _posts, onPostAdded: _onPostAdded),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.draw),
            label: 'AR落書き',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'マップ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'SNS',
          ),
        ],
      ),
    );
  }

  Widget _buildARTab() {
    return Stack(
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
    );
  }
}
