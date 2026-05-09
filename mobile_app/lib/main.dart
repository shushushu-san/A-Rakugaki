import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'unity_view.dart';

import 'models/post.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'screens/favorites_screen.dart';
import 'screens/map_screen.dart';
import 'screens/sns_screen.dart';
import 'theme.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A-RAKUGAKI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _unityKey = GlobalKey<UnityARViewState>();
  final _arRepaintKey = GlobalKey();
  final _snsKey = GlobalKey<SNSScreenState>();
  final _mapKey = GlobalKey<MapScreenState>();

  int _currentIndex = 0;
  final List<Post> _favorites = [];

  List<Post> _posts = [
    Post(
      id: 'dummy_1',
      comment: '渋谷スクランブル交差点に落書きしてみた！人多すぎてARで描くの難しかった笑',
      location: const LatLng(35.6595, 139.7004),
      createdAt: DateTime(2026, 5, 1, 14, 30),
    ),
    Post(
      id: 'dummy_2',
      comment: '浅草寺の前に巨大な龍を描いた。観光客に見せたい',
      location: const LatLng(35.7148, 139.7967),
      createdAt: DateTime(2026, 5, 3, 10, 0),
    ),
    Post(
      id: 'dummy_3',
      comment: '新宿御苑の桜の木に虹色のペイントを追加。春っぽくしてみた',
      location: const LatLng(35.6852, 139.7100),
      createdAt: DateTime(2026, 5, 5, 16, 45),
    ),
  ];

  bool _captureMode = false;
  bool _capturing = false;
  void Function(File?)? _onCaptureDone;

  static const _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.white,
  ];

  void _onPostAdded(Post post) {
    setState(() => _posts = [post, ..._posts]);
  }

  void _toggleFavorite(Post post) {
    setState(() {
      final exists = _favorites.any((f) => f.id == post.id);
      if (exists) {
        _favorites.removeWhere((f) => f.id == post.id);
      } else {
        _favorites.add(post);
      }
    });
  }

  bool _isFavorited(String postId) => _favorites.any((f) => f.id == postId);

  void _navigateToMapLocation(LatLng location) {
    setState(() => _currentIndex = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapKey.currentState?.moveToLocation(location);
    });
  }

  void enterCaptureMode(void Function(File?) onDone) {
    setState(() {
      _currentIndex = 2;
      _captureMode = true;
      _onCaptureDone = onDone;
    });
  }

  void _cancelCapture() {
    _onCaptureDone?.call(null);
    setState(() {
      _captureMode = false;
      _currentIndex = 0;
      _onCaptureDone = null;
    });
  }

  Future<void> _finishCapture() async {
    setState(() => _capturing = true);
    try {
      final boundary = _arRepaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File(
          '${Directory.systemTemp.path}/ar_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      _onCaptureDone?.call(file);
    } catch (_) {
      _onCaptureDone?.call(null);
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
          _captureMode = false;
          _currentIndex = 0;
          _onCaptureDone = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        // キャプチャモード時はAR(index 3)を表示
        index: _captureMode ? 3 : _currentIndex,
        children: [
          SNSScreen(
            key: _snsKey,
            posts: _posts,
            onPostAdded: _onPostAdded,
            onARCaptureRequested: enterCaptureMode,
            isFavorited: _isFavorited,
            onFavoriteToggle: _toggleFavorite,
          ),
          MapScreen(key: _mapKey, posts: _posts),
          FavoritesScreen(
            favorites: _favorites,
            onRemove: _toggleFavorite,
            onNavigateToMap: _navigateToMapLocation,
          ),
          _buildARTab(), // index 3: キャプチャモード専用
        ],
      ),
      bottomNavigationBar: _captureMode
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.people), label: 'タイムライン'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.map), label: 'マップ'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.star), label: 'お気に入り'),
              ],
            ),
    );
  }

  Widget _buildARTab() {
    return Stack(
      children: [
        RepaintBoundary(
          key: _arRepaintKey,
          child: UnityARView(key: _unityKey),
        ),
        if (_captureMode) _buildCaptureOverlay() else _buildARControls(),
      ],
    );
  }

  Widget _buildARControls() {
    return Positioned(
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child:
                  const Text('消去', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureOverlay() {
    final top = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        // キャンセルボタン
        Positioned(
          top: top + 8,
          left: 8,
          child: IconButton(
            onPressed: _cancelCapture,
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black38),
          ),
        ),
        // ガイドテキスト
        Positioned(
          top: top + 12,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              '落書きして決定を押せ',
              style: GoogleFonts.bebasNeue(
                color: kRed,
                fontSize: 20,
                letterSpacing: 3,
                shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
              ),
            ),
          ),
        ),
        // 色ボタン + 確定ボタン
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ..._colors.map((color) => GestureDetector(
                        onTap: () =>
                            _unityKey.currentState?.setColor(color),
                        child: Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 8),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.grey, width: 2),
                          ),
                        ),
                      )),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _unityKey.currentState?.clearAll(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('消去',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _capturing ? null : _finishCapture,
                icon: _capturing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: const Text('この落書きを使う'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
