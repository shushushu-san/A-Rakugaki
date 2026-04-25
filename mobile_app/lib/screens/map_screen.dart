import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const CameraPosition _tokyoPosition = CameraPosition(
    target: LatLng(35.6812, 139.7671),
    zoom: 14.0,
  );

  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  BitmapDescriptor? _locationIcon;
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();
    _buildLocationIcon().then((icon) {
      setState(() => _locationIcon = icon);
    });
    _initLocation();
  }

  /// Canvas で現在地アイコンをプログラム的に生成する（アセット不要）
  Future<BitmapDescriptor> _buildLocationIcon() async {
    const double size = 24;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;

    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    paint.color = const Color(0xFF4285F4);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 6, paint);

    paint.color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), 8, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<void> _initLocation() async {
    final permission = await _requestPermission();
    if (!permission) {
      setState(() => _locationDenied = true);
      return;
    }
    await _moveToCurrentLocation();
  }

  Future<bool> _requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<void> _moveToCurrentLocation() async {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    final latLng = LatLng(pos.latitude, pos.longitude);
    setState(() => _currentPosition = latLng);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16.0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('A-Rakugaki'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _tokyoPosition,
            myLocationButtonEnabled: true,
            myLocationEnabled: false,
            mapType: MapType.normal,
            onMapCreated: (controller) => _mapController = controller,
            markers: _currentPosition == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('current_location'),
                      position: _currentPosition!,
                      icon: _locationIcon ?? BitmapDescriptor.defaultMarker,
                      anchor: const Offset(0.5, 0.5),
                      infoWindow: const InfoWindow(title: '現在地'),
                    ),
                  },
          ),
          if (_locationDenied)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off, color: Colors.red),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('位置情報の権限が必要です。設定から許可してください。'),
                      ),
                      TextButton(
                        onPressed: Geolocator.openAppSettings,
                        child: const Text('設定'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
