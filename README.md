# 9人の審判 / Nine Verdicts

> 正式名称: **9人の審判 / Nine Verdicts**
>
> GitHubリポジトリの推奨名は `nine-verdicts` です。GitHubの
> Settings → General → Repository name で変更した後、ローカルでは次を実行します。
>
> ```sh
git remote set-url origin https://github.com/perusonao/nine-verdicts.git
> ```
>
> Dart package名 `dead_or_alive`、Firebase project ID、Android applicationId、
> iOS bundle identifierは既存環境・import・保存データとの互換性のため変更していません。

Flutter製の2人用・秘密情報対戦ゲームです。現行実装の正規コードは `lib/features/nine_judges/` です。

## 現在の実装

- 救済者と執行者によるホットシート／CPU対戦
- 9人全員が属性非公開・審議中で開始
- 無制限の通常行動 `LIFE` / `DEATH` / `EYE`
- 各陣営1回限定の逆転の一手（救済者は`DEATH`、執行者は`LIFE`）
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
flutter build web --release --base-href /nine-verdicts/ --no-web-resources-cdn
```

## スマホ向け配布物

ホームの「ガイド・動画をダウンロード」から、以下を開いて保存できます。

- 実際の遊び方: `downloads/nine-verdicts-how-to-play.pdf`
- 操作チュートリアル: `downloads/nine-verdicts-tutorial.pdf`
- プレイ動画: `downloads/nine-verdicts-gameplay.mp4`

配布物を更新する場合は、PDF/動画生成環境で次を実行します。

```bash
python tool/generate_download_media.py
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

## 外部テスト管理画面 (Admin Dashboard)

`playtests`に保存された外部テストデータを閲覧・集計するための、完全に読み取り専用の
管理画面です。通常のプレイ画面からはリンクされていません。

- **開き方**: タイトル画面(モード選択画面)右上の「外部テストβ　ルール1.2」バッジを
  **長押し**します(通常タップは説明ダイアログのままです)。以前用意していたURL直接
  入力・専用PWAインストール導線(`web/admin/`配下の別ページ・別manifest)は実運用で
  うまく機能しなかったため廃止し、アプリ内操作のみに一本化しました。
- ローカル確認・直接URLでの起動も引き続き可能です:
  `https://perusonao.github.io/nine-verdicts/#/admin`
  (ローカル確認時は `flutter run -d chrome` 後にアドレスバーで `#/admin` を追加)
- 認証方式: 通常プレイの匿名認証とは完全に分離された、Google Sign-In専用の
  Firebase Authインスタンス(`lib/features/nine_judges/admin/services/admin_firebase.dart`
  が名前付きセカンダリFirebase Appを使用)。管理画面へのログイン・ログアウトは
  通常のゲームプレイのFirebase匿名セッションに一切影響しません。
- 管理者判定: クライアント側の表示制御だけでなく、`firestore.rules`の`isAdmin()`
  関数が実際のアクセス制御を行います。`admins/{request.auth.uid}`ドキュメントが
  存在し、かつ`enabled == true`であることを必須とします。メールアドレスの
  文字列比較による判定は行いません。

### 最初の管理者を登録する手順

1. Firebase Consoleで対象プロジェクトを開きます。
2. 左メニュー「Authentication」→「Sign-in method」タブで、
   「Google」プロバイダを有効にします。
3. GitHub Pagesで公開している場合は、「Authentication」→「Settings」タブの
   「承認済みドメイン (Authorized domains)」に`perusonao.github.io`を追加します
   (`localhost`は開発用として最初から登録されています)。
4. 管理画面(タイトル画面の「外部テストβ」バッジ長押し、または`#/admin`)を開き、
   「Googleでログイン」でご自身のGoogleアカウントにログインします。この時点では
   「このアカウントには管理権限がありません」と表示されます(まだ`admins`
   ドキュメントが無いため、これは正しい動作です)。
5. Firebase Consoleの「Authentication」→「Users」タブで、ログインした
   アカウントのUID(ユーザーID列)を確認してコピーします。
6. 「Firestore Database」→「データ」タブを開き、「コレクションを開始」で
   コレクションID`admins`を作成します。
7. ドキュメントIDに手順5でコピーしたUIDを貼り付け、フィールド
   `enabled`(真偽値)を`true`に設定して保存します(`displayName`や
   `createdAt`は任意で追加できます)。
