import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/post.dart';

class PostService {
  PostService._();
  static final PostService instance = PostService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const _collection = 'posts';

  /// 全投稿をリアルタイムで取得するストリーム（新しい順）
  Stream<List<Post>> watchPosts() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Post.fromFirestore).toList());
  }

  Future<void> createPost({
    required String comment,
    required double lat,
    required double lng,
    required String userId,
    File? imageFile,
  }) async {
    String? imageUrl;
    if (imageFile != null) {
      final ref = _storage
          .ref()
          .child('posts/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    }

    await _db.collection(_collection).add({
      'comment': comment,
      'imageUrl': imageUrl,
      'lat': lat,
      'lng': lng,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': userId,
      'reactions': <String, int>{},
    });
  }

  /// リアクションをトグルする（Firestore トランザクション）
  Future<void> toggleReaction({
    required String postId,
    required String emoji,
    required bool hasReacted,
  }) async {
    final docRef = _db.collection(_collection).doc(postId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final rxns = Map<String, dynamic>.from(data['reactions'] as Map? ?? {});
      final current = (rxns[emoji] as num?)?.toInt() ?? 0;
      if (hasReacted) {
        if (current <= 1) {
          rxns.remove(emoji);
        } else {
          rxns[emoji] = current - 1;
        }
      } else {
        rxns[emoji] = current + 1;
      }
      tx.update(docRef, {'reactions': rxns});
    });
  }
}
