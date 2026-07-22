import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// ルール説明画面。基本ルールを簡潔に表示する。
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
                  icon: Icons.flag,
                  title: '目的',
                  body:
                      '善人陣営は終了時に「生存している善人」を多く、悪人陣営は「生存している悪人」を多く残すことを目指します。',
                ),
                _Section(
                  icon: Icons.style,
                  title: 'カード',
                  body:
                      '場には人カード（善人・悪人・中立、数字1〜9）が各プレイヤー9枚並びます。手札の生死カード（デッド・アライブ・キープ、数字1〜9）で相手の場のカードを操作します。',
                ),
                _Section(
                  icon: Icons.bolt,
                  title: 'パワー判定',
                  body:
                      '生死カードの数字 ≧ 人カードの数字 なら成功。成功すると種類と数字が公開され、失敗すると数字のみ公開されます。',
                ),
                _Section(
                  icon: Icons.dangerous,
                  title: 'デッド / アライブ',
                  body:
                      'デッド成功で対象を死亡、アライブ成功で対象を生存（復活）させます。失敗すると状態は変化しません。',
                ),
                _Section(
                  icon: Icons.shield,
                  title: 'キープ',
                  body:
                      'キープ成功で対象に1回分の防御を付与。防御中のカードが次にデッド/アライブを受けると効果を無効化し、防御は解除されます。',
                ),
                _Section(
                  icon: Icons.theater_comedy,
                  title: '中立ペナルティ',
                  body:
                      '善人陣営が中立を死亡、悪人陣営が中立を生存させると、自分の未使用生死カードを最大3枚ランダムに失います。キープでは発生しません。',
                ),
                _Section(
                  icon: Icons.emoji_events,
                  title: '勝敗',
                  body:
                      '両者の手札が尽きたら終了。善人陣営は生存善人 > 生存悪人で勝利、悪人陣営は生存悪人 ≧ 生存善人で勝利（引き分けは悪人の勝ち）。中立は人数に含みません。',
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.good,
                ),
              ),
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
