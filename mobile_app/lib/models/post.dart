import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Post {
  final String id;
  final String comment;
  final File? image;       // ARキャプチャのローカルプレビュー用
  final String? imageUrl;  // Firebase Storage URL
  final LatLng location;
  final DateTime createdAt;
  final String userId;
  final Map<String, int> reactions;

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
  }) : reactions = reactions ?? {};

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
      );
}
