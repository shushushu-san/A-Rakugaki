import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/post.dart';
import '../theme.dart';
import 'post_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  final List<Post> favorites;
  final void Function(Post) onRemove;
  final void Function(LatLng) onNavigateToMap;

  const FavoritesScreen({
    super.key,
    required this.favorites,
    required this.onRemove,
    required this.onNavigateToMap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SAVED'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kRed),
        ),
      ),
      body: favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('EMPTY', style: GoogleFonts.bebasNeue(fontSize: 64, color: kBorder)),
                  const SizedBox(height: 8),
                  const Text('★でお気に入りに追加', style: TextStyle(color: kGrey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (_, i) => _FavoriteCard(
                post: favorites[i],
                onRemove: () => onRemove(favorites[i]),
                onNavigateToMap: () => onNavigateToMap(favorites[i].location),
              ),
            ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final Post post;
  final VoidCallback onRemove;
  final VoidCallback onNavigateToMap;

  const _FavoriteCard({
    required this.post,
    required this.onRemove,
    required this.onNavigateToMap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PostDetailScreen(post: post),
        ),
      ),
      child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (post.image != null)
            Image.file(
              post.image!,
              height: 180,
              fit: BoxFit.cover,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              post.comment,
              style: const TextStyle(fontSize: 15),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 2),
                Text(
                  '${post.location.latitude.toStringAsFixed(4)}, '
                  '${post.location.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.star, color: Colors.amber),
                  tooltip: 'お気に入り解除',
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNavigateToMap,
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('地図で見る'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    // AR表示は実装予定 — 現地に行ったときにカメラ越しに落書きが見える
                    onPressed: null,
                    icon: const Icon(Icons.view_in_ar, size: 18),
                    label: const Text('ARで見る'),
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: Colors.deepPurple.withValues(alpha: 0.3),
                      disabledForegroundColor: Colors.white60,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),    // Card
    );    // GestureDetector
  }
}
