// Ver.0.4 で使用する列挙型。

/// 人間カードの種類。
enum HumanType {
  good, // 善人
  neutral, // 中立
  evil, // 悪人
}

/// 人間カードの生死状態。
enum CardState {
  alive, // 生
  dead, // 死
}

/// アクションカードの種類。
enum ActionType {
  life, // 生カード
  death, // 死カード
  protect, // 保カード
}

/// 陣営。
enum Faction {
  savior, // 救済者
  executioner, // 執行者
}

/// プレイヤー識別（ローカル2人対戦）。
enum PlayerId {
  a, // プレイヤーA（左列を確認）
  b, // プレイヤーB（右列を確認）
}

/// ゲームの進行フェーズ。
enum GamePhase {
  peekA, // プレイヤーAが左列を確認
  peekB, // プレイヤーBが右列を確認
  playing, // 対戦中
  finished, // 終了
}
