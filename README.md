# Dead or Alive / 9人の審判

Flutter製の2人用・秘密情報対戦ゲームです。現行実装の正規コードは `lib/features/nine_judges/` です。

## 現在の実装

- 救済者と執行者によるホットシート／CPU対戦
- 9人全員が属性非公開・審議中で開始
- 無制限の通常行動 `LIFE` / `DEATH` / `EYE`
- 各陣営1回限定の特殊行動「審判」
- 同状態の連続付与、または3回目の介入による確定
- 1〜9の審判ボーナスと、非確定者への遅延秘密公開
- プレイヤー別の属性KnowledgeとHandoff画面
- 構造化プレイログ、JSON/TXTエクスポート、分析画面
- スマートフォン縦画面向け3×3盤面

ルール詳細は [RULES.md](RULES.md) を参照してください。

## 開発

```sh
flutter pub get
flutter analyze
flutter test
flutter build web --release --base-href /d_o_a_test/ --no-web-resources-cdn
```

`lib/features/game/` などは旧プロトタイプであり、現行ルールの正規実装ではありません。
