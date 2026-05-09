import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/post.dart';

/// 近接判定のしきい値（メートル）
const double kProximityRadiusMeters = 30;

/// 上書き候補の検出半径（メートル）。投稿時に「同じ場所」とみなす範囲。
const double kOverwriteRadiusMeters = 15;

/// 2点間の距離（m）。Geolocator の Haversine 実装を使う。
double distanceMeters(LatLng a, LatLng b) {
  return Geolocator.distanceBetween(
    a.latitude,
    a.longitude,
    b.latitude,
    b.longitude,
  );
}

/// 指定地点から半径 [radius] 以内の投稿を、近い順に返す。
List<NearbyPost> findNearbyPosts(
  LatLng origin,
  Iterable<Post> posts, {
  double radius = kProximityRadiusMeters,
}) {
  final hits = <NearbyPost>[];
  for (final post in posts) {
    final d = distanceMeters(origin, post.location);
    if (d <= radius) {
      hits.add(NearbyPost(post: post, distance: d));
    }
  }
  hits.sort((a, b) => a.distance.compareTo(b.distance));
  return hits;
}

class NearbyPost {
  final Post post;
  final double distance;
  const NearbyPost({required this.post, required this.distance});
}

/// [origin] から最も近い投稿を返す（[radius] 以内に無ければ null）
NearbyPost? findNearestPost(
  LatLng origin,
  Iterable<Post> posts, {
  double radius = kOverwriteRadiusMeters,
}) {
  final hits = findNearbyPosts(origin, posts, radius: radius);
  return hits.isEmpty ? null : hits.first;
}
