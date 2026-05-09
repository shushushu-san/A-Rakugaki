import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_unity_widget_2/flutter_unity_widget_2.dart';

/// Unity から飛んでくるメッセージのチャネル種別。
enum UnityChannel { status, pose, strokes, unknown }

/// Unity から受信したメッセージの汎用ラッパー。
class UnityIncomingMessage {
  final UnityChannel channel;
  final Map<String, dynamic> payload;
  const UnityIncomingMessage({required this.channel, required this.payload});

  static UnityIncomingMessage? tryParse(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final channelStr = m['channel'] as String? ?? '';
      final payload = (m['payload'] is Map)
          ? Map<String, dynamic>.from(m['payload'] as Map)
          : <String, dynamic>{};
      final channel = switch (channelStr) {
        'status' => UnityChannel.status,
        'pose' => UnityChannel.pose,
        'strokes' => UnityChannel.strokes,
        _ => UnityChannel.unknown,
      };
      return UnityIncomingMessage(channel: channel, payload: payload);
    } catch (_) {
      return null;
    }
  }
}

class UnityARView extends StatefulWidget {
  /// Unity からのメッセージ通知（任意）
  final void Function(UnityIncomingMessage msg)? onUnityMessage;

  const UnityARView({super.key, this.onUnityMessage});

  @override
  UnityARViewState createState() => UnityARViewState();
}

class UnityARViewState extends State<UnityARView> {
  UnityWidgetController? _controller;
  // 同期的な応答待ち用の Completer 群（チャネル毎に1つだけ保持）
  final Map<UnityChannel, Completer<Map<String, dynamic>>> _pendingResponses = {};

  void _onUnityCreated(UnityWidgetController controller) {
    _controller = controller;
  }

  /// 既存 DrawingManager 系（Flutter → Unity 一方向）
  void _post(String go, String method, String arg) {
    _controller?.postMessage(go, method, arg);
  }

  void setColor(Color color) {
    final r = color.r.toStringAsFixed(3);
    final g = color.g.toStringAsFixed(3);
    final b = color.b.toStringAsFixed(3);
    _post('XR Origin (Mobile AR)', 'SetColor', '$r,$g,$b,1.0');
  }

  void setWidth(double width) =>
      _post('XR Origin (Mobile AR)', 'SetWidth', width.toStringAsFixed(4));

  void setEraser(bool enabled) =>
      _post('XR Origin (Mobile AR)', 'SetEraser', enabled ? 'true' : 'false');

  void undo() => _post('XR Origin (Mobile AR)', 'Undo', '');
  void clearAll() => _post('XR Origin (Mobile AR)', 'ClearAll', '');

  // ---- Geospatial（GeospatialManager.cs と対応） ----

  /// 描画モードに切り替え
  void startDrawMode() =>
      _post('XR Origin (Mobile AR)', 'StartDrawMode', '');

  /// 視聴モードに切り替え（指定された投稿の作品を AR 空間に復元）
  /// [payloadJson] は GeospatialManager.PostPayload と互換のJSON文字列
  void startViewMode(String payloadJson) =>
      _post('XR Origin (Mobile AR)', 'StartViewMode', payloadJson);

  /// 視聴で生成したアンカー・線を破棄
  void clearViewAnchor() =>
      _post('XR Origin (Mobile AR)', 'ClearViewAnchor', '');

  /// 現在地の Geospatial Pose を取得（投稿時用）
  Future<Map<String, dynamic>> requestCurrentPose({
    Duration timeout = const Duration(seconds: 6),
  }) {
    return _request(UnityChannel.pose, () {
      _post('XR Origin (Mobile AR)', 'RequestCurrentPose', '');
    }, timeout);
  }

  /// 現在描かれているストロークを取得（投稿時用）
  Future<Map<String, dynamic>> requestDrawnStrokes({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return _request(UnityChannel.strokes, () {
      _post('XR Origin (Mobile AR)', 'RequestDrawnStrokes', '');
    }, timeout);
  }

  Future<Map<String, dynamic>> _request(
    UnityChannel ch,
    void Function() send,
    Duration timeout,
  ) {
    // 既に待機中なら新しい Completer に置き換え（最後の問い合わせ優先）
    _pendingResponses[ch]?.completeError(StateError('superseded'));
    final c = Completer<Map<String, dynamic>>();
    _pendingResponses[ch] = c;
    send();
    return c.future.timeout(timeout, onTimeout: () {
      _pendingResponses.remove(ch);
      throw TimeoutException('Unity did not respond on $ch within $timeout');
    });
  }

  /// Unity からのメッセージ受信
  void _handleUnityMessage(dynamic raw) {
    final str = raw is String ? raw : raw.toString();
    final msg = UnityIncomingMessage.tryParse(str);
    if (msg == null) return;
    final pending = _pendingResponses.remove(msg.channel);
    pending?.complete(msg.payload);
    widget.onUnityMessage?.call(msg);
  }

  @override
  void dispose() {
    _controller?.dispose();
    for (final c in _pendingResponses.values) {
      if (!c.isCompleted) c.completeError(StateError('disposed'));
    }
    _pendingResponses.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UnityWidget(
      onUnityCreated: _onUnityCreated,
      onUnityMessage: _handleUnityMessage,
      useAndroidViewSurface: false,
    );
  }
}
