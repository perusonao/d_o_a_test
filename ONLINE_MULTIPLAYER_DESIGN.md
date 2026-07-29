# オンライン対戦 実装設計メモ (Phase 1)

現状(2026-07時点)の実装は「ルーム作成/参加とロビー画面」までで止まっており、
実際の対戦・サーバー権威の盤面生成・チート対策は未実装。本メモは、実装に入る
前に固めておく設計方針。コードはまだ書かない。

## 1. なぜCloud Functionsが要るのか

CPU対戦は「ローカルの`NineJudgesController`が盤面を全部知っていて、CPUに見せ
ない情報をフィルタするだけ」で成立している(`CpuGameView`/`knowsAttribute`)。
これは同一端末・同一プロセス内で完結するので成り立つ。

オンライン対人戦では、2人のプレイヤーは別々の端末・別々のクライアントであり、
どちらのクライアントも信用できない。盤面の真の属性配置とボーナス順を「両方の
クライアントが読めるFirestoreドキュメント」に置いた時点で、開発者ツールから
簡単に覗き見できてしまう。これを防ぐには、真の状態を**クライアントが直接読め
ない場所(Cloud Functions経由でのみアクセス可能なサーバー側の状態)**に置き、
各プレイヤーには「そのプレイヤーが正当に知ってよい情報だけ」を配信する必要が
ある。これが必須のアーキテクチャ変更であり、Cloud Functionsを使う理由。

## 2. 既存資産の再利用

幸い、ルール自体(`lib/features/nine_judges/game/game_rules.dart`
`game_config.dart`)は副作用のない小さな純粋関数群(合わせて約130行)なので、
TypeScript/Node.jsへの移植は機械的にできる。ロジックの再設計は不要:

- `NineJudgesRules.createBoard`/`createBonusDeck` — 盤面・ボーナス順の生成
- `NineJudgesRules.canUseAction` — 合法手判定(LIFE/DEATH/EYE/JUDGE)
- `NineJudgesRules.applyVerdictAction`/`applySpecialVerdict` — 状態遷移
- `NineJudgesRules.scoringFaction` — 得点判定
- `NineJudgesConfig` — EYE使用上限・ゾーン制限・ルールバージョン定数

また、情報を「各プレイヤーが正当に知ってよい範囲」に絞る考え方自体は、CPU戦の
`CpuGameView`/`CpuSlotView.knownAttribute`パターンとしてDart側に既に実装・
テスト済みなので、そのロジックの"考え方"をそのままCloud Functions側の視点
生成にも流用する。

さらに`online_models.dart`には`OnlineTurnGate`(手番/リビジョン検証)・
`OnlinePrivateKnowledge`/`OnlinePlayerView`(プレイヤー視点の型)という未使用
の設計スケッチが既にあり、方向性は今回の設計と一致している(現状は
`OnlineRoomRepository.submitAction`から呼ばれておらず、宙に浮いている)。

## 3. データモデル

既存の`rooms/{code}`構造を拡張する形にし、既存の`players`/`actions`サブコレ
クションの命名は変えない。

```
rooms/{code}                       … 公開情報のみ(既存のまま)
  status, hostUid, guestUid, currentTurnUid, revision,
  rulesVersion, gameVersion, winner, finishedAt, playerUids …

rooms/{code}/serverState/board     … 【新規・クライアント読み取り不可】
  trueBoard: [{ id, attribute, verdictState, verdictHistory, confirmedBy … }] (9件)
  bonusOrder: number[9]
  bonusIndex: number
  eyeUsedCount: { [uid]: number }
  reverseActionUsed: { [uid]: boolean }
  specialVerdictUsed: { [uid]: boolean }

rooms/{code}/players/{uid}         … 【既存を拡張】プレイヤーごとの視点
  faction: 'savior' | 'executor'
  knownAttributes: { [slotIndex]: attribute }   … 自陣3枚+EYE結果+確定済み
  visibleBonus: number | null                   … 開示されている場合のみ

rooms/{code}/actions/{actionIndex} … 既存のまま(行動ログ、両者に公開)
```

`serverState/board`はFirestoreルールで**クライアントからのread/writeを一切
禁止**し、Cloud Functionsのサーバー環境(Admin SDK、ルール適用外)からのみ
アクセスする。これが「サーバー権威」の核。

## 4. 処理フロー

1. **ルーム作成** (`createRoom`, 既存): 変更なし。ただしこの時点ではまだ盤面
   を生成しない(先に生成すると、ホストが2人目の参加を待つ間に盤面情報が
   `serverState`に存在してしまい、後述のFunction起動タイミングとズレる余地
   があるため)。
