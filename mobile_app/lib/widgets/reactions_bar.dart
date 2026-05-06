import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// 絵文字リスト（カテゴリ順）
// ---------------------------------------------------------------------------
const List<String> kDefaultEmojis = [
  // 感情
  '😀', '😂', '🤣', '😊', '😍', '🥰', '😎', '🤔',
  '😭', '😱', '🥹', '😇', '🤯', '🫠', '🥲', '😡',
  // ジェスチャー
  '👍', '👎', '👏', '🙌', '🫶', '🤝', '✌️', '🤞',
  '👋', '🤚', '✋', '🤙', '🫡', '💪', '🙏', '🤌',
  // ハート
  '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
  '🤎', '💔', '❤️‍🔥', '💕', '💞', '💓', '💗', '💝',
  // モノ・記号
  '🔥', '✨', '🎉', '💯', '🎊', '🚀', '⭐', '💎',
  '🏆', '👑', '🎯', '🌟', '💡', '🎵', '🌈', '🍀',
];

// ---------------------------------------------------------------------------
// リアクション表示バー
// ---------------------------------------------------------------------------
class ReactionsBar extends StatelessWidget {
  final Map<String, int> reactions;
  final Set<String> myReactions;
  final void Function(String emoji) onToggle;

  const ReactionsBar({
    super.key,
    required this.reactions,
    required this.myReactions,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...reactions.entries.map((e) => _ReactionChip(
              emoji: e.key,
              count: e.value,
              isOwn: myReactions.contains(e.key),
              onTap: () => onToggle(e.key),
            )),
        _AddReactionButton(onSelected: onToggle),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isOwn;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.isOwn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isOwn
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOwn
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: isOwn ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddReactionButton extends StatelessWidget {
  final void Function(String emoji) onSelected;

  const _AddReactionButton({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => EmojiPickerSheet(onSelected: onSelected),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: const Icon(
          Icons.add_reaction_outlined,
          size: 16,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 絵文字ピッカー ボトムシート
// ---------------------------------------------------------------------------
class EmojiPickerSheet extends StatelessWidget {
  final void Function(String emoji) onSelected;

  const EmojiPickerSheet({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ハンドル
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('リアクション',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                controller: controller,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: kDefaultEmojis.length,
                itemBuilder: (_, i) {
                  final e = kDefaultEmojis[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(e);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
