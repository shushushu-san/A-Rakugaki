import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Post {
  final String id;
  final String title;
  final String comment;
  final String? imageUrl; // 将来的にARコンテンツへ置き換え予定
  final LatLng location;
  final DateTime createdAt;
  final String userId;
  final Map<String, int> reactions;

  Post({
    required this.id,
    required this.title,
    required this.comment,
    this.imageUrl,
    required this.location,
    required this.createdAt,
    required this.userId,
    Map<String, int>? reactions,
  }) : reactions = reactions ?? {};

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      title: data['title'] as String,
      comment: data['comment'] as String,
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

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'comment': comment,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'lat': location.latitude,
      'lng': location.longitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'reactions': reactions,
    };
  }

  Post copyWith({Map<String, int>? reactions}) {
    return Post(
      id: id,
      title: title,
      comment: comment,
      imageUrl: imageUrl,
      location: location,
      createdAt: createdAt,
      userId: userId,
      reactions: reactions ?? Map<String, int>.from(this.reactions),
    );
  }
}
