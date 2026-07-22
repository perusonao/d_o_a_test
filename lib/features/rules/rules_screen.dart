import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// ルール説明画面（Ver.0.3）。
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ルール')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                _Section(
                  icon: Icons.remove_red_eye,
                  title: '核',
                  body:
                      '中央に伏せた9枚を巡り、「自分だけが一部の正体を知っている」情報差を武器に、'
                      '善人を生かすか殺すかを争う心理戦です。',
                ),
                _Section(
                  icon: Icons.grid_view,
                  title: '場と情報',
                  body:
                      '善人3・悪人3・中立3の計9枚を中央に3×3で伏せます。開始時、'
                      'あなたと CPU はそれぞれ異なる3枚の正体だけを知り、3枚は誰も知りません。'
                      '正体（種類・数字）は終了時まで非公開。状態（生存/死亡/封印）だけが見えます。',
                ),
                _Section(
                  icon: Icons.groups,
                  title: '役割',
                  body:
                      '救済者は善人を生存させ、執行者は善人を死亡させることを目指します。',
                ),
                _Section(
                  icon: Icons.bolt,
                  title: '行動とパワー判定',
                  body:
                      '手番ごとに手札（デッド/アライブ/シール）を1枚選び、中央の1枚に使います。'
                      '生死カードの数字 ≧ 相手の数字 なら成功。'
                      '失敗しても正体は公開されず、「そのパワーでは倒せなかった」事実だけが手がかりになります。',
                ),
                _Section(
                  icon: Icons.lock,
                  title: '効果',
                  body:
                      'デッド＝死亡、アライブ＝生存（復活）、シール＝封印（終了まで状態固定）。'
                      'シールは各プレイヤー1回のみ。終盤の決め手になります。',
                ),
                _Section(
                  icon: Icons.emoji_events,
                  title: '得点と勝敗',
                  body:
                      '全手番終了で正体を一斉公開し集計します。'
                      '救済者＝生存善人2点・死亡悪人/中立1点。執行者＝死亡善人2点・生存悪人/中立1点。'
                      '中立は「自分の本能どおり」に扱うと相手の得点になるので注意。合計点が高い方の勝ち。',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.accent, size: 22),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.good)),
            ],
          ),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  fontSize: 14, height: 1.5, color: Color(0xFFCFC7B5))),
        ],
      ),
    );
  }
}
