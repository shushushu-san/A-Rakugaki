import 'dart:io';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class Post {
  final String id;
  final String comment;
  final File? image;
  final LatLng location;
  final DateTime createdAt;
  final Map<String, int> reactions;

  static const defaultEmojis = ['🔥', '🤘', '💀', '👁', '⚡'];

  Post({
    required this.id,
    required this.comment,
    this.image,
    required this.location,
    required this.createdAt,
    Map<String, int>? reactions,
  }) : reactions = reactions ?? {};
}
