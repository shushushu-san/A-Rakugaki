import 'dart:io';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class Post {
  final String id;
  final String title;
  final String comment;
  final File? image; // 将来的にARコンテンツへ置き換え予定
  final LatLng location;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.title,
    required this.comment,
    this.image,
    required this.location,
    required this.createdAt,
  });
}
