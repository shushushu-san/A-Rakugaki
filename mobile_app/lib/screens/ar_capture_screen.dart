import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../unity_view.dart';

class ARCaptureScreen extends StatefulWidget {
  const ARCaptureScreen({super.key});

  @override
  State<ARCaptureScreen> createState() => _ARCaptureScreenState();
}

class _ARCaptureScreenState extends State<ARCaptureScreen> {
  final _unityKey = GlobalKey<UnityARViewState>();
  final _repaintKey = GlobalKey();
  bool _capturing = false;

  static const _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.white,
  ];

  Future<void> _capture() async {
    setState(() => _capturing = true);
    try {
      final boundary =
          _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = Directory.systemTemp;
      final file = File(
          '${dir.path}/ar_capture_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      if (mounted) Navigator.of(context).pop(file);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('キャプチャに失敗しました')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(
            key: _repaintKey,
            child: UnityARView(key: _unityKey),
          ),
          // 戻るボタン
          Positioned(
            top: top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black38),
            ),
          ),
          // 操作ボタン群
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
                          onTap: () => _unityKey.currentState?.setColor(color),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 44,
                            height: 44,
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
                  onPressed: _capturing ? null : _capture,
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
      ),
    );
  }
}
