import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/post.dart';
import '../services/location_service.dart';
import 'post_detail_screen.dart';

class MapScreen extends StatefulWidget {
  final List<Post> posts;
  final bool Function(String)? isFavorited;
  final void Function(Post)? onFavoriteToggle;

  const MapScreen({
    super.key,
    required this.posts,
    this.isFavorited,
    this.onFavoriteToggle,
  });

  @override
  State<MapScreen> createState() => MapScreenState();
}

// publicにしてHomeScreenからカメラ操作できるようにする

class MapScreenState extends State<MapScreen> {
  static const CameraPosition _tokyoPosition = CameraPosition(
    target: LatLng(35.6812, 139.7671),
    zoom: 14.0,
  );

  GoogleMapController? _mapController;
  bool _locationDenied = false;
  Set<Marker> _markers = {};
  Post? _centeredPost;
  // LocationService から最初の位置が届いたとき、まだ地図が準備できていない場合に保持する
  LatLng? _pendingCameraTarget;

  @override
  void initState() {
    super.initState();
    _listenLocation();
    _rebuildMarkers();
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.posts.length != widget.posts.length) {
      _rebuildMarkers();
    }
  }

  void moveToLocation(LatLng target) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 17.0));
  }

  /// LocationService（シングルトン）から最初の位置を受け取りカメラを移動する。
  /// 権限リクエストは LocationService 側で一元管理されるため、
  /// MapScreen が直接 requestPermission() を呼ぶ競合が起きない。
  void _listenLocation() {
    LocationService.instance.positionStream.first.then((pos) {
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      if (_mapController != null) {
        _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(latLng, 16.0));
      } else {
        // onMapCreated がまだ呼ばれていない場合は保持してあとで適用
        _pendingCameraTarget = latLng;
      }
    }).catchError((Object _) {
      if (mounted) setState(() => _locationDenied = true);
    });
  }

  // ---- フキダシマーカー生成 ----

  Future<void> _rebuildMarkers() async {
    final posts = List<Post>.from(widget.posts);
    final newMarkers = <Marker>{};

    for (final post in posts) {
      final icon = await _createSpeechBubbleIcon(post.comment);
      if (!mounted) return;
      newMarkers.add(
        Marker(
          markerId: MarkerId(post.id),
          position: post.location,
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          onTap: () => _showPostDetail(post),
        ),
      );
    }
    if (mounted) setState(() => _markers = newMarkers);
  }

  Future<BitmapDescriptor> _createSpeechBubbleIcon(String comment) async {
    final String label =
        comment.length > 10 ? '${comment.substring(0, 10)}…' : comment;

    const double scale = 3.0; // 高DPI対応スケール
    const double bubbleWidth = 150;
    const double radius = 10.0;
    const double padding = 10.0;
    const double tailHeight = 14.0;
    const double fontSize = 13.0;

    // テキスト計測（論理サイズ）
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: fontSize,
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: bubbleWidth - padding * 2);

    final bubbleHeight = textPainter.height + padding * 2;
    const totalWidth = bubbleWidth;
    final totalHeight = bubbleHeight + tailHeight;

    // スケールアップしたキャンバスで描画
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, totalWidth * scale, totalHeight * scale),
    );
    canvas.scale(scale, scale);

    // フキダシパス（角丸矩形 + 下向き三角）
    final path = Path()
      ..addRRect(
        RRect.fromLTRBR(
          0,
          0,
          totalWidth,
          bubbleHeight,
          const Radius.circular(radius),
        ),
      )
      ..moveTo(totalWidth / 2 - 9, bubbleHeight)
      ..lineTo(totalWidth / 2, bubbleHeight + tailHeight)
      ..lineTo(totalWidth / 2 + 9, bubbleHeight)
      ..close();

    // 影
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // 塗りつぶし
    canvas.drawPath(path, Paint()..color = Colors.white);
    // 枠線
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // テキスト描画
    textPainter.paint(canvas, const Offset(padding, padding));

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (totalWidth * scale).ceil(),
      (totalHeight * scale).ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      imagePixelRatio: scale,
    );
  }

  // ---- カメラ中心に投稿が来たか検出 ----

  void _onCameraMove(CameraPosition pos) {
    if (_centeredPost != null) {
      setState(() => _centeredPost = null);
    }
  }

  void _onCameraIdle() async {
    if (_mapController == null) return;
    final bounds = await _mapController!.getVisibleRegion();
    final centerLat =
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    final centerLng =
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
    final latRange =
        (bounds.northeast.latitude - bounds.southwest.latitude).abs();

    Post? found;
    for (final post in widget.posts) {
      final dLat = (post.location.latitude - centerLat).abs();
      final dLng = (post.location.longitude - centerLng).abs();
      if (dLat < latRange * 0.08 && dLng < latRange * 0.08) {
        found = post;
        break;
      }
    }
    if (mounted) setState(() => _centeredPost = found);
  }

  // ---- 全画面詳細表示 ----

  void _showPostDetail(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PostDetailScreen(
          post: post,
          isFavorited: widget.isFavorited?.call(post.id) ?? false,
          onFavoriteToggle: widget.onFavoriteToggle != null
              ? () => widget.onFavoriteToggle!(post)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MAP'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFD90000)),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _tokyoPosition,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            mapType: MapType.normal,
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
              // 位置情報が先に届いていた場合はここで反映
              if (_pendingCameraTarget != null) {
                controller.animateCamera(
                    CameraUpdate.newLatLngZoom(_pendingCameraTarget!, 16.0));
                _pendingCameraTarget = null;
              }
            },
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),
          // 中心の投稿画像ポップアップ
          if (_centeredPost?.image != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _CenteredPostPopup(
                post: _centeredPost!,
                onClose: () => setState(() => _centeredPost = null),
                onDetail: () => _showPostDetail(_centeredPost!),
              ),
            ),
          if (_locationDenied)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off, color: Colors.red),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('位置情報の権限が必要です。設定から許可してください。'),
                      ),
                      TextButton(
                        onPressed: Geolocator.openAppSettings,
                        child: const Text('設定'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- 中心投稿ポップアップ ----

class _CenteredPostPopup extends StatelessWidget {
  final Post post;
  final VoidCallback onClose;
  final VoidCallback onDetail;

  const _CenteredPostPopup({
    required this.post,
    required this.onClose,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (post.image != null)
            Stack(
              children: [
                Image.file(
                  post.image!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          InkWell(
            onTap: onDetail,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                post.comment,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


