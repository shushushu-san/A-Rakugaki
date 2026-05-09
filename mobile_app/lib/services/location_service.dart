import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// 端末の現在位置をストリーム配信するシングルトン。
///
/// 複数画面（SNS, Map, 近接通知など）から同じ位置情報を共有する。
/// 1秒以上の間隔・5m以上の移動でのみ更新を発行することでバッテリー消費を抑える。
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  StreamController<Position>? _controller;
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  bool _starting = false;

  /// 直近の位置（取得済みの場合）
  Position? get lastPosition => _lastPosition;

  /// 位置情報のストリーム。listen された時点で監視を開始する。
  Stream<Position> get positionStream {
    _controller ??= StreamController<Position>.broadcast(
      onListen: _ensureStarted,
      onCancel: _maybeStop,
    );
    return _controller!.stream;
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<void> _ensureStarted() async {
    if (_positionSub != null || _starting) return;
    _starting = true;
    try {
      final ok = await _ensurePermission();
      if (!ok) {
        _controller?.addError(
          'Location permission denied or service disabled',
        );
        return;
      }
      // 初回だけ即値取得して配信
      try {
        final initial = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        _lastPosition = initial;
        _controller?.add(initial);
      } catch (_) {
        // 初回取得失敗は致命ではない（ストリームで補完される）
      }

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // 5m移動で更新
        ),
      ).listen((pos) {
        _lastPosition = pos;
        _controller?.add(pos);
      }, onError: (Object e) {
        _controller?.addError(e);
      });
    } finally {
      _starting = false;
    }
  }

  void _maybeStop() {
    // 購読者がゼロになったら監視停止（StreamControllerは保持）
    if (_controller?.hasListener == false) {
      _positionSub?.cancel();
      _positionSub = null;
    }
  }

  /// 一回だけ現在地を取得（位置情報の確定が必要な場面用）
  Future<Position?> getCurrentOnce() async {
    final ok = await _ensurePermission();
    if (!ok) return null;
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _lastPosition = p;
      return p;
    } catch (_) {
      return null;
    }
  }
}
