import 'package:flutter/material.dart';

import '../models/post.dart';
import '../theme/app_colors.dart';
import '../widgets/reactions_bar.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final void Function(String emoji)? onReactionToggled;
  final Set<String> myReactions;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.onReactionToggled,
    this.myReactions = const {},
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Map<String, int> _reactions;
  late Set<String> _myReactions;

  @override
  void initState() {
    super.initState();
    _reactions = Map<String, int>.from(widget.post.reactions);
    _myReactions = Set<String>.from(widget.myReactions);
  }

  void _handleToggle(String emoji) {
    setState(() {
      if (_myReactions.contains(emoji)) {
        _myReactions.remove(emoji);
        final count = (_reactions[emoji] ?? 1) - 1;
        if (count <= 0) {
          _reactions.remove(emoji);
        } else {
          _reactions[emoji] = count;
        }
      } else {
        _myReactions.add(emoji);
        _reactions[emoji] = (_reactions[emoji] ?? 0) + 1;
      }
    });
    widget.onReactionToggled?.call(emoji);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.post.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.post.image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  widget.post.image!,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(widget.post.comment, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${widget.post.location.latitude.toStringAsFixed(5)}, '
                  '${widget.post.location.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(widget.post.createdAt),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ReactionsBar(
              reactions: _reactions,
              myReactions: _myReactions,
              onToggle: _handleToggle,
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
