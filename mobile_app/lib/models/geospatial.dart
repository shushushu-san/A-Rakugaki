import 'dart:convert';

/// 投稿地点の Geospatial Pose（ARCore VPS から取得した絶対座標）
class GeospatialPose {
  /// 緯度
  final double lat;

  /// 経度
  final double lng;

  /// 高度（m, EGM2008 楕円体基準）
  final double alt;

  /// 北を 0° とする時計回りの方位（度）
  final double heading;

  /// 取得時の精度（参考値、再現には使わない）
  final double? horizontalAccuracy;
  final double? verticalAccuracy;
  final double? headingAccuracy;

  const GeospatialPose({
    required this.lat,
    required this.lng,
    required this.alt,
    required this.heading,
    this.horizontalAccuracy,
    this.verticalAccuracy,
    this.headingAccuracy,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'alt': alt,
        'heading': heading,
        if (horizontalAccuracy != null)
          'horizontalAccuracy': horizontalAccuracy,
        if (verticalAccuracy != null) 'verticalAccuracy': verticalAccuracy,
        if (headingAccuracy != null) 'headingAccuracy': headingAccuracy,
      };

  factory GeospatialPose.fromJson(Map<String, dynamic> j) => GeospatialPose(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        alt: (j['alt'] as num?)?.toDouble() ?? 0,
        heading: (j['heading'] as num?)?.toDouble() ?? 0,
        horizontalAccuracy:
            (j['horizontalAccuracy'] as num?)?.toDouble(),
        verticalAccuracy: (j['verticalAccuracy'] as num?)?.toDouble(),
        headingAccuracy: (j['headingAccuracy'] as num?)?.toDouble(),
      );
}

/// LineRenderer 1本ぶんのストローク。色・太さ・3D点列を持つ。
class Stroke {
  final String colorRgba; // "1.0,0.0,0.0,1.0"
  final double width;
  final List<List<double>> points; // [[x,y,z], ...]

  const Stroke({
    required this.colorRgba,
    required this.width,
    required this.points,
  });

  Map<String, dynamic> toJson() => {
        'colorRgba': colorRgba,
        'width': width,
        'points': points
            .map((p) => {
                  'x': p[0],
                  'y': p[1],
                  'z': p[2],
                })
            .toList(),
      };

  factory Stroke.fromJson(Map<String, dynamic> j) {
    final pts = (j['points'] as List).map<List<double>>((p) {
      final m = p as Map;
      return [
        (m['x'] as num).toDouble(),
        (m['y'] as num).toDouble(),
        (m['z'] as num).toDouble(),
      ];
    }).toList();
    return Stroke(
      colorRgba: j['colorRgba'] as String? ?? '1.0,0.0,0.0,1.0',
      width: (j['width'] as num?)?.toDouble() ?? 0.005,
      points: pts,
    );
  }
}

/// Unity に投げる視聴モード用ペイロード（pose + strokes）
String encodePostPayload({
  required GeospatialPose pose,
  required List<Stroke> strokes,
}) {
  return jsonEncode({
    'lat': pose.lat,
    'lng': pose.lng,
    'alt': pose.alt,
    'heading': pose.heading,
    'strokes': strokes.map((s) => s.toJson()).toList(),
  });
}
