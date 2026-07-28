import 'package:flutter/material.dart';

class RulesGuideScreen extends StatefulWidget {
  const RulesGuideScreen({super.key});

  @override
  State<RulesGuideScreen> createState() => _RulesGuideScreenState();
}

class _RulesGuideScreenState extends State<RulesGuideScreen> {
  final _controller = PageController();
  var _page = 0;

  static const _pages = <({String title, IconData icon, List<String> lines})>[
    (
      title: 'あなたの役割',
      icon: Icons.groups_outlined,
      lines: [
        '救済者：善人・中立をLIFE、悪人をDEATH',
        '執行者：善人・中立をDEATH、悪人をLIFE',
        '判決ボーナスの合計点を競います。',
      ],
    ),
    (
      title: '9人の人間',
      icon: Icons.grid_view,
      lines: [
        '善人3・悪人3・中立3を3×3に配置。',
        '正体は基本的に秘密です。',
        '自分側のA3・B3・C3だけ最初から分かります。',
      ],
    ),
    (
      title: 'LIFE / DEATH',
      icon: Icons.compare_arrows,
      lines: [
        '審議中 → LIFE → 生 → LIFE → 生確定',
        '審議中 → DEATH → 死 → DEATH → 死確定',
        '異なる操作を重ねても3回目で必ず確定します。',
      ],
    ),
    (
      title: 'EYE',
      icon: Icons.visibility_outlined,
      lines: [
        '中央3人のうち、正体を知らない人物1人を確認します。',
        '各プレイヤー2回まで。同じ人物への再使用はできません。',
        '3人全員を見ることはできないため、残り1人は推理しましょう。',
        '結果を知るのは自分だけ。相手には「どこを見たか」だけ伝わります。',
      ],
    ),
    (
      title: 'JUDGE',
      icon: Icons.gavel,
      lines: [
        '各プレイヤーがゲーム中1回だけ使用。',
        '未介入の審議中人物を直接確定します。',
        '救済者はALIVE、執行者はDEADに確定します。',
      ],
    ),
    (
      title: '逆転の一手',
      icon: Icons.swap_horiz,
      lines: [
        '救済者はDEATHを1回だけ使用できます。',
        '執行者はLIFEを1回だけ使用できます。',
        'ここぞという人物に使う切り札です。',
      ],
    ),
    (
      title: '審判ボーナス',
      icon: Icons.stars_outlined,
      lines: [
        '1〜9をシャッフルし、確定順に1枚ずつ使用。',
        '最初だけ両者に公開。',
        '以降は前の確定者ではない側だけ次の値を知ります。',
        '未来の並び順は公開されません。',
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('遊び方')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              key: const Key('rules-pages'),
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                final page = _pages[index];
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(page.icon, size: 72, color: const Color(0xFFD6B25E)),
                      const SizedBox(height: 24),
                      Text(
                        page.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      for (final line in page.lines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            line,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Text('${_page + 1} / ${_pages.length}'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_page > 0)
                  TextButton(
                    onPressed: () => _controller.previousPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    ),
                    child: const Text('戻る'),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('rules-next'),
                  onPressed: () {
                    if (_page == _pages.length - 1) {
                      Navigator.pop(context);
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(_page == _pages.length - 1 ? '閉じる' : '次へ'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
