// ゲーム全体で使用する列挙型をまとめたファイル。
// ルール変更をしやすくするため、状態や種類は全て enum で表現する。

/// 人カードの種類。
enum PersonType {
  good, // 善人
  evil, // 悪人
  neutral, // 中立
}

/// 人カードの現在状態。
enum PersonStatus {
  hidden, // 未確定（本プロトタイプでは初期状態を alive にするため実質未使用だが将来用に保持）
  alive, // 生存
  dead, // 死亡
}

/// 情報公開レベル。
enum RevealLevel {
  none, // 完全非公開
  numberOnly, // 数字のみ公開
  full, // 種類と数字を公開
}

/// 生死カードの効果。
enum LifeDeathEffect {
  dead, // デッド
  alive, // アライブ
  keep, // キープ
}

/// 陣営。
enum Faction {
  good, // 善人陣営
  evil, // 悪人陣営
}

/// カードの所有者 / ターンの担当者。
enum TurnOwner {
  player, // プレイヤー
  cpu, // CPU
}

/// ゲームの進行フェーズ。
enum GamePhase {
  playerTurn, // プレイヤーのターン
  cpuTurn, // CPU のターン
  resolving, // 効果判定中（アニメーション等で入力を止める）
  finished, // ゲーム終了
}
