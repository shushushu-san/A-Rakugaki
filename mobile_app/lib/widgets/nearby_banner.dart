import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/post.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../utils/proximity.dart';

/// 端末位置を監視し、半径 [kProximityRadiusMeters] 以内に投稿があれば
/// 画面下にバナーで表示する。タップで [onOpen] が呼ばれる。
class NearbyBanner extends StatefulWidget {
  final List<Post> posts;
  final void Function(Post post) onOpen;

  const NearbyBanner({
    super.key,
    required this.posts,
    required this.onOpen,
  });

  @override
  State<NearbyBanner> createState() => _NearbyBannerState();
}

class _NearbyBannerState extends State<NearbyBanner> {
  StreamSubscription<dynamic>? _sub;
  NearbyPost? _current;
  // すでにバナーで「閉じる」された投稿はこのセッション中再表示しない
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _sub = LocationService.instance.positionStream.listen(
      (pos) => _evaluate(LatLng(pos.latitude, pos.longitude)),
      onError: (_) {}, // 権限エラー等は黙殺（マップ画面で別途案内する）
    );
    final last = LocationService.instance.lastPosition;
    if (last != null) {
      _evaluate(LatLng(last.latitude, last.longitude));
    }
  }

  @override
  void didUpdateWidget(NearbyBanner old) {
    super.didUpdateWidget(old);
    final last = LocationService.instance.lastPosition;
    if (last != null) {
      _evaluate(LatLng(last.latitude, last.longitude));
    }
  }

  void _evaluate(LatLng here) {
    final hits = findNearbyPosts(here, widget.posts)
        .where((n) => !_dismissed.contains(n.post.id))
        .toList();
    final next = hits.isEmpty ? null : hits.first;
    if (next?.post.id != _current?.post.id) {
      setState(() => _current = next);
    } else if (next != null && _current != null) {
      // 同じ投稿でも距離は更新したい
      setState(() => _current = next);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hit = _current;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: hit == null
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : _Card(
              key: ValueKey(hit.post.id),
              hit: hit,
              onTap: () => widget.onOpen(hit.post),
              onClose: () {
                setState(() {
                  _dismissed.add(hit.post.id);
                  _current = null;
                });
              },
            ),
    );
  }
}

class _Card extends StatelessWidget {
  final NearbyPost hit;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _Card({
    super.key,
    required this.hit,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final post = hit.post;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        color: kCard,
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: kRed, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _Thumb(post: post),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'NEARBY',
                        style: GoogleFonts.bebasNeue(
                          color: kRed,
                          fontSize: 14,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        post.comment,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${hit.distance.toStringAsFixed(0)} m',
                        style: const TextStyle(color: kGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: kGrey, size: 20),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final Post post;
  const _Thumb({required this.post});

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (post.image != null) {
      img = Image.file(post.image!, width: 56, height: 56, fit: BoxFit.cover);
    } else if (post.imageUrl != null) {
      img = Image.network(
        post.imageUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
      );
    } else {
      img = Container(
        width: 56,
        height: 56,
        color: kSurface,
        child: const Icon(Icons.image_not_supported, color: kGrey),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: img,
    );
  }
}
