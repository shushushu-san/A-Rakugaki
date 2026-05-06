import 'package:flutter/material.dart';

/// アプリ全体で使用するカラー定義
abstract final class AppColors {
  // --- ベースカラー ---
  static const Color background    = Color(0xFF121212); // 最も暗い背景
  static const Color surface       = Color(0xFF1E1E1E); // AppBar / BottomNav
  static const Color card          = Color(0xFF2C2C2C); // カード背景
  static const Color backgroundPure = Color(0xFF000000); // 純黒（Unityプレースホルダー等）

  // --- テキスト ---
  static const Color textPrimary   = Color(0xFFFFFFFF); // 白
  static const Color textSecondary = Color(0xFF9E9E9E); // グレー（Colors.grey 相当）
  static const Color textMuted     = Color(0xB3FFFFFF); // 白70%（控えめな白）
  static const Color textDisabled  = Color(0x8AFFFFFF); // 白54%（無効状態テキスト・アイコン）

  // --- アクセント（重要部分に使用）---
  static const Color primary       = Color(0xFFE53935); // 赤
  static const Color onPrimary     = Color(0xFFFFFFFF); // 赤の上に乗るテキスト・アイコン

  // --- オーバーレイ ---
  static const Color overlayDark   = Color(0x8A000000); // 黒54%（ガイドラベル・削除ボタン等）

  // --- マップフキダシマーカー ---
  static const Color bubbleFill    = Color(0xFFFFFFFF); // 吹き出し塗りつぶし
  static const Color bubbleShadow  = Color(0x42000000); // 吹き出し影（黒26%）
  static const Color bubbleInk     = Color(0xDD000000); // 吹き出しテキスト・枠線（黒87%）

  // --- エラー・警告バナー ---
  static const Color errorBanner   = Color(0xFF3E1212); // 暗い赤背景
  static const Color errorIcon     = Color(0xFFE53935); // 赤アイコン
}
