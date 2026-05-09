import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/geospatial.dart';
import '../models/post.dart';
import '../theme.dart';
import '../unity_view.dart';

/// Geospatial Pose と 3D ストロークを持つ投稿を、Unity AR で原寸大に復元するビューワー。
class GeospatialViewerScreen extends StatefulWidget {
  final Post post;
  const GeospatialViewerScreen({super.key, required this.post});

  @override
  State<GeospatialViewerScreen> createState() => _GeospatialViewerScreenState();
}

class _GeospatialViewerScreenState extends State<GeospatialViewerScreen> {
  final _unityKey = GlobalKey<UnityARViewState>();
  String _status = 'initializing';

  @override
  void initState() {
    super.initState();
    // Unity 初期化完了後に視聴モードに切り替える
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startView();
    });
  }

  void _startView() {
    final pose = widget.post.geoPose;
    if (pose == null) return;
    final payload = encodePostPayload(
      pose: pose,
      strokes: widget.post.strokes,
    );
    _unityKey.currentState?.startViewMode(payload);
  }

  void _handleUnityMessage(UnityIncomingMessage msg) {
    if (msg.channel == UnityChannel.status) {
      setState(() => _status = msg.payload['status']?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    _unityKey.currentState?.clearViewAnchor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: UnityARView(
              key: _unityKey,
              onUnityMessage: _handleUnityMessage,
            ),
          ),
          // HUD
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kRed, width: 1),
                          ),
                          child: Text(
                            post.comment,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: kWhite),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _StatusChip(status: _status),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'view_ready' => 'AR 復元完了',
      'earth_not_tracking' => 'VPS 接続待ち... 屋外で広い空が見える場所へ',
      'anchor_create_failed' => 'アンカー作成失敗。位置情報を再取得してください',
      'initializing' => '初期化中...',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: GoogleFonts.bebasNeue(
          color: Colors.white,
          fontSize: 13,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
