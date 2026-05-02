import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post.dart';
import 'map_picker_screen.dart';
import 'post_detail_screen.dart';

// ---------------------------------------------------------------------------
// SNS フィード画面
// ---------------------------------------------------------------------------
class SNSScreen extends StatefulWidget {
  final List<Post> posts;
  final void Function(Post) onPostAdded;

  const SNSScreen({super.key, required this.posts, required this.onPostAdded});

  @override
  State<SNSScreen> createState() => _SNSScreenState();
}

class _SNSScreenState extends State<SNSScreen> {
  Future<void> _openPostSheet() async {
    final post = await showModalBottomSheet<Post>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PostSheet(),
    );
    if (post != null) {
      widget.onPostAdded(post);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('SNS'),
      ),
      body: widget.posts.isEmpty
          ? const Center(
              child: Text(
                'まだ投稿がありません\n右下のボタンから投稿しましょう',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: widget.posts.length,
              itemBuilder: (_, i) => _PostCard(post: widget.posts[i]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openPostSheet,
        tooltip: '投稿する',
        child: const Icon(Icons.edit),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 投稿作成ボトムシート
// ---------------------------------------------------------------------------
class _PostSheet extends StatefulWidget {
  const _PostSheet();

  @override
  State<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends State<_PostSheet> {
  final _commentController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  File? _image;
  bool _fetchingLocation = false;

  @override
  void dispose() {
    _commentController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  // ---- 画像選択 ----
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  // ---- 座標取得方法の選択ダイアログ ----
  Future<void> _selectLocation() async {
    final choice = await showDialog<_LocationChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('座標の取得方法'),
        content: const Text('投稿に紐づける位置を選択してください。'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, _LocationChoice.current),
            icon: const Icon(Icons.my_location),
            label: const Text('現在地を使う'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, _LocationChoice.map),
            icon: const Icon(Icons.map),
            label: const Text('マップから選ぶ'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == _LocationChoice.current) {
      await _fetchCurrentLocation();
    } else {
      await _pickFromMap();
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _setCoords(pos.latitude, pos.longitude);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('現在地の取得に失敗しました')),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _pickFromMap() async {
    final initial = _parsedLatLng() ?? const LatLng(35.6812, 139.7671);
    final result = await Navigator.of(context, rootNavigator: true).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialPosition: initial),
      ),
    );
    if (result != null && mounted) _setCoords(result.latitude, result.longitude);
  }

  void _setCoords(double lat, double lng) {
    setState(() {
      _latController.text = lat.toStringAsFixed(6);
      _lngController.text = lng.toStringAsFixed(6);
    });
  }

  LatLng? _parsedLatLng() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  // ---- 投稿 ----
  void _submit() {
    final comment = _commentController.text.trim();
    final location = _parsedLatLng();

    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('コメントを入力してください')),
      );
      return;
    }
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('座標を設定してください')),
      );
      return;
    }

    Navigator.of(context).pop(
      Post(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        comment: comment,
        image: _image,
        location: location,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー
            Row(
              children: [
                Text('新規投稿', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // コメント入力
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'コメント',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // 画像選択（将来的にARに置き換え予定）
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('画像を追加 (AR予定)'),
                ),
                if (_image != null) ...[
                  const SizedBox(width: 8),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          _image!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _image = null),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // 座標入力
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: '緯度',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: '経度',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _fetchingLocation
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: _selectLocation,
                        icon: const Icon(Icons.my_location),
                        tooltip: '座標を取得',
                      ),
              ],
            ),
            const SizedBox(height: 16),

            // 投稿ボタン
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: const Text('投稿する'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _LocationChoice { current, map }

// ---------------------------------------------------------------------------
// 投稿カード
// ---------------------------------------------------------------------------
class _PostCard extends StatelessWidget {
  final Post post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => PostDetailScreen(post: post),
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像（AR置き換え予定エリア）
            if (post.image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  post.image!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // コメント
            Text(post.comment, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),

            // フッター（座標・日時）
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 2),
                Text(
                  '${post.location.latitude.toStringAsFixed(5)}, '
                  '${post.location.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  _formatDate(post.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min';
  }
}
