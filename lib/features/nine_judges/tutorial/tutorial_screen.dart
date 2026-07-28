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
    'あなたは救済者です。自陣3人（A3・B3・C3）の正体は最初から見えています。'
        '善人と中立を生へ、悪人を死へ導きましょう。',
    'まず、既知の善人B3へLIFEを使ってみましょう。1回だけでは確定しません。',
    'EYEが使えるのは中央のA2・B2・C2だけ。自陣にも相手陣にも使えません。'
        'まずB2を確認しましょう。',
    'EYEの結果はあなただけに見えます。相手の画面には伝わりません。次はCPUの番です。',
    'CPUが中央のA2へEYEを使いました。CPUが見たことは分かりますが、'
        '属性はあなたには見えません。',
    'EYEは1ゲームにつき2回まで。あなたの残りEYEは1回です。',
    '中央のC2はまだ誰も見ていません。3人全員を確認することはできないため、'
        '残り1人は行動や相手の反応から推理しましょう。',
    'CPUが同じB3へDEATHで対抗し、あなたがもう一度LIFEで押し返します。'
        '3回目の判定でB3は生確定します。',
    'CPUがA1をJUDGEで確定させます。あなたもC1へJUDGEを使ってみましょう。',
    '確定するたびに審判ボーナスが入ります。最初のボーナスは両者に公開、'
        '以降は確定させなかった側だけが次の値を先に知ります。',
    'チュートリアル完了。中央3人のうち2人しか見られない読み合いを意識して、'
        '実戦に挑みましょう。',
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

  /// Forces the actor for this scripted step: hotseat mode alternates
  /// [NineJudgesController.currentPlayer] after every real action, but this
  /// fixed lesson needs specific back-to-back actors (e.g. the player using
  /// two of their own actions in a row) regardless of whichever turn the
  /// engine would naturally be on. `currentPlayer` is plain mutable state on
  /// the controller — same liberty [initState] already takes with the board.
  bool _act(Faction actor, ActionType action, int target) {
    game.currentPlayer = actor;
    final applied = game.performTutorialAction(action, target);
    if (applied) _settle();
    return applied;
  }

  void _advance() {
    var applied = true;
    switch (step) {
      case 1:
        applied = _act(Faction.savior, ActionType.life, 7);
        break;
      case 2:
        applied = _act(Faction.savior, ActionType.eye, 4);
        break;
      case 3:
        applied = _act(Faction.executor, ActionType.eye, 3);
        break;
      case 7:
        applied = _act(Faction.executor, ActionType.death, 7);
        if (applied) applied = _act(Faction.savior, ActionType.life, 7);
        break;
      case 8:
        applied = _act(Faction.executor, ActionType.specialVerdict, 0);
        if (applied) {
          applied = _act(Faction.savior, ActionType.specialVerdict, 2);
        }
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
    1 => 'B3にLIFE',
    2 => 'B2にEYE',
    3 => 'CPU：A2にEYE',
    7 => 'B3で攻防',
    8 => 'C1にJUDGE',
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
                  step == 2 || step == 3
                      ? Icons.visibility
                      : step == 8
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
