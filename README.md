# 9人の審判

Flutter Webで動作する、同一端末ホットシート形式の1対1カードゲーム・ルール検証用プロトタイプです。

## 現在の実装

- 3×3の人カードと、各マスに隠された数字カード1〜9
- 救済者／執行者によるホットシート対戦
- LIFE / DEATH / JUDGE / SAVE
- プレイヤーごとに分離された初期数字情報とJUDGE情報
- 手番交代時の秘密情報遮断画面
- 9人全員の判決によるゲーム終了
- 最終得点、得点先、勝者、プレイログ
- 全情報、リアルタイム得点、リセット、再シャッフルを備えたデバッグモード
- 360×640でスクロールを使わない1画面UI

実装ルールは [RULES.md](RULES.md) を参照してください。

旧「DEAD OR ALIVE」実装は削除せず残しています。旧文書は`docs/legacy/`、旧ソースは
`lib/features/game`、`lib/features/title`、`lib/features/result`、旧バランス実験は`tool/`です。

## 起動と検証

```bash
flutter pub get
flutter run -d chrome
flutter analyze
flutter test
flutter build web --release --base-href /d_o_a_test/ --no-web-resources-cdn
```

ルール設定は`lib/features/nine_judges/game/game_config.dart`に集約しています。
