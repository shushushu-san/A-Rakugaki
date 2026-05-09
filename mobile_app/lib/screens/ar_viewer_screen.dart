import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/post.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../utils/proximity.dart';

/// 投稿地点を「ワールド固定」で見せるARビューワー。
///
/// 方位（コンパス）+ ピッチ（上下角）から、作品が画面のどこに見えるべきかを
/// 計算して表示する。カメラを別方向に向けると作品は画面外に消える。
class ARViewerScreen extends StatefulWidget {
  final Post post;
  const ARViewerScreen({super.key, required this.post});

  @override
  State<ARViewerScreen> createState() => _ARViewerScreenState();
}

class _ARViewerScreenState extends State<ARViewerScreen>
    with WidgetsBindingObserver {
  // ---- 端末カメラ ----
  CameraController? _camera;
  Future<void>? _cameraInit;

  // ---- センサー購読 ----
  StreamSubscription<Position>? _posSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<AccelerometerEvent>? _accSub;

  // ---- 状態 ----
  Position? _here;
  double _heading = 0; // 度（北=0、時計回り）
  double _pitch = 0; // 度（上向きが正）
  double _mx = 0, _my = 0, _mz = 0;
  double _ax = 0, _ay = 0, _az = -9.8;

  // ---- 表示設定 ----
  // 画面の縦・横FOV（度）。多くのスマホ縦持ちでこの範囲。
  // 大きすぎると作品が小さく表示され、小さすぎると追尾がガクつく感覚になる。
  double _hFovDeg = 55;
  double _vFovDeg = 70;
  // 作品の物理サイズ（m）の想定値。距離スケール計算に使う。
  double _assumedSize = 2.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _initSensors();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return;
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _camera = controller;
      _cameraInit = controller.initialize();
      await _cameraInit;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _initSensors() {
    _posSub = LocationService.instance.positionStream.listen((p) {
      if (mounted) setState(() => _here = p);
    }, onError: (_) {});
    _here = LocationService.instance.lastPosition;

    _magSub = magnetometerEventStream().listen((e) {
      _mx = e.x;
      _my = e.y;
      _mz = e.z;
      _recompute();
    });
    _accSub = accelerometerEventStream().listen((e) {
      _ax = e.x;
      _ay = e.y;
      _az = e.z;
      _recompute();
    });
  }

  /// 端末の向き（heading, pitch）を更新する。
  ///
  /// 縦持ちを想定。Android センサ座標系:
  ///   X: 端末の右、Y: 端末の上、Z: 画面手前（ユーザー側）
  /// バックカメラは -Z 方向を向く。
  void _recompute() {
    // 重力単位ベクトル
    final gNorm = math.sqrt(_ax * _ax + _ay * _ay + _az * _az);
    if (gNorm == 0) return;
    final gx = _ax / gNorm;
    final gy = _ay / gNorm;
    final gz = _az / gNorm;

    // ---- pitch（バックカメラの仰角） ----
    // 端末縦持ちの基本姿勢: ax=0, ay=-1, az=0 → pitch=0（カメラ水平）
    // 仰向けに倒すと az が負方向に振れる → カメラは上を向く（pitch>0）
    final hMag = math.sqrt(_ax * _ax + _ay * _ay);
    final pitchRad = math.atan2(-_az, hMag);

    // ---- heading（北からの時計回り、バックカメラの向き） ----
    // East = mag × gravity（地球磁場の水平成分から東を求める）
    final ex = _my * gz - _mz * gy;
    final ey = _mz * gx - _mx * gz;
    final ez = _mx * gy - _my * gx;
    final eNorm = math.sqrt(ex * ex + ey * ey + ez * ez);
    if (eNorm == 0) return;
    final exN = ex / eNorm;
    final eyN = ey / eNorm;
    final ezN = ez / eNorm;
    // North = gravity × East（z成分のみ使用：バックカメラ方向の北軸成分計算用）
    final nz = gx * eyN - gy * exN;

    // バックカメラ方向 (-Z in 端末座標) をワールド水平面に射影
    // 北軸成分 = -Z · North、東軸成分 = -Z · East
    final camN = -nz;
    final camE = -ezN;
    var headingRad = math.atan2(camE, camN);
    if (headingRad < 0) headingRad += 2 * math.pi;

    final newHeading = headingRad * 180 / math.pi;
    final newPitch = pitchRad * 180 / math.pi;
    if (mounted) {
      setState(() {
        _heading = newHeading;
        _pitch = newPitch;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _camera;
    if (ctrl == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      ctrl.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _posSub?.cancel();
    _magSub?.cancel();
    _accSub?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  // ---- 計算 ----

  double? _distance() {
    final h = _here;
    if (h == null) return null;
    return distanceMeters(
        LatLng(h.latitude, h.longitude), widget.post.location);
  }

  double? _bearingToPost() {
    final h = _here;
    if (h == null) return null;
    final lat1 = h.latitude * math.pi / 180;
    final lat2 = widget.post.location.latitude * math.pi / 180;
    final dLng =
        (widget.post.location.longitude - h.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    var b = math.atan2(y, x) * 180 / math.pi;
    return (b + 360) % 360;
  }

  /// カメラ方向と作品方位の差分（左:負、右:正、-180〜180）
  double? _relativeBearing() {
    final b = _bearingToPost();
    if (b == null) return null;
    var d = b - _heading;
    while (d > 180) {
      d -= 360;
    }
    while (d < -180) {
      d += 360;
    }
    return d;
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final dist = _distance();
    final rel = _relativeBearing();
    final pitch = _pitch;

    final mq = MediaQuery.of(context).size;
    final w = mq.width;
    final h = mq.height;

    double? dx, dy, sizePx;
    bool inView = false;

    if (dist != null && rel != null) {
      // 画面中心からのオフセット比（-1〜+1で画面端）
      final xRatio = rel / (_hFovDeg / 2);
      // pitch が正（上向き）なら作品（地平線上想定）は画面下方向に見える
      final yRatio = pitch / (_vFovDeg / 2);

      // 画面内判定（少し外側まで描画してフェードを滑らかにする）
      inView = xRatio.abs() < 1.2 && yRatio.abs() < 1.2;

      dx = xRatio * (w / 2);
      dy = yRatio * (h / 2);

      // 想定物理サイズ ÷ 距離 = 角度（rad） → 画素換算
      final angDeg = (_assumedSize / dist) * 180 / math.pi;
      sizePx = (angDeg / _hFovDeg) * w;
      sizePx = sizePx.clamp(80.0, w * 1.4);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildCamera()),

          // 作品を画面の対応位置に描画
          if (dx != null && dy != null && sizePx != null)
            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: Offset(dx, dy),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: inView ? 1.0 : 0.0,
                    child: SizedBox(
                      width: sizePx,
                      height: sizePx,
                      child: _PostOverlay(post: widget.post),
                    ),
                  ),
                ),
              ),
            ),

          // HUD
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  comment: widget.post.comment,
                  onClose: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                if (!inView && rel != null)
                  _OffscreenIndicator(relativeBearing: rel),
                const SizedBox(height: 8),
                _DistanceChip(distance: dist),
                const SizedBox(height: 16),
                _SettingsPanel(
                  hFov: _hFovDeg,
                  size: _assumedSize,
                  onHFovChanged: (v) => setState(() {
                    _hFovDeg = v;
                    // 縦は横の比率で連動（縦持ちで縦の方が広い）
                    _vFovDeg = v * 1.27;
                  }),
                  onSizeChanged: (v) => setState(() => _assumedSize = v),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCamera() {
    final ctrl = _camera;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: kRed)),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: ctrl.value.previewSize?.height ?? 1,
        height: ctrl.value.previewSize?.width ?? 1,
        child: CameraPreview(ctrl),
      ),
    );
  }
}

