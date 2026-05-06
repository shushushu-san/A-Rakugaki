import 'dart:io';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class Post {
  final String id;
  final String title;
  final String comment;
  final File? image; // 将来的にARコンテンツへ置き換え予定
  final LatLng location;
  final DateTime createdAt;
  final Map<String, int> reactions;

  Post({
    required this.id,
    required this.title,
    required this.comment,
    this.image,
    required this.location,
    required this.createdAt,
    Map<String, int>? reactions,
  }) : reactions = reactions ?? {};

  Post copyWith({Map<String, int>? reactions}) {
    return Post(
      id: id,
      title: title,
      comment: comment,
      image: image,
      location: location,
      createdAt: createdAt,
      reactions: reactions ?? Map<String, int>.from(this.reactions),
    );
  }
}
