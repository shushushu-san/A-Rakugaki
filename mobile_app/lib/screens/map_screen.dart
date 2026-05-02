import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/post.dart';

class MapScreen extends StatefulWidget {
  final List<Post> posts;

  const MapScreen({super.key, required this.posts});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const CameraPosition _tokyoPosition = CameraPosition(
    target: LatLng(35.6812, 139.7671),
    zoom: 14.0,
  );

  GoogleMapController? _mapController;
  bool _locationDenied = false;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initLocation();
    _rebuildMarkers();
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.posts.length != widget.posts.length) {
      _rebuildMarkers();
    }
  }

  Future<void> _initLocation() async {
    final permission = await _requestPermission();
    if (!permission) {
      setState(() => _locationDenied = true);
      return;
    }
    await _moveToCurrentLocation();
  }

  Future<bool> _requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<void> _moveToCurrentLocation() async {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    final latLng = LatLng(pos.latitude, pos.longitude);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16.0));
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

    const double bubbleWidth = 150;
    const double radius = 10.0;
    const double padding = 10.0;
    const double tailHeight = 14.0;
    const double fontSize = 13.0;

    // テキスト計測
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

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, totalWidth, totalHeight),
    );

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
    final image =
        await picture.toImage(totalWidth.ceil(), totalHeight.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  // ---- 全画面詳細表示 ----

  void _showPostDetail(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PostDetailScreen(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('A-Rakugaki'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _tokyoPosition,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            mapType: MapType.normal,
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
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

// ---------------------------------------------------------------------------
// 投稿全画面詳細
// ---------------------------------------------------------------------------
class _PostDetailScreen extends StatelessWidget {
  final Post post;

  const _PostDetailScreen({required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('投稿詳細'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  post.image!,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(post.comment, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${post.location.latitude.toStringAsFixed(5)}, '
                  '${post.location.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(post.createdAt),
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min';
  }
}
