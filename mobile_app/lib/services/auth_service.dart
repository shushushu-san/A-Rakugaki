import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// 未ログインの場合は匿名ログインを行い、UID を返す
  Future<String?> signInIfNeeded() async {
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user;
    return user?.uid;
  }
}
