import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';
import 'package:flutter/material.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late final NineJudgesController game;
  var step = 0;

  static const messages = [
    'あなたは救済者です。善人と中立を生へ、悪人を死へ導きましょう。',
    '手前のA3・B3・C3は、ゲーム開始時からあなただけが正体を知っています。',
    '未知のB2をEYEで調査します。実際のゲームと同じ知識管理を使います。',
    '既知の善人B3へLIFEを置きます。',
    'CPUが同じB3へDEATHを置いて対抗します。',
    'もう一度LIFE。3枚目のチップでB3が生確定します。',
    'あなたが確定者なので、次のボーナスを知るのはCPUだけです。',
    'CPUがA1をJUDGE。今度はあなたが次のボーナスを知ります。',
    'JUDGEは各陣営1回だけ。あなたもC1へJUDGEを使います。',
    '救済者も1回だけ逆属性のDEATHを使用できます。',
    'チュートリアル完了。情報・介入・判決の流れを実戦で試しましょう。',
  ];

  @override
  void initState() {
    super.initState();
    game = NineJudgesController(
      seed: 1101,
      settings: const NineJudgesGameSettings(
        mode: GameMode.hotseat,
        firstPlayer: Faction.savior,
      ),
    );
    // B3 is always the known GOOD target in this deterministic lesson.
    final goodIndex = game.board.indexWhere(
      (slot) => slot.person.attribute == PersonAttribute.good,
    );
    final temporary = game.board[7];
    game.board[7] = game.board[goodIndex];
    game.board[goodIndex] = temporary;
  }

  @override
  void dispose() {
    game.dispose();
    super.dispose();
  }

  void _settle() {
    if (game.awaitingConfirmationReveal) {
      game.confirmConfirmationReveal();
    }
    if (game.awaitingHandoff) game.confirmHandoff();
  }

  bool _act(ActionType action, int target) {
    final applied = game.performTutorialAction(action, target);
    if (applied) _settle();
    return applied;
  }

  void _advance() {
    var applied = true;
    switch (step) {
      case 2:
        applied = _act(ActionType.eye, 4);
        if (applied) applied = _act(ActionType.eye, 3); // scripted CPU turn
        break;
      case 3:
        applied = _act(ActionType.life, 7);
        break;
      case 4:
        applied = _act(ActionType.death, 7);
        break;
      case 5:
        applied = _act(ActionType.life, 7);
        break;
      case 7:
        applied = _act(ActionType.specialVerdict, 0);
        break;
      case 8:
        applied = _act(ActionType.specialVerdict, 2);
        break;
      case 9:
        applied = _act(ActionType.eye, 5); // scripted CPU turn
        if (applied) applied = _act(ActionType.death, 6);
        break;
    }
    if (!applied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作を適用できませんでした。もう一度お試しください。')),
      );
      return;
    }
    setState(() => step = (step + 1).clamp(0, 10));
  }

  String get _buttonLabel => switch (step) {
    2 => 'B2にEYE',
    3 => 'B3にLIFE',
    4 => 'CPU：B3にDEATH',
    5 => 'B3にLIFE',
    7 => 'CPU：A1にJUDGE',
    8 => 'C1にJUDGE',
    9 => 'A3に特殊DEATH',
    _ => '次へ',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('チュートリアル ${step + 1}/11')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Container(
              key: const Key('tutorial-message'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF302714),
                border: Border.all(color: const Color(0xFFD6B25E)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(messages[step], textAlign: TextAlign.center),
            ),
            const SizedBox(height: 8),
            Expanded(child: BoardGrid(controller: game)),
            const SizedBox(height: 8),
            if (step < 10)
              FilledButton.icon(
                key: const Key('tutorial-next'),
                onPressed: _advance,
                icon: Icon(
                  step == 2
                      ? Icons.visibility
                      : step == 7 || step == 8
                      ? Icons.gavel
                      : Icons.touch_app,
                ),
                label: Text(_buttonLabel),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ホームへ戻る'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: const Key('tutorial-complete'),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('CPU対戦を始める'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
