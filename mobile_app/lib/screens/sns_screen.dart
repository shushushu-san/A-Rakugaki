import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/post.dart';
import '../services/post_service.dart';
import '../theme.dart';
import '../utils/proximity.dart';
import 'map_picker_screen.dart';
import 'post_detail_screen.dart';

// ---------------------------------------------------------------------------
// SNS フィード画面
// ---------------------------------------------------------------------------
class SNSScreen extends StatefulWidget {
  final List<Post> posts;
  final String userId;
  final void Function(Post) onPostAdded;
  final void Function(void Function(File?) onDone) onARCaptureRequested;
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
  Future<void> _openPostSheet({File? prefilledImage, Post? basePost}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PostSheet(
        prefilledImage: prefilledImage,
        basePost: basePost,
        userId: widget.userId,
        existingPosts: widget.posts,
        onARCaptureTapped: (selectedBase, onDone) {
          Navigator.of(context).pop();
          // ゴースト表示は端末差で位置合わせができないため一旦無効化。
          // selectedBase は AR 終了後にシートを再オープンする際の上書きフラグ用に保持する。
          widget.onARCaptureRequested((file) {
            onDone(file);
            if (file != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _openPostSheet(prefilledImage: file, basePost: selectedBase);
              });
            }
          });
        },
      ),
    );
  }

  void openWithImage(File image) {
    _openPostSheet(prefilledImage: image);
  }

  void openWithImageAndBase(File image, Post basePost) {
    _openPostSheet(prefilledImage: image, basePost: basePost);
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
  final Post? basePost; // 上書き対象（既にARから戻ってきている場合）
  final String userId;
  final List<Post> existingPosts;
  final void Function(Post? basePost, void Function(File?) onDone)
      onARCaptureTapped;

  const _PostSheet({
    required this.prefilledImage,
    required this.basePost,
    required this.userId,
    required this.existingPosts,
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
  bool _submitting = false;
  // 近くの既存投稿（上書き候補）。位置取得後に検出される。
  Post? _nearbyPost;
  // 上書きモードの確定フラグ（true なら投稿時に既存を置き換える）
  bool _overwriteMode = false;

  @override
  void initState() {
    super.initState();
    _image = widget.prefilledImage;
    if (widget.basePost != null) {
      // ARから上書きモードで戻ってきた場合
      _nearbyPost = widget.basePost;
      _overwriteMode = true;
      _commentController.text = widget.basePost!.comment;
      _setCoords(
        widget.basePost!.location.latitude,
        widget.basePost!.location.longitude,
      );
      _fetchingLocation = false;
    } else {
      _fetchCurrentLocation();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _pickImage({bool overwrite = false}) {
    final base = overwrite ? _nearbyPost : null;
    widget.onARCaptureTapped(base, (file) {
      // シートが再び開かれた時は prefilledImage で画像が渡される
    });
  }

  /// 位置が確定したら、近くの既存投稿を探して上書き候補にする
  void _refreshNearby() {
    final coords = _parsedLatLng();
    if (coords == null) {
      setState(() => _nearbyPost = null);
      return;
    }
    final hit = findNearestPost(coords, widget.existingPosts);
    setState(() => _nearbyPost = hit?.post);
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
    // 位置が確定したので近くの投稿を再検索（明示的な上書き編集中はそのまま維持）
    if (widget.basePost == null) _refreshNearby();
  }

  LatLng? _parsedLatLng() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  // ---- 投稿 ----
  Future<void> _submit() async {
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

    setState(() => _submitting = true);
    try {
      if (_overwriteMode && _nearbyPost != null) {
        await PostService.instance.replacePost(
          oldPost: _nearbyPost!,
          comment: comment,
          lat: location.latitude,
          lng: location.longitude,
          userId: widget.userId,
          imageFile: _image,
        );
      } else {
        await PostService.instance.createPost(
          comment: comment,
          lat: location.latitude,
          lng: location.longitude,
          userId: widget.userId,
          imageFile: _image,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投稿に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

            // 近くの既存投稿があれば上書きの導線を表示
            if (_nearbyPost != null && widget.basePost == null)
              _OverwriteHintCard(
                post: _nearbyPost!,
                onPickWithBase: () => _pickImage(overwrite: true),
              ),
            if (_nearbyPost != null && widget.basePost == null)
              const SizedBox(height: 12),
            // 上書きモード時のステータス表示
            if (_overwriteMode && _nearbyPost != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kRed.withValues(alpha: 0.15),
                  border: Border.all(color: kRed),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.layers, size: 16, color: kRed),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '上書きモード: 投稿時に既存の作品が置き換わります',
                        style: TextStyle(color: kWhite, fontSize: 12),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _overwriteMode = false),
                      child: const Icon(Icons.close, size: 16, color: kGrey),
                    ),
                  ],
                ),
              ),

            // 画像選択
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

            // 位置情報
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kSurface,
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  _fetchingLocation
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.location_on,
                          size: 16,
                          color: _parsedLatLng() != null ? kRed : kGrey,
                        ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _fetchingLocation
                          ? '現在地を取得中...'
                          : _parsedLatLng() != null
                              ? '${_latController.text}, ${_lngController.text}'
                              : '位置情報を取得できませんでした',
                      style: TextStyle(
                        color: _parsedLatLng() != null ? kWhite : kGrey,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _fetchingLocation ? null : _pickFromMap,
                    icon: const Icon(Icons.map, size: 16),
                    label: const Text('変更'),
                    style: TextButton.styleFrom(foregroundColor: kGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 投稿ボタン
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_submitting ? '投稿中...' : '投稿する'),
            ),
          ],
        ),
      ),
    );
  }
}

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
          builder: (_) => PostDetailScreen(
            post: post,
            isFavorited: widget.isFavorited,
            onFavoriteToggle: widget.onFavoriteToggle,
          ),
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

// ---------------------------------------------------------------------------
// 上書き候補が見つかったときに出るヒントカード
// ---------------------------------------------------------------------------
class _OverwriteHintCard extends StatelessWidget {
  final Post post;
  final VoidCallback onPickWithBase;

  const _OverwriteHintCard({
    required this.post,
    required this.onPickWithBase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kRed),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: post.image != null
                      ? Image.file(post.image!, fit: BoxFit.cover)
                      : (post.imageUrl != null
                          ? Image.network(post.imageUrl!, fit: BoxFit.cover)
                          : Container(color: kBorder)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'この場所には既存の作品があります',
                      style: TextStyle(
                        color: kWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.comment,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kGrey, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onPickWithBase,
            icon: const Icon(Icons.layers, size: 18),
            label: const Text('上書きしてARで描く'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kRed,
              side: const BorderSide(color: kRed),
            ),
          ),
        ],
      ),
    );
  }
}