2. **2人目が参加** (`joinRoom`, 既存の`status: 'playing'`への更新をトリガー
   に): Firestoreトリガー型Cloud Function `onRoomStart`が発火し、
   `NineJudgesRules.createBoard`/`createBonusDeck`相当のロジックで
   `serverState/board`を生成。あわせて`players/{hostUid}`
   `players/{guestUid}`の初期`knownAttributes`(自陣3枚)を書き込む。
3. **行動送信**: クライアントは直接`rooms/{code}`や`actions`に書き込まず、
   Callable Function `submitOnlineAction(code, action, targetIndex,
   clientRevision)`を呼ぶ。Function内で:
   - 手番/リビジョンを`OnlineTurnGate`と同等のロジックで検証
   - `canUseAction`相当のロジックで合法性を検証(クライアントの自己申告を
     信用しない)
   - `applyVerdictAction`/`applySpecialVerdict`相当で`serverState/board`を
     更新
   - 確定・EYE成功などで新たに開示される情報があれば、該当プレイヤーの
     `players/{uid}.knownAttributes`/`visibleBonus`を更新
   - `rooms/{code}`(公開情報: 手番・リビジョン・スコア・勝敗)と
     `actions/{actionIndex}`(行動ログ、既存の`actorUid/actionType/
     targetPersonId`形式を維持)を更新
4. **クライアントの描画**: `rooms/{code}`(公開)+`players/{myUid}`(自分の
   視点)の2つをリッスンし、`CpuGameView`と同じ形の読み取り専用ビューに変換
   してBoardGrid等の既存ウィジェットにそのまま渡す(盤面描画コンポーネント
   自体の変更は不要になるはず)。

## 5. Firestoreルールの変更方針

- `rooms/{code}/serverState/{doc}`: `allow read, write: if false;`(常に拒否。
  Cloud Functions Admin SDKはルールをバイパスするので問題ない)
- `rooms/{code}/actions/{actionId}`: `allow create`をクライアントから剥奪し
  Cloud Functions経由のみに変更(現状の直接書き込みを廃止)
- `rooms/{code}`自体の`update`も、`currentTurnUid`/`revision`等のゲーム進行
  フィールドはクライアントから直接更新できないようにし、Cloud Functions
  経由に一本化(現状の`playing`遷移やdiffベースの許可は縮小・置き換え)

## 6. クライアント側の新規実装

`OnlineGameController`(新規、`NineJudgesController`とは別クラス)を用意し、
役割を「Firestoreの2つのスナップショットを購読し、`submitOnlineAction`を
呼ぶだけの薄いアダプタ」に限定する。ゲームルールの判定・状態遷移ロジックは
一切持たせない(それは全てサーバー側)。既存の`NineJudgesGameScreen`が
`NineJudgesController`インターフェースの必要最小限のサブセットに依存する形
なら、盤面ウィジェット自体はほぼ流用できる見込み。

## 7. テスト方針

- **ルールの移植(TS)**: `test/game_engine_test.dart`にある既存ケースを
  そのままNode側のテストに移植し、Dart版と挙動が一致することを確認
- **Cloud Functions**: Firebase Emulator Suite上でCallable/Triggerを起動し、
  「相手の手番に送信→拒否」「不正なactionType→拒否」「EYE結果が相手の
  `players`ドキュメントに漏れない」等を検証
- **Firestoreルール**: 既存の管理画面認可テスト(rulesエミュレータ)と同じ
  パターンで、`serverState`への直接read/writeが確実に拒否されることを検証
- **Flutter側**: `OnlineGameController`はFakeFirebaseFirestoreで購読・送信の
  配線のみを検証(ルール判定はここでは検証しない、サーバー側の責務のため)

## 8. 実装順序の提案(PR単位の目安)

1. ルール移植(TS) — 既存Dartテストの移植のみ、外部への影響なし
2. `onRoomStart`(盤面生成) + `serverState`のルール締め出し
3. `submitOnlineAction`(行動検証・視点更新) + `actions`直書き込みの廃止
4. `OnlineGameController` + ロビー→実ゲーム画面の接続
5. 上記のテスト一式
6. 既存のCPU戦のログ/管理画面と同等の記録・可視化(優先度は低め、後回し可)

## 9. 未決定事項(実装前に確認したいこと)

- Cloud Functionsのランタイム言語: TypeScript推奨(型があるとルール移植の
  ミスを検出しやすい)で良いか、Node.js(JS)で十分か
- 対戦中の切断・再接続時の挙動(タイムアウトで不戦敗にするか、無期限に
  「相手の手番を待つ」ままにするか)
- Firebase Blazeプラン(従量課金)への切り替えが必要かどうかの確認
  (Cloud Functionsは無料のSparkプランでは動かせない)
