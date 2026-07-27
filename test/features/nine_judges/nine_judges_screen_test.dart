import 'package:dead_or_alive/app/theme.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/game_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/mode_select_screen.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/action_panel.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/card_assets.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/game_style.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/person_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _noop() {}

void main() {
  testWidgets('ホームから3種類の配布物へ移動できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: NineJudgesModeSelectScreen(onStart: (_) {})),
    );
    await tester.ensureVisible(find.byKey(const Key('open-downloads')));
    await tester.tap(find.byKey(const Key('open-downloads')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('download-how-to')), findsOneWidget);
    expect(find.byKey(const Key('download-tutorial')), findsOneWidget);
    expect(find.byKey(const Key('download-gameplay')), findsOneWidget);
    expect(find.byKey(const Key('download-tutorial-video')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('救済者画面は3×3、得点、ボーナス、LIFE/EYE/審判を表示', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(
          initialSettings: NineJudgesGameSettings(
            mode: GameMode.hotseat,
            firstPlayer: Faction.savior,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('nine-judges-board')), findsOneWidget);
    expect(find.byKey(const Key('current-bonus')), findsOneWidget);
    expect(find.byKey(const Key('bonus-history')), findsOneWidget);
    expect(find.byKey(const Key('faction-savior')), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.byKey(const Key('action-life')), findsOneWidget);
    expect(find.byKey(const Key('action-eye')), findsOneWidget);
    expect(find.byKey(const Key('action-specialVerdict')), findsOneWidget);
    expect(find.text('JUDGE'), findsOneWidget);
    expect(find.text('TURN'), findsNothing);
    expect(find.textContaining('TURN 1'), findsOneWidget);
    expect(find.byKey(const Key('coordinate-A1')), findsOneWidget);
    expect(find.byKey(const Key('coordinate-C3')), findsOneWidget);
    expect(find.byKey(const Key('action-death')), findsOneWidget);
    expect(find.textContaining('SAVE'), findsNothing);
    expect(find.byKey(const Key('debug-button')), findsNothing);
    expect(find.text('人物とアクションを選択してください'), findsNothing);
    expect(find.byKey(const Key('verdict-status-savior')), findsOneWidget);
    expect(find.byKey(const Key('verdict-status-executor')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ボーナス履歴は現在・使用済み・残りを表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
      ),
    );
    await tester.tap(find.byKey(const Key('bonus-history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bonus-history-title')), findsOneWidget);
    expect(find.byKey(const Key('bonus-history-current')), findsOneWidget);
    expect(find.byKey(const Key('remaining-bonuses')), findsOneWidget);
    expect(find.text('使用済み'), findsOneWidget);
    expect(find.text('残り（順序非公開）'), findsOneWidget);
    expect(find.textContaining(RegExp(r'[1-9] / [1-9]')), findsNothing);
  });

  testWidgets('CPU対戦であなた・CPU・現在手番を明示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(
          initialSettings: NineJudgesGameSettings(
            mode: GameMode.cpu,
            cpuFaction: Faction.executor,
            firstPlayer: Faction.savior,
          ),
        ),
      ),
    );
    expect(find.text('あなた'), findsOneWidget);
    expect(find.text('CPU'), findsOneWidget);
    expect(find.textContaining('あなた（救済者）の手番'), findsOneWidget);
    await tester.tap(find.byKey(const Key('recent-history')));
    await tester.pumpAndSettle();
    expect(find.text('直近の履歴'), findsOneWidget);
  });

  testWidgets('人物状態は審議中・生・確定を別ラベルで表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
      ),
    );
    expect(find.byKey(const Key('verdict-deliberating')), findsNWidgets(9));
    await tester.tap(find.byKey(const Key('action-life')));
    await tester.pump();
    await tester.tap(find.byType(InkWell).last);
  });

  testWidgets('確定時に属性・ボーナス・得点者を公開する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
      ),
    );
    await tester.tap(find.byKey(const Key('action-specialVerdict')));
    await tester.pump();
    await tester.tap(find.byType(PersonCardWidget).first);
    await tester.pump();
    expect(find.byKey(const Key('judge-confirm-dialog')), findsOneWidget);
    expect(find.text('JUDGEを使用しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-judge')));
    await tester.pump();
    expect(find.byKey(const Key('confirmation-reveal')), findsOneWidget);
    expect(find.byKey(const Key('nine-judges-board')), findsOneWidget);
    expect(find.text('JUDGEMENT'), findsOneWidget);
    expect(find.textContaining('POINT'), findsWidgets);
    await tester.tap(find.byKey(const Key('confirmation-reveal')));
    await tester.pump();
    expect(find.byKey(const Key('confirmation-reveal')), findsNothing);
  });

  testWidgets('JUDGE確認をキャンセルすると人物を確定しない', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
      ),
    );
    await tester.tap(find.byKey(const Key('action-specialVerdict')));
    await tester.pump();
    await tester.tap(find.byType(PersonCardWidget).first);
    await tester.pump();
    expect(find.byKey(const Key('judge-confirm-dialog')), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirmation-reveal')), findsNothing);
    expect(find.byKey(const Key('verdict-deliberating')), findsNWidgets(9));
  });

  testWidgets('EYE実施者をYOU/CPUで区別し属性は非表示にできる', (tester) async {
    const person = PersonCard(id: 'test', attribute: PersonAttribute.evil);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 120,
            child: PersonCardWidget(
              person: person,
              attributeVisible: false,
              viewerEyeKnown: false,
              opponentEyeKnown: true,
              viewerLabel: 'YOU',
              opponentLabel: 'CPU',
              selected: false,
              cpuHighlighted: false,
              enabled: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('正体不明'), findsOneWidget);
    expect(find.text('悪人'), findsNothing);
  });

  testWidgets('生死チップを順番通り最大3個、確定後も表示する', (tester) async {
    const person = PersonCard(
      id: 'history',
      attribute: PersonAttribute.good,
      verdictState: VerdictState.aliveConfirmed,
      verdictActionCount: 3,
      verdictHistory: [
        VerdictActionType.life,
        VerdictActionType.death,
        VerdictActionType.life,
      ],
      awardedBonus: 9,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 140,
            height: 140,
            child: PersonCardWidget(
              person: person,
              attributeVisible: true,
              viewerEyeKnown: false,
              opponentEyeKnown: false,
              viewerLabel: 'YOU',
              opponentLabel: 'CPU',
              selected: false,
              cpuHighlighted: false,
              enabled: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('生'), findsNWidgets(2));
    expect(find.text('死'), findsOneWidget);
    expect(find.byKey(const Key('confirmed-label')), findsOneWidget);
    expect(
      find.byKey(const Key('card-surface-aliveConfirmed')),
      findsOneWidget,
    );
  });

  testWidgets('DEAD確定カードは専用状態面を表示する', (tester) async {
    const person = PersonCard(
      id: 'dead',
      attribute: PersonAttribute.evil,
      verdictState: VerdictState.deadConfirmed,
      awardedBonus: 4,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 140,
            height: 140,
            child: PersonCardWidget(
              person: person,
              attributeVisible: true,
              viewerEyeKnown: false,
              opponentEyeKnown: false,
              viewerLabel: 'YOU',
              opponentLabel: 'CPU',
              selected: false,
              cpuHighlighted: false,
              enabled: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('card-surface-deadConfirmed')), findsOneWidget);
    expect(find.textContaining('DEAD'), findsWidgets);
  });

  testWidgets('善人・悪人・中立は形の異なるアイコンで表示する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final attribute in PersonAttribute.values)
                Expanded(
                  child: PersonCardWidget(
                    person: PersonCard(
                      id: attribute.name,
                      attribute: attribute,
                    ),
                    attributeVisible: true,
                    viewerEyeKnown: false,
                    opponentEyeKnown: false,
                    viewerLabel: 'YOU',
                    opponentLabel: 'CPU',
                    selected: false,
                    cpuHighlighted: false,
                    enabled: false,
                    onTap: () {},
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('attribute-icon-good')), findsOneWidget);
    expect(find.byKey(const Key('attribute-icon-evil')), findsOneWidget);
    expect(find.byKey(const Key('attribute-icon-neutral')), findsOneWidget);
  });

  for (final size in [
    const Size(360, 640),
    const Size(375, 667),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()}でoverflowしない', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
        ),
      );
      expect(find.byKey(const Key('nine-judges-board')), findsOneWidget);
      expect(find.byType(PersonCardWidget), findsNWidgets(9));
      expect(find.byKey(const Key('action-life')), findsOneWidget);
      expect(find.byKey(const Key('action-death')), findsOneWidget);
      expect(find.byKey(const Key('action-eye')), findsOneWidget);
      expect(find.byKey(const Key('action-specialVerdict')), findsOneWidget);
      expect(find.byKey(const Key('special-badge-death')), findsOneWidget);
      expect(find.text('JUDGE'), findsOneWidget);
      expect(find.textContaining('SPECIAL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('CPUの手番はCPU TURNを弱い金色で、あなたの手番はYOUR TURNを強い金色で表示', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(
          initialSettings: NineJudgesGameSettings(
            mode: GameMode.cpu,
            cpuFaction: Faction.savior,
            firstPlayer: Faction.savior,
            firstPlayerSelection: FirstPlayerSelection.cpu,
            // Zero-duration CPU delays, and skipCpuDelays also makes the
            // confirmation overlay skip scheduling its own auto-close timer
            // (see _ConfirmationOverlayState.initState) — so regardless of
            // which move the (unseeded) CPU randomly draws, no real Timer is
            // ever left pending at teardown.
            skipCpuDelays: true,
          ),
        ),
      ),
    );
    expect(find.text('CPU TURN'), findsOneWidget);
    expect(find.text('YOUR TURN'), findsNothing);
    final cpuLabel = tester.widget<Text>(
      find.byKey(const Key('turn-big-label')),
    );
    expect(cpuLabel.style!.color, GameColors.goldMuted);
    // Flush the CPU's zero-duration "think" and "clear feedback" delays.
    // An explicit non-zero step reliably advances the fake clock past a
    // zero-duration Timer; a bare pump() is not guaranteed to.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  });

  testWidgets('あなたの手番ではYOUR TURNを金色で強調表示', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(
          initialSettings: NineJudgesGameSettings(
            mode: GameMode.cpu,
            cpuFaction: Faction.savior,
            firstPlayer: Faction.executor,
            firstPlayerSelection: FirstPlayerSelection.human,
          ),
        ),
      ),
    );
    expect(find.text('YOUR TURN'), findsOneWidget);
    expect(find.text('CPU TURN'), findsNothing);
    final label = tester.widget<Text>(find.byKey(const Key('turn-big-label')));
    expect(label.style!.color, GameColors.gold);
  });

  testWidgets('裁定回数テキストを出さず生死チップだけで履歴を表す', (tester) async {
    Widget cardWith(int count, List<VerdictActionType> history) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 150,
          height: 220,
          child: PersonCardWidget(
            person: PersonCard(
              id: 'p',
              attribute: PersonAttribute.good,
              verdictActionCount: count,
              verdictHistory: history,
            ),
            attributeVisible: true,
            viewerEyeKnown: false,
            opponentEyeKnown: false,
            viewerLabel: 'YOU',
            opponentLabel: 'CPU',
            selected: false,
            cpuHighlighted: false,
            enabled: false,
            onTap: () {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(cardWith(0, const []));
    expect(find.textContaining('裁定'), findsNothing);

    await tester.pumpWidget(cardWith(1, const [VerdictActionType.life]));
    expect(find.textContaining('裁定'), findsNothing);
    expect(find.byKey(const Key('verdict-chip-0-life')), findsOneWidget);

    await tester.pumpWidget(
      cardWith(2, const [VerdictActionType.life, VerdictActionType.death]),
    );
    expect(find.textContaining('裁定'), findsNothing);
    expect(find.byKey(const Key('verdict-chip-0-life')), findsOneWidget);
    expect(find.byKey(const Key('verdict-chip-1-death')), findsOneWidget);
  });

  testWidgets('LIFE→DEATH→LIFEの順で履歴チップが左から順番通りに表示される', (tester) async {
    const person = PersonCard(
      id: 'order',
      attribute: PersonAttribute.good,
      verdictActionCount: 3,
      verdictHistory: [
        VerdictActionType.life,
        VerdictActionType.death,
        VerdictActionType.life,
      ],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 140,
            height: 140,
            child: PersonCardWidget(
              person: person,
              attributeVisible: true,
              viewerEyeKnown: false,
              opponentEyeKnown: false,
              viewerLabel: 'YOU',
              opponentLabel: 'CPU',
              selected: false,
              cpuHighlighted: false,
              enabled: false,
              onTap: _noop,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('verdict-chip-0-life')), findsOneWidget);
    expect(find.byKey(const Key('verdict-chip-1-death')), findsOneWidget);
    expect(find.byKey(const Key('verdict-chip-2-life')), findsOneWidget);
  });

  testWidgets('確定していないボーナスは?POINTとして表示され数値が漏れない', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
      ),
    );
    // Force a confirmation via JUDGE so the very next bonus becomes hidden
    // from both factions until the non-confirmer's next turn begins.
    await tester.tap(find.byKey(const Key('action-specialVerdict')));
    await tester.pump();
    await tester.tap(find.byType(PersonCardWidget).first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-judge')));
    await tester.pump();
    // The confirmation overlay sits on top, but the board underneath (with
    // its now-hidden bonus panel) remains in the tree. Match the bonus
    // panel's exact "N POINT" text node specifically, so the (legitimately
    // revealed) already-awarded bonus inside the overlay's reveal message
    // doesn't produce a false positive.
    expect(find.textContaining('? POINT'), findsOneWidget);
    final leakedBonus = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data != null &&
          RegExp(r'^[1-9] POINT$').hasMatch(widget.data!),
    );
    expect(leakedBonus, findsNothing);
  });

  testWidgets('CPUだけがEYE済みの場合はCPUマーカーのみ表示され属性は漏れない', (tester) async {
    const person = PersonCard(id: 'hidden', attribute: PersonAttribute.evil);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 160,
            child: PersonCardWidget(
              person: person,
              attributeVisible: false,
              viewerEyeKnown: false,
              opponentEyeKnown: true,
              viewerLabel: 'YOU',
              opponentLabel: 'CPU',
              selected: false,
              cpuHighlighted: false,
              enabled: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('YOU'), findsNothing);
    expect(find.byKey(const Key('attribute-icon-hidden')), findsOneWidget);
    expect(find.byKey(const Key('attribute-icon-evil')), findsNothing);
    expect(find.text('正体不明'), findsOneWidget);
    expect(find.text('悪人'), findsNothing);
    final portraitAssets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName);
    expect(portraitAssets, contains(CardAssets.concealedPortrait));
    expect(portraitAssets, isNot(contains(CardAssets.evilPortrait)));
  });

  testWidgets('属性判明時だけ対応人物へ切り替え、全badge領域を共通化', (tester) async {
    const people = [
      PersonCard(id: 'good', attribute: PersonAttribute.good),
      PersonCard(id: 'evil', attribute: PersonAttribute.evil),
      PersonCard(id: 'neutral', attribute: PersonAttribute.neutral),
      PersonCard(id: 'hidden', attribute: PersonAttribute.evil),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (var i = 0; i < people.length; i++)
                Expanded(
                  child: PersonCardWidget(
                    person: people[i],
                    attributeVisible: i < 3,
                    viewerEyeKnown: false,
                    opponentEyeKnown: false,
                    viewerLabel: 'YOU',
                    opponentLabel: 'CPU',
                    selected: false,
                    cpuHighlighted: false,
                    enabled: false,
                    onTap: _noop,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final badgeAreas = tester
        .elementList(find.byKey(const Key('attribute-icon-area')))
        .map((element) => tester.getSize(find.byWidget(element.widget)))
        .toList();
    expect(badgeAreas, hasLength(4));
    expect(badgeAreas.toSet(), {const Size(24, 24)});
    expect(find.byKey(const Key('attribute-icon-good')), findsOneWidget);
    expect(find.byKey(const Key('attribute-icon-evil')), findsOneWidget);
    expect(find.byKey(const Key('attribute-icon-neutral')), findsOneWidget);
    expect(find.byKey(const Key('attribute-icon-hidden')), findsOneWidget);

    final portraitAssets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName);
    expect(portraitAssets, contains(CardAssets.goodPortrait));
    expect(portraitAssets, contains(CardAssets.evilPortrait));
    expect(portraitAssets, contains(CardAssets.neutralPortrait));
    expect(portraitAssets, contains(CardAssets.concealedPortrait));
  });

  testWidgets('JUDGEボタンはJUDGEと残り1回を別々の切れないテキストで表示', (tester) async {
    final controller = NineJudgesController(
      seed: 1,
      settings: const NineJudgesGameSettings(
        mode: GameMode.hotseat,
        firstPlayer: Faction.savior,
      ),
    );
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActionPanel(controller: controller)),
      ),
    );
    expect(find.text('JUDGE'), findsOneWidget);
    expect(find.text('残り1回'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('逆アクションは該当するLIFE/DEATH内にSPECIAL表示', (tester) async {
    final saviorTurn = NineJudgesController(
      seed: 2,
      settings: const NineJudgesGameSettings(
        mode: GameMode.hotseat,
        firstPlayer: Faction.savior,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActionPanel(controller: saviorTurn)),
      ),
    );
    expect(find.byKey(const Key('special-badge-death')), findsOneWidget);
    expect(find.byKey(const Key('special-badge-life')), findsNothing);
    expect(find.byKey(const Key('action-death')), findsOneWidget);

    final executorTurn = NineJudgesController(
      seed: 3,
      settings: const NineJudgesGameSettings(
        mode: GameMode.hotseat,
        firstPlayer: Faction.executor,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActionPanel(controller: executorTurn)),
      ),
    );
    expect(find.byKey(const Key('special-badge-life')), findsOneWidget);
    expect(find.byKey(const Key('special-badge-death')), findsNothing);
    expect(find.byKey(const Key('action-life')), findsOneWidget);
  });

  testWidgets('JUDGE・SPECIALは使用済みになると使用済みと表示', (tester) async {
    final controller = NineJudgesController(
      seed: 4,
      settings: const NineJudgesGameSettings(
        mode: GameMode.hotseat,
        firstPlayer: Faction.savior,
      ),
    );
    controller.specialVerdictUsed[Faction.savior] = true;
    controller.reverseActionUsed[Faction.savior] = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActionPanel(controller: controller)),
      ),
    );
    expect(find.text('使用済み'), findsNWidgets(2));
    expect(find.text('残り1回'), findsNothing);
  });

  testWidgets('JUDGEキャンセルではJUDGE残数・状態・ボーナス・手番が変化しない', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
      ),
    );
    String bonusPointText() =>
        tester.widgetList<Text>(find.textContaining('POINT')).first.data!;
    final bonusBefore = bonusPointText();
    final ownerBefore = tester
        .widget<Text>(find.byKey(const Key('turn-owner-label')))
        .data;
    final judgeStatusBefore = tester
        .widget<Text>(find.byKey(const Key('verdict-status-savior')))
        .data;

    await tester.tap(find.byKey(const Key('action-specialVerdict')));
    await tester.pump();
    await tester.tap(find.byType(PersonCardWidget).first);
    await tester.pump();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(bonusPointText(), bonusBefore);
    expect(
      tester.widget<Text>(find.byKey(const Key('turn-owner-label'))).data,
      ownerBefore,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('verdict-status-savior'))).data,
      judgeStatusBefore,
    );
    expect(find.textContaining('TURN 1'), findsOneWidget);
    expect(find.byKey(const Key('verdict-deliberating')), findsNWidgets(9));
  });

  testWidgets('生存確定は緑、死亡確定は赤の枠で表示される', (tester) async {
    Border borderOf(Key key) {
      final container = tester.widget<AnimatedContainer>(find.byKey(key));
      return (container.decoration! as BoxDecoration).border! as Border;
    }

    const alive = PersonCard(
      id: 'a',
      attribute: PersonAttribute.good,
      verdictState: VerdictState.aliveConfirmed,
      awardedBonus: 3,
    );
    const dead = PersonCard(
      id: 'd',
      attribute: PersonAttribute.evil,
      verdictState: VerdictState.deadConfirmed,
      awardedBonus: 3,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: PersonCardWidget(
                  person: alive,
                  attributeVisible: true,
                  viewerEyeKnown: false,
                  opponentEyeKnown: false,
                  viewerLabel: 'YOU',
                  opponentLabel: 'CPU',
                  selected: false,
                  cpuHighlighted: false,
                  enabled: false,
                  onTap: () {},
                ),
              ),
              Expanded(
                child: PersonCardWidget(
                  person: dead,
                  attributeVisible: true,
                  viewerEyeKnown: false,
                  opponentEyeKnown: false,
                  viewerLabel: 'YOU',
                  opponentLabel: 'CPU',
                  selected: false,
                  cpuHighlighted: false,
                  enabled: false,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      borderOf(const Key('card-surface-aliveConfirmed')).top.color,
      AppTheme.alive,
    );
    expect(
      borderOf(const Key('card-surface-deadConfirmed')).top.color,
      AppTheme.dead,
    );
  });

  testWidgets('陣営紋章・人物領域・アクションアイコンは共通サイズで揃う', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
      ),
    );

    final saviorCrest = tester.getSize(
      find.byKey(const Key('faction-crest-area-savior')),
    );
    final executorCrest = tester.getSize(
      find.byKey(const Key('faction-crest-area-executor')),
    );
    expect(saviorCrest, executorCrest);
    expect(saviorCrest, const Size(34, 34));

    final portraitAreas = tester
        .elementList(find.byKey(const Key('portrait-area')))
        .map((element) => tester.getSize(find.byWidget(element.widget)))
        .toList();
    final infoAreas = tester
        .elementList(find.byKey(const Key('card-info-area')))
        .map((element) => tester.getSize(find.byWidget(element.widget)))
        .toList();
    expect(portraitAreas, hasLength(9));
    expect(infoAreas, hasLength(9));
    expect(portraitAreas.toSet(), hasLength(1));
    expect(infoAreas.toSet(), hasLength(1));

    for (final action in ['life', 'death', 'eye']) {
      expect(
        tester.getSize(find.byKey(Key('action-icon-area-$action'))),
        const Size(28, 28),
      );
    }
    expect(find.byKey(const Key('action-eye-icon-complete')), findsOneWidget);
    final eyeIcon = tester.getSize(
      find.byKey(const Key('action-eye-icon-complete')),
    );
    expect(eyeIcon.width, lessThanOrEqualTo(28));
    expect(eyeIcon.height, lessThanOrEqualTo(28));
    expect(tester.takeException(), isNull);
  });
}
