import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'firebase_options.dart';
import 'models/post.dart';
import 'theme/app_colors.dart';
import 'screens/map_screen.dart';
import 'screens/sns_screen.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A-Rakugaki',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          secondary: AppColors.primary,
          onSecondary: AppColors.onPrimary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
        ),
        cardTheme: const CardThemeData(
          color: AppColors.card,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textMuted,
            side: const BorderSide(color: AppColors.textSecondary),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          labelStyle: TextStyle(color: AppColors.textSecondary),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.textSecondary),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _userId;
  final Map<String, Set<String>> _myReactions = {};

  late final Stream<List<Post>> _postsStream = FirebaseFirestore.instance
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Post.fromFirestore).toList());

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
    _initAuth();
  }

  Future<void> _initAuth() async {
    final user = FirebaseAuth.instance.currentUser ??
        (await FirebaseAuth.instance.signInAnonymously()).user;
    if (mounted) setState(() => _userId = user?.uid);
  }

  Future<void> _onReactionToggled(String postId, String emoji) async {
    final myPostReactions = _myReactions.putIfAbsent(postId, () => {});
    final hasReacted = myPostReactions.contains(emoji);
    setState(() {
      if (hasReacted) {
        myPostReactions.remove(emoji);
      } else {
        myPostReactions.add(emoji);
      }
    });
    final docRef =
        FirebaseFirestore.instance.collection('posts').doc(postId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final rxns =
          Map<String, dynamic>.from(data['reactions'] as Map? ?? {});
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Post>>(
      stream: _postsStream,
      builder: (context, snapshot) {
        final posts = snapshot.data ?? [];
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              MapScreen(
                posts: posts,
                onReactionToggled: _onReactionToggled,
                myReactions: _myReactions,
              ),
              SNSScreen(
                posts: posts,
                userId: _userId ?? '',
                onReactionToggled: _onReactionToggled,
                myReactions: _myReactions,
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.map),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Timeline',
              ),
            ],
          ),
        );
      },
    );
  }
}
