import 'package:flutter/material.dart';

// TODO: Unity AR 統合手順
// 1. Unityメンバーが以下をエクスポートしたら flutter_unity_widget を追加する:
//    Android: Build Settings → Export Project → mobile_app/android/unityLibrary/
//    iOS:     Build → 出力された UnityFramework.framework を ios/Runner に追加
//
// 2. pubspec.yaml の以下コメントアウトを解除して `flutter pub get`:
//    flutter_unity_widget: ^2022.2.1+2
//
// 3. このファイルの UnityARView を flutter_unity_widget の UnityWidget に差し替える:
//    import 'package:flutter_unity_widget/flutter_unity_widget.dart';
//    ... UnityWidget(onUnityCreated: ..., onUnityMessage: ...) ...

/// Unity AR 画面のプレースホルダーウィジェット。
/// flutter_unity_widget 追加後にこのクラスを差し替える。
class UnityARView extends StatelessWidget {
  const UnityARView({super.key});

  /// Unity側のGameObjectにメッセージを送る（統合後に実装）
  // void sendMessageToUnity(String gameObject, String method, String message) {
  //   _controller?.postMessage(gameObject, method, message);
  // }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_in_ar, color: Colors.white54, size: 64),
            SizedBox(height: 12),
            Text(
              'Unity AR\n(統合準備中)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

