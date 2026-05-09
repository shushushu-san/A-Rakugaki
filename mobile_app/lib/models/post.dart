import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'geospatial.dart';

class Post {
  final String id;
  final String comment;
  final File? image;       // ARキャプチャのローカルプレビュー用
  final String? imageUrl;  // Firebase Storage URL
  final LatLng location;
  final DateTime createdAt;
  final String userId;
  final Map<String, int> reactions;
  /// ARCore Geospatial Pose（VPS 取得済みの場合のみ存在）
  final GeospatialPose? geoPose;
  /// 3D ストロークデータ（geoPose と組み合わせて AR で復元する）
  final List<Stroke> strokes;

  static const defaultEmojis = ['🔥', '🤘', '💀', '👁', '⚡'];

  Post({
    required this.id,
    required this.comment,
    this.image,
    this.imageUrl,
    required this.location,
    required this.createdAt,
    this.userId = '',
    Map<String, int>? reactions,
    this.geoPose,
    List<Stroke>? strokes,
  })  : reactions = reactions ?? {},
        strokes = strokes ?? const [];

  /// AR で 3D 復元できる投稿か
  bool get hasGeospatialContent =>
      geoPose != null && strokes.isNotEmpty;

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final geoMap = data['geoPose'] as Map<String, dynamic>?;
    final strokesList = data['strokes'] as List?;
    return Post(
      id: doc.id,
      comment: data['comment'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      location: LatLng(
        (data['lat'] as num).toDouble(),
        (data['lng'] as num).toDouble(),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: data['userId'] as String? ?? '',
      reactions: Map<String, int>.from(
        ((data['reactions'] as Map<String, dynamic>?) ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      ),
      geoPose: geoMap != null ? GeospatialPose.fromJson(geoMap) : null,
      strokes: strokesList == null
          ? const []
          : strokesList
              .map((e) => Stroke.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'comment': comment,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'lat': location.latitude,
        'lng': location.longitude,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': userId,
        'reactions': reactions,
        if (geoPose != null) 'geoPose': geoPose!.toJson(),
        if (strokes.isNotEmpty)
          'strokes': strokes.map((s) => s.toJson()).toList(),
      };

  Post copyWith({Map<String, int>? reactions}) => Post(
        id: id,
        comment: comment,
        image: image,
        imageUrl: imageUrl,
        location: location,
        createdAt: createdAt,
        userId: userId,
        reactions: reactions ?? Map<String, int>.from(this.reactions),
        geoPose: geoPose,
        strokes: strokes,
      );
}
