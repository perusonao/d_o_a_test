// Ver.0.3 で使用する列挙型をまとめたファイル。
// ルール変更をしやすくするため、状態や種類は全て enum で表現する。

/// 人カードの種類。
enum PersonType {
  good, // 善人
  evil, // 悪人
  neutral, // 中立
}

/// 人カードの現在状態。
enum PersonStatus {
  alive, // 生存
  dead, // 死亡
}

/// そのカードの正体を誰が知っているか（重複しないので単一）。
enum Knower {
  none, // 誰も知らない
  player, // プレイヤーだけが知る
  cpu, // CPU だけが知る
}

/// 生死カードの効果。
enum LifeDeathEffect {
  dead, // デッド
  alive, // アライブ
  seal, // シール（恒久固定）
}

/// 陣営＝役割。
enum Role {
  savior, // 救済者：善人を生存させる
  executioner, // 執行者：善人を死亡させる
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
  resolving, // 効果判定中（入力を止める）
  finished, // ゲーム終了
}
