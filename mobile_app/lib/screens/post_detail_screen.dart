import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/post.dart';
import '../services/post_service.dart';
import '../theme.dart';
import 'ar_viewer_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final bool isFavorited;
  final VoidCallback? onFavoriteToggle;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.isFavorited = false,
    this.onFavoriteToggle,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late bool _isFavorited;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.isFavorited;
  }

  void _handleFavoriteToggle() {
    if (widget.onFavoriteToggle == null) return;
    setState(() => _isFavorited = !_isFavorited);
    widget.onFavoriteToggle!();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Scaffold(
      backgroundColor: kBlack,
      appBar: AppBar(
        title: Text('DETAIL', style: GoogleFonts.bebasNeue(color: kRed, fontSize: 24, letterSpacing: 3)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: kWhite),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (widget.onFavoriteToggle != null)
            IconButton(
              icon: Icon(
                _isFavorited ? Icons.star : Icons.star_border,
                color: _isFavorited ? kRed : kWhite,
              ),
              onPressed: _handleFavoriteToggle,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kRed),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.image != null)
              Image.file(post.image!, width: double.infinity, fit: BoxFit.contain)
            else if (post.imageUrl != null)
              Image.network(post.imageUrl!, width: double.infinity, fit: BoxFit.contain),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.comment,
                    style: const TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  // AR ビューワーへの導線
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => ARViewerScreen(post: post),
                      ),
                    ),
                    icon: const Icon(Icons.view_in_ar),
                    label: const Text('現地でARで見る'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 経路探索
                  OutlinedButton.icon(
                    onPressed: () => _openDirections(post.location.latitude, post.location.longitude),
                    icon: const Icon(Icons.directions, color: kRed),
                    label: const Text('経路探索', style: TextStyle(color: kRed)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kRed),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 絵文字リアクション
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: Post.defaultEmojis.map((emoji) {
                      final count = post.reactions[emoji] ?? 0;
                      return GestureDetector(
                        onTap: () => PostService.instance.toggleReaction(
                          postId: post.id,
                          emoji: emoji,
                          hasReacted: count > 0,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: count > 0 ? kRed.withValues(alpha: 0.15) : kSurface,
                            border: Border.all(color: count > 0 ? kRed : kBorder),
                          ),
                          child: Text(
                            count > 0 ? '$emoji $count' : emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: kBorder),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: kGrey),
                      const SizedBox(width: 4),
                      Text(
                        '${post.location.latitude.toStringAsFixed(5)}, '
                        '${post.location.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 13, color: kGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(post.createdAt),
                    style: const TextStyle(fontSize: 13, color: kGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDirections(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Google マップが開けない場合はブラウザで開く
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  String _formatDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min';
  }
}