class _PostOverlay extends StatelessWidget {
  final Post post;
  const _PostOverlay({required this.post});

  @override
  Widget build(BuildContext context) {
    Widget? img;
    if (post.image != null) {
      img = Image.file(post.image!, fit: BoxFit.contain);
    } else if (post.imageUrl != null) {
      img = Image.network(post.imageUrl!, fit: BoxFit.contain);
    }
    return img ?? const SizedBox.shrink();
  }
}

class _TopBar extends StatelessWidget {
  final String comment;
  final VoidCallback onClose;
  const _TopBar({required this.comment, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kRed, width: 1),
              ),
              child: Text(
                comment,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kWhite),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 作品が画面外のとき方向を示す矢印
class _OffscreenIndicator extends StatelessWidget {
  final double relativeBearing;
  const _OffscreenIndicator({required this.relativeBearing});

  @override
  Widget build(BuildContext context) {
    final rad = relativeBearing * math.pi / 180;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: rad,
            child: const Icon(Icons.navigation, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          Text(
            '${relativeBearing.abs().toStringAsFixed(0)}° '
            '${relativeBearing > 0 ? 'RIGHT →' : '← LEFT'}',
            style: GoogleFonts.bebasNeue(
              color: Colors.white,
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  final double? distance;
  const _DistanceChip({required this.distance});

  @override
  Widget build(BuildContext context) {
    if (distance == null) return const SizedBox.shrink();
    final near = distance! < 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: near ? kRed : Colors.white24),
      ),
      child: Text(
        '${distance!.toStringAsFixed(1)} m',
        style: TextStyle(
          color: near ? kRed : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// FOV と想定サイズの調整スライダー（環境差吸収用）
class _SettingsPanel extends StatelessWidget {
  final double hFov;
  final double size;
  final ValueChanged<double> onHFovChanged;
  final ValueChanged<double> onSizeChanged;
  const _SettingsPanel({
    required this.hFov,
    required this.size,
    required this.onHFovChanged,
    required this.onSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _Row(
            label: 'FOV ${hFov.toStringAsFixed(0)}°',
            child: Slider(
              value: hFov,
              min: 35,
              max: 90,
              onChanged: onHFovChanged,
            ),
          ),
          _Row(
            label: 'SIZE ${size.toStringAsFixed(1)}m',
            child: Slider(
              value: size,
              min: 0.3,
              max: 8,
              onChanged: onSizeChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final Widget child;
  const _Row({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kRed,
              inactiveTrackColor: Colors.white24,
              thumbColor: kRed,
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
