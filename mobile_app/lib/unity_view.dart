import 'package:flutter/material.dart';
import 'package:flutter_unity_widget_2/flutter_unity_widget_2.dart';

class UnityARView extends StatefulWidget {
  const UnityARView({super.key});

  @override
  State<UnityARView> createState() => _UnityARViewState();
}

class _UnityARViewState extends State<UnityARView> {
  UnityWidgetController? _controller;

  void _onUnityCreated(UnityWidgetController controller) {
    _controller = controller;
  }

  void sendMessageToUnity(String gameObject, String method, String message) {
    _controller?.postMessage(gameObject, method, message);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UnityWidget(
      onUnityCreated: _onUnityCreated,
      useAndroidViewSurface: false,
    );
  }
}