8. 管理画面をリロードすると管理者として認識され、ダッシュボードが表示されます。

### 管理画面でできること(初期版)

概要・ゲームログ・フィードバック・KPI・設定の5タブで構成され、すべて読み取り専用です
(ログの編集・削除、コメント編集、管理者の追加・削除は今回のバージョンでは実装して
いません)。ゲームログはFirestoreの読み取り件数を抑えるため20件ずつページングし、
個々のゲームのアクション履歴(`playtests/{gameId}/actions`)は詳細画面を開いたときに
のみ取得します。チュートリアルの計測データは現在Firestoreへ送信されていないため、
このダッシュボードには表示されません(端末内Hiveストレージにのみ保存されています)。

### 訪問数・プレイ数の記録

`playtests`はプレイヤーが最後にフィードバックを送信して初めて1件増える仕組みのため、
「実際に何人来て何回遊ばれたか」を答えられませんでした。そのギャップを埋めるため、
`appStats/visits`・`appStats/plays`の2つのドキュメント(それぞれ`count`フィールドのみ)
に、サイト読み込み1回ごと(`lib/main.dart`)・実プレイ開始1回ごと
(`game_screen.dart`の`_startGame`、チュートリアル/ショーケース/プロモ画面は対象外)
に`FieldValue.increment(1)`で加算しています。`tutorialCompletions`と異なり
端末・ユーザーで重複排除しない、単純な延べ回数です。

`admins/{uid}`と違い、事前にFirebase Consoleでドキュメントを作る必要はありません
(最初の1回の書き込みで`count: 1`のドキュメントが自動生成されます)。管理画面の
「概要」タブに常時表示されます。

### Firestoreインデックスについて

管理画面のクエリは`playtests`コレクションへの`orderBy('finishedAt')`
単一フィールドのページングと、`actions`サブコレクションへの
ドキュメントIDによる並び替えのみを使用しており、いずれもFirestoreが自動生成する
単一フィールドインデックスで動作します。複合インデックス(`firestore.indexes.json`)の
追加は不要です。

### Security Rulesのテスト

`fake_firebase_security_rules`(Dartのfakeライブラリ)は`function`/`get`/`exists`/
`request.resource`を解釈できないため、`isAdmin()`を含む本物のルールをそのまま検証
できません。そのため`firestore-tests/`にNode.js製のFirebase Emulator Suiteテストを
別途用意しています。

```sh
cd firestore-tests
npm install
cd ..
npx firebase-tools emulators:exec --only firestore \
  "cd firestore-tests && npm test"
```

anon userによる自分のplaytest作成、firebaseUid不一致の拒否、他人のplaytestの
読み取り拒否、管理者による全playtest読み取り、管理者によるactions読み取り、
一般ユーザーによるadminsドキュメント作成拒否、`appStats`カウンタの
+1インクリメントのみ許可(任意の値への上書き・他フィールド混入・削除は拒否)、
rooms関連ルールが影響を受けていないことを実際のFirestoreルールエンジンに対して
検証しています。

### Firestore Rulesの自動デプロイ

`firestore.rules`はGitHub Pagesへのデプロイ(`deploy-pages.yml`)とは別物で、
自動では本番のFirebaseプロジェクトへ反映されません。`.github/workflows/
deploy-firestore-rules.yml`が、`firestore.rules`/`firebase.json`/`.firebaserc`が
`main`へpushされた際に、上記のFirebase Emulator Suiteテストを実行して通った場合の
み本番へ`firebase deploy --only firestore:rules`を実行します。

初回のみ、リポジトリの管理者が以下を設定してください(実施しないとルール変更は
本番へ反映されず、ワークフローも警告付きでスキップされるだけで失敗はしません)。

1. Firebase Console → 対象プロジェクトの「プロジェクトの設定」(歯車アイコン) →
   「サービスアカウント」タブを開きます。
2. 「新しい秘密鍵の生成」でJSONキーファイルをダウンロードします。
3. GitHubリポジトリの Settings → Secrets and variables → Actions →
   「New repository secret」を開きます。
4. 名前を`FIREBASE_SERVICE_ACCOUNT`とし、値にダウンロードしたJSONファイルの
   中身をそのまま貼り付けて保存します。

このシークレットは強い権限を持つため、リポジトリの管理者以外に共有しないでください。
