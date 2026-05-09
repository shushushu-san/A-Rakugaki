import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteService {
  FavoriteService._();
  static final FavoriteService instance = FavoriteService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _db.collection('users').doc(userId).collection('favorites');

  /// ユーザーのお気に入り投稿IDを取得する
  Future<Set<String>> loadFavoriteIds(String userId) async {
    if (userId.isEmpty) return {};
    final snap = await _col(userId).get();
    return snap.docs.map((d) => d.id).toSet();
  }

  /// お気に入りに追加する
  Future<void> addFavorite(String userId, String postId) async {
    if (userId.isEmpty) return;
    await _col(userId).doc(postId).set({
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// お気に入りから削除する
  Future<void> removeFavorite(String userId, String postId) async {
    if (userId.isEmpty) return;
    await _col(userId).doc(postId).delete();
  }
}
