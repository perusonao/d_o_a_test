# 9人の審判 / Nine Verdicts

> 正式名称: **9人の審判 / Nine Verdicts**
>
> GitHubリポジトリの推奨名は `nine-verdicts` です。GitHubの
> Settings → General → Repository name で変更した後、ローカルでは次を実行します。
>
> ```sh
> git remote set-url origin https://github.com/perusonao/nine-verdicts.git
> ```
>
> Dart package名 `dead_or_alive`、Firebase project ID、Android applicationId、
> iOS bundle identifierは既存環境・import・保存データとの互換性のため変更していません。

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

## 外部テスト版

Ver.1.1プロトタイプ。CPU対戦、ホットシート、ルールガイド、チュートリアル、
匿名プレイログ送信、ルームコード式オンライン対戦βの基盤を含みます。

## Firebaseセットアップ

Firebase未設定でもCPU対戦とローカルログは動作します。未設定時はオンライン対戦と
クラウド送信を無効表示にします。

1. Firebase Consoleでプロジェクトを作成します。
2. `dart pub global activate flutterfire_cli`でFlutterFire CLIを導入します。
3. リポジトリ直下で`flutterfire configure`を実行し、対象プラットフォームを選びます。
4. 生成された`lib/firebase_options.dart`を使って
   `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`へ切り替えます。
5. AuthenticationのSign-in methodでAnonymousを有効化します。
6. Cloud Firestoreを作成します。
7. `firebase deploy --only firestore:rules`で`firestore.rules`を適用します。
8. Webを利用する場合はFirebaseへWebアプリを登録します。
9. `flutter run -d chrome`で起動します。別ブラウザ／シークレットウィンドウを使い、
   片方でルーム作成、もう片方で6桁コード参加を確認します。
10. Firestoreの`playtests`で送信ログ、`rooms`でβルームを確認します。

APIキーはFirebaseクライアント設定として公開可能な識別子ですが、サービスアカウント鍵、
Admin SDK秘密鍵、CIトークンはコミットしないでください。

## オンラインβのセキュリティ制約

共有`rooms/{roomId}`には属性・EYE結果・bonusOrderを保存しません。秘密情報は
`rooms/{roomId}/players/{uid}`へ分離し、本人だけが読めるRulesを適用します。

現段階はクライアント生成方式です。完全な不正防止と権威的な盤面進行にはCloud Functions
が必要です。盤面・ボーナス生成、合法手検証、秘密情報配布をFunctionsへ移すことを
オンライン正式版の必須TODOとしています。
