import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/post.dart';
import '../services/post_service.dart';
import '../theme.dart';
import 'ar_viewer_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
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

  String _formatDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min';
  }
}
