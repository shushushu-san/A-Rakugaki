import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'unity_view.dart';

import 'firebase_options.dart';
import 'models/geospatial.dart';
import 'models/post.dart';
import 'services/auth_service.dart';
import 'services/post_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'screens/favorites_screen.dart';
import 'screens/map_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/sns_screen.dart';
import 'theme.dart';
import 'widgets/nearby_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const MyApp());
}

/// AR キャプチャモードからの戻り値。
/// 画像（プレビュー）に加えて、VPS取得済みなら Geospatial Pose と 3D ストロークも含む。
class CaptureResult {
  final File? image;
  final GeospatialPose? pose;
  final List<Stroke> strokes;
  const CaptureResult({
    this.image,
    this.pose,
    this.strokes = const [],
  });
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
  Set<String> _favoriteIds = {};
  List<Post> _posts = [];
  String _userId = '';

  static const _favoritesKey = 'favorite_post_ids';

  @override
  void initState() {
    super.initState();
    _initAuth();
    _loadFavoriteIds();
    PostService.instance.watchPosts().listen((posts) {
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _favorites
          ..clear()
          ..addAll(posts.where((p) => _favoriteIds.contains(p.id)));
      });
    });
  }

  Future<void> _initAuth() async {
    final uid = await AuthService.instance.signInIfNeeded();
    if (mounted) setState(() => _userId = uid ?? '');
  }

  Future<void> _loadFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_favoritesKey) ?? [];
    if (mounted) setState(() => _favoriteIds = ids.toSet());
  }

  Future<void> _saveFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favoriteIds.toList());
  }

  bool _captureMode = false;
  bool _capturing = false;
  void Function(CaptureResult)? _onCaptureDone;

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
      if (_favoriteIds.contains(post.id)) {
        _favoriteIds.remove(post.id);
        _favorites.removeWhere((f) => f.id == post.id);
      } else {
        _favoriteIds.add(post.id);
        _favorites.add(post);
      }
    });
    _saveFavoriteIds();
  }

  bool _isFavorited(String postId) => _favoriteIds.contains(postId);

  void _navigateToMapLocation(LatLng location) {
    setState(() => _currentIndex = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapKey.currentState?.moveToLocation(location);
    });
  }

  void enterCaptureMode(void Function(CaptureResult) onDone) {
    setState(() {
      _currentIndex = 2;
      _captureMode = true;
      _onCaptureDone = onDone;
    });
    // Unity 側を描画モードに切り替え（VPS 取得開始）
    _unityKey.currentState?.startDrawMode();
  }

  void _cancelCapture() {
    _onCaptureDone?.call(const CaptureResult(image: null));
    setState(() {
      _captureMode = false;
      _currentIndex = 0;
      _onCaptureDone = null;
    });
  }

  Future<void> _finishCapture() async {
    setState(() => _capturing = true);
    File? capturedFile;
    GeospatialPose? pose;
    List<Stroke> strokes = const [];
    try {
      // 1. 画面キャプチャ（プレビュー画像）
      final boundary = _arRepaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      capturedFile = File(
          '${Directory.systemTemp.path}/ar_${DateTime.now().millisecondsSinceEpoch}.png');
      await capturedFile.writeAsBytes(bytes);

      // 2. Unity 側から Geospatial Pose を取得（VPS が確立していれば成功）
      try {
        final poseRes = await _unityKey.currentState!.requestCurrentPose();
        if (poseRes['ok'] == true) {
          pose = GeospatialPose.fromJson(Map<String, dynamic>.from(poseRes));
        }
      } catch (_) {
        // VPS 取得失敗（屋内・カバレッジ外など）。pose=null のまま続行。
      }

      // 3. ストロークデータを取得（あれば）
      try {
        final strokesRes =
            await _unityKey.currentState!.requestDrawnStrokes();
        final list = strokesRes['strokes'] as List?;
        if (list != null) {
          strokes = list
              .map((e) =>
                  Stroke.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } catch (_) {/* ストローク取得失敗は無視 */}
    } catch (_) {/* ignore */} finally {
      _onCaptureDone?.call(CaptureResult(
        image: capturedFile,
        pose: pose,
        strokes: strokes,
      ));
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

  void _openNearbyPost(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PostDetailScreen(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
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
          // 近接バナー（キャプチャモード中・ARタブ中は非表示）
          if (!_captureMode && _currentIndex != 3)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: NearbyBanner(
                  posts: _posts,
                  onOpen: _openNearbyPost,
                ),
              ),
            ),
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
        // NOTE: 上書きモード時に既存作品をゴースト表示する案は、
        // 端末ごとの FOV / 画面比率差で位置が一致しないため一旦無効化。
        // 将来 ARCore Anchor で対応する想定。
        if (_captureMode) _buildCaptureOverlay() else _buildARControls(),
      ],
    );
  }

  void _setColor(Color color) {
    setState(() {
      _penColor = color;
      _isErasing = false;
    });
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

  Future<void> _handleColorTap(Color? preset) async {
    if (preset != null) {
      _setColor(preset);
      return;
    }
    // カスタムカラーピッカー
    Color picked = _penColor;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kCard,
          title: const Text('色を選ぶ', style: TextStyle(color: kWhite)),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: picked,
              onColorChanged: (c) => setDialogState(() => picked = c),
              enableAlpha: false,
              labelTypes: const [],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル', style: TextStyle(color: kGrey)),
            ),
            FilledButton(
              onPressed: () {
                _setColor(picked);
                Navigator.of(ctx).pop();
              },
              child: const Text('決定'),
            ),
          ],
        ),
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
        onColorTap: _handleColorTap,
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
          top: top + 56,
          left: 12,
          right: 12,
          child: _DrawingToolbar(
            penColor: _penColor,
            brushSize: _brushSize,
            isErasing: _isErasing,
            onColorTap: _handleColorTap,
            onEraserTap: _toggleEraser,
            onUndo: () => _unityKey.currentState?.undo(),
            onClear: () => _unityKey.currentState?.clearAll(),
            onSizeChanged: _setBrushSize,
          ),
        ),
        Positioned(
          bottom: 32,
          left: 12,
          right: 12,
          child: Column(
            children: [
              Text(
                '落書きして決定を押せ',
                style: GoogleFonts.bebasNeue(
                  color: kRed,
                  fontSize: 20,
                  letterSpacing: 3,
                  shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
              const SizedBox(height: 12),
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
  final void Function(Color?) onColorTap;
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
          // プリセットカラー + カスタムピッカー
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...[Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.white, Colors.black].map((c) {
                final selected = !isErasing && penColor.toARGB32() == c.toARGB32();
                return GestureDetector(
                  onTap: () => onColorTap(c),
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.white38,
                        width: selected ? 3 : 1.5,
                      ),
                    ),
                  ),
                );
              }),
              // カスタムカラーピッカー
              GestureDetector(
                onTap: () => onColorTap(null),
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38, width: 1.5),
                    gradient: const SweepGradient(colors: [
                      Colors.red, Colors.yellow, Colors.green,
                      Colors.cyan, Colors.blue, Colors.purple, Colors.red,
                    ]),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 操作ボタン行
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
