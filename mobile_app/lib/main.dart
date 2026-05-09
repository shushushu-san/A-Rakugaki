import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'unity_view.dart';

import 'firebase_options.dart';
import 'models/post.dart';
import 'services/auth_service.dart';
import 'services/post_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'screens/favorites_screen.dart';
import 'screens/map_screen.dart';
import 'screens/sns_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );
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
  List<Post> _posts = [];
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _initAuth();
    PostService.instance.watchPosts().listen((posts) {
      if (mounted) setState(() => _posts = posts);
    });
  }

  Future<void> _initAuth() async {
    final uid = await AuthService.instance.signInIfNeeded();
    if (mounted) setState(() => _userId = uid ?? '');
  }

  bool _captureMode = false;
  bool _capturing = false;
  void Function(File?)? _onCaptureDone;

  Color _penColor = Colors.red;
  double _brushSize = 0.005;
  bool _isErasing = false;

  Future<void> _onPostAdded(Post post) async {
    await PostService.instance.createPost(
      comment: post.comment,
      lat: post.location.latitude,
      lng: post.location.longitude,
      userId: _userId,
      imageFile: post.image,
    );
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
            userId: _userId,
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

  void _setColor(Color color) {
    setState(() {
      _penColor = color;
      _isErasing = false;
    });
    _unityKey.currentState?.setEraser(false);
    _unityKey.currentState?.setColor(color);
  }

  void _toggleEraser() {
    setState(() => _isErasing = !_isErasing);
    _unityKey.currentState?.setEraser(_isErasing);
  }

  void _setBrushSize(double size) {
    setState(() => _brushSize = size);
    _unityKey.currentState?.setWidth(size);
  }

  Future<void> _openColorPicker() async {
    Color picked = _penColor;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('色を選ぶ', style: TextStyle(color: kWhite)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル', style: TextStyle(color: kGrey)),
          ),
          FilledButton(
            onPressed: () {
              _setColor(picked);
              Navigator.of(context).pop();
            },
            child: const Text('決定'),
          ),
        ],
      ),
    );
  }

  Widget _buildARControls() {
    return Positioned(
      bottom: 32,
      left: 12,
      right: 12,
      child: _DrawingToolbar(
        penColor: _penColor,
        brushSize: _brushSize,
        isErasing: _isErasing,
        onColorTap: _openColorPicker,
        onEraserTap: _toggleEraser,
        onUndo: () => _unityKey.currentState?.undo(),
        onClear: () => _unityKey.currentState?.clearAll(),
        onSizeChanged: _setBrushSize,
      ),
    );
  }

  Widget _buildCaptureOverlay() {
    final top = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        Positioned(
          top: top + 8,
          left: 8,
          child: IconButton(
            onPressed: _cancelCapture,
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black38),
          ),
        ),
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
        Positioned(
          bottom: 32,
          left: 12,
          right: 12,
          child: Column(
            children: [
              _DrawingToolbar(
                penColor: _penColor,
                brushSize: _brushSize,
                isErasing: _isErasing,
                onColorTap: _openColorPicker,
                onEraserTap: _toggleEraser,
                onUndo: () => _unityKey.currentState?.undo(),
                onClear: () => _unityKey.currentState?.clearAll(),
                onSizeChanged: _setBrushSize,
              ),
              const SizedBox(height: 16),
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

// ---------------------------------------------------------------------------
// 描画ツールバー（通常ARモード・キャプチャモード共用）
// ---------------------------------------------------------------------------
class _DrawingToolbar extends StatelessWidget {
  final Color penColor;
  final double brushSize;
  final bool isErasing;
  final VoidCallback onColorTap;
  final VoidCallback onEraserTap;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final ValueChanged<double> onSizeChanged;

  const _DrawingToolbar({
    required this.penColor,
    required this.brushSize,
    required this.isErasing,
    required this.onColorTap,
    required this.onEraserTap,
    required this.onUndo,
    required this.onClear,
    required this.onSizeChanged,
  });

  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? kRed : Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(color: active ? kRed : Colors.white30, width: 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // カラーピッカー
              GestureDetector(
                onTap: onColorTap,
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: penColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isErasing ? Colors.white30 : Colors.white,
                      width: isErasing ? 1.5 : 3,
                    ),
                  ),
                ),
              ),
              // 消しゴム
              _iconBtn(
                icon: Icons.auto_fix_normal,
                onTap: onEraserTap,
                active: isErasing,
                tooltip: '消しゴム',
              ),
              // アンドゥ
              _iconBtn(
                icon: Icons.undo,
                onTap: onUndo,
                tooltip: '一つ戻す',
              ),
              // 全消去
              _iconBtn(
                icon: Icons.delete_outline,
                onTap: onClear,
                tooltip: '全消去',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ブラシサイズスライダー
          Row(
            children: [
              const Icon(Icons.brush, color: Colors.white54, size: 16),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: kRed,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: kRed,
                    overlayColor: kRed.withValues(alpha: 0.2),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: brushSize,
                    min: 0.002,
                    max: 0.02,
                    onChanged: onSizeChanged,
                  ),
                ),
              ),
              const Icon(Icons.brush, color: Colors.white, size: 22),
            ],
          ),
        ],
      ),
    );
  }
}
