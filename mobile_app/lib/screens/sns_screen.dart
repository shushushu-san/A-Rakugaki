import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/post.dart';
import '../services/post_service.dart';
import '../theme.dart';
import 'map_picker_screen.dart';
import 'post_detail_screen.dart';

// ---------------------------------------------------------------------------
// SNS フィード画面
// ---------------------------------------------------------------------------
class SNSScreen extends StatefulWidget {
  final List<Post> posts;
  final String userId;
  final void Function(Post) onPostAdded;
  final void Function(void Function(File?)) onARCaptureRequested;
  final bool Function(String) isFavorited;
  final void Function(Post) onFavoriteToggle;

  const SNSScreen({
    super.key,
    required this.posts,
    required this.userId,
    required this.onPostAdded,
    required this.onARCaptureRequested,
    required this.isFavorited,
    required this.onFavoriteToggle,
  });

  @override
  SNSScreenState createState() => SNSScreenState();
}

class SNSScreenState extends State<SNSScreen> {
  Future<void> _openPostSheet({File? prefilledImage}) async {
    final post = await showModalBottomSheet<Post>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PostSheet(
        prefilledImage: prefilledImage,
        onARCaptureTapped: (onDone) {
          Navigator.of(context).pop(); // シートを閉じる
          widget.onARCaptureRequested((file) {
            onDone(file);
            if (file != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _openPostSheet(prefilledImage: file);
              });
            }
          });
        },
      ),
    );
    if (post != null) {
      widget.onPostAdded(post);
    }
  }

  void openWithImage(File image) {
    _openPostSheet(prefilledImage: image);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('A-RAKUGAKI', style: GoogleFonts.bebasNeue(color: kRed, fontSize: 28, letterSpacing: 4)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kRed),
        ),
      ),
      body: widget.posts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('EMPTY', style: GoogleFonts.bebasNeue(fontSize: 64, color: kBorder)),
                  const SizedBox(height: 8),
                  Text('まだ落書きがない\n右下から描け', textAlign: TextAlign.center, style: TextStyle(color: kGrey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: widget.posts.length,
              itemBuilder: (_, i) => _PostCard(
                post: widget.posts[i],
                isFavorited: widget.isFavorited(widget.posts[i].id),
                onFavoriteToggle: () => widget.onFavoriteToggle(widget.posts[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openPostSheet(),
        tooltip: '投稿する',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 投稿作成ボトムシート
// ---------------------------------------------------------------------------
class _PostSheet extends StatefulWidget {
  final File? prefilledImage;
  final void Function(void Function(File?)) onARCaptureTapped;

  const _PostSheet({
    required this.prefilledImage,
    required this.onARCaptureTapped,
  });

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
  void initState() {
    super.initState();
    _image = widget.prefilledImage;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _pickImage() {
    widget.onARCaptureTapped((file) {
      // シートが再び開かれた時は prefilledImage で画像が渡される
    });
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
                  icon: const Icon(Icons.draw),
                  label: const Text('AR落書きを追加'),
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
class _PostCard extends StatefulWidget {
  final Post post;
  final bool isFavorited;
  final VoidCallback onFavoriteToggle;

  const _PostCard({
    required this.post,
    required this.isFavorited,
    required this.onFavoriteToggle,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  void _react(String emoji) {
    final count = widget.post.reactions[emoji] ?? 0;
    PostService.instance.toggleReaction(
      postId: widget.post.id,
      emoji: emoji,
      hasReacted: count > 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PostDetailScreen(post: post),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        decoration: const BoxDecoration(
          color: kCard,
          border: Border(left: BorderSide(color: kRed, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像（ローカルファイル or Firebase Storage URL）
            if (post.image != null)
              Image.file(post.image!, width: double.infinity, height: 220, fit: BoxFit.cover)
            else if (post.imageUrl != null)
              Image.network(post.imageUrl!, width: double.infinity, height: 220, fit: BoxFit.cover),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // コメント
                  Text(
                    post.comment,
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 絵文字リアクション
                  Row(
                    children: Post.defaultEmojis.map((emoji) {
                      final count = post.reactions[emoji] ?? 0;
                      return GestureDetector(
                        onTap: () => _react(emoji),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: count > 0
                                ? kRed.withValues(alpha: 0.15)
                                : kSurface,
                            border: Border.all(
                              color: count > 0 ? kRed : kBorder,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            count > 0 ? '$emoji $count' : emoji,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  // フッター
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 12, color: kGrey),
                      const SizedBox(width: 2),
                      Text(
                        '${post.location.latitude.toStringAsFixed(4)}, '
                        '${post.location.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 11, color: kGrey),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onFavoriteToggle,
                        child: Icon(
                          widget.isFavorited
                              ? Icons.star
                              : Icons.star_border,
                          size: 20,
                          color:
                              widget.isFavorited ? kRed : kGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
