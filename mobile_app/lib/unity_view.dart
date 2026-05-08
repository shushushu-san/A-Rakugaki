import 'package:flutter/material.dart';
import 'package:flutter_unity_widget_2/flutter_unity_widget_2.dart';

class UnityARView extends StatefulWidget {
  const UnityARView({super.key});

  @override
  UnityARViewState createState() => UnityARViewState();
}

class UnityARViewState extends State<UnityARView> {
  UnityWidgetController? _controller;

  void _onUnityCreated(UnityWidgetController controller) {
    _controller = controller;
  }

  void setColor(Color color) {
    final r = color.r.toStringAsFixed(3);
    final g = color.g.toStringAsFixed(3);
    final b = color.b.toStringAsFixed(3);
    _controller?.postMessage('XR Origin (Mobile AR)', 'SetColor', '$r,$g,$b,1.0');
  }

  void clearAll() {
    _controller?.postMessage('XR Origin (Mobile AR)', 'ClearAll', '');
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
