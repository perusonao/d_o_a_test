import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/utils/card_visuals.dart';
import '../../../shared/widgets/life_death_card_widget.dart';
import '../../../shared/widgets/person_card_widget.dart';
import '../application/game_controller.dart';
import '../application/game_engine.dart';
import '../domain/enums.dart';
import '../domain/game_state.dart';
import '../domain/life_death_card.dart';
import '../domain/person_card.dart';
import '../domain/player_state.dart';
import 'widgets/game_log_view.dart';
import 'widgets/neutral_penalty_dialog.dart';

/// ゲーム本編画面。
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  String? _shownPenaltyOutcomeKey;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);

    // 終了したらリザルトへ遷移。
    ref.listen<GameState?>(gameControllerProvider, (prev, next) {
      if (next == null) return;
      _maybeShowPenalty(next);
      if (next.phase == GamePhase.finished) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(AppRoutes.result);
        });
      }
    });

    if (state == null) {
      // 直接 URL でアクセスした等。タイトルへ。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.title);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            const pad = 6.0;
            const gap = 5.0;
            final screenW = math.min(w, 560.0);
            final contentW = screenW - pad * 2;
            final selectable =
                state.phase == GamePhase.playerTurn && !state.isBusy;

            // 生死カード手札：横スクロールせず、5枚×2段で収める。
            const perRow = 5;
            const handRows = 2;
            final lifeW =
                ((contentW - gap * (perRow - 1)) / perRow).clamp(34.0, 46.0);
            final handH = handRows * (lifeW * 1.35) + (handRows - 1) * gap;

            // 固定要素の高さ見積り（この合計を差し引いた残りを人カードへ）。
            const infoH = 30.0;
            const turnH = 26.0;
            const logH = 48.0;
            const selInfoH = 18.0;
            const msgH = 14.0;
            const btnH = 44.0;
            const chromePad = 22.0; // 各種 padding / 余白の合算。
            final gapsH = gap * 8;
            final fixed = infoH +
                turnH +
                logH +
                selInfoH +
                msgH +
                btnH +
                handH +
                gapsH +
                chromePad;

            // 残り高さを人カード6段（CPU3段＋自分3段）で分け合う。
            final availPersons = h - fixed;
            final pByWidth = (contentW - gap * 2) / 3;
            final pByHeight = (availPersons / 6) / 1.28;
            final personSize =
                math.min(pByWidth, pByHeight).clamp(34.0, 112.0);

            final board = Padding(
              padding: const EdgeInsets.symmetric(horizontal: pad),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CpuInfoBar(cpu: state.cpu),
                  const SizedBox(height: gap),
                  _personGrid(
                    cards: state.cpu.persons,
                    ownerView: false,
                    state: state,
                    size: personSize,
                    gap: gap,
                    selectable: selectable,
                  ),
                  const SizedBox(height: gap),
                  _TurnIndicator(state: state),
                  const SizedBox(height: gap),
                  GameLogView(state: state),
                  const SizedBox(height: gap),
                  _personGrid(
                    cards: state.player.persons,
                    ownerView: true,
                    state: state,
                    size: personSize,
                    gap: gap,
                    selectable: false,
                  ),
                ],
              ),
            );

            return Center(
              child: SizedBox(
                width: screenW,
                child: Column(
                  children: [
                    // 通常は1画面に収まる。極端に低い画面のみ内部スクロールで救済。
                    Expanded(child: SingleChildScrollView(child: board)),
                    _HandArea(state: state, lifeWidth: lifeW),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _maybeShowPenalty(GameState state) {
    final o = state.lastOutcome;
    if (o == null || !o.neutralPenalty) return;
    final key = '${o.lifeDeathCardId}_${o.targetPersonId}';
    if (_shownPenaltyOutcomeKey == key) return;
    _shownPenaltyOutcomeKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showNeutralPenaltyDialog(context, o);
      }
    });
  }

  Widget _personGrid({
    required List<PersonCard> cards,
    required bool ownerView,
    required GameState state,
    required double size,
    required double gap,
    required bool selectable,
  }) {
    // 3列固定にするため、カード幅×3＋間隔ぶんに横幅を制限する。
    // （Wrap は横幅が許す限り詰め込むため、明示的に3列へ収める。）
    return Center(
      child: SizedBox(
        width: size * 3 + gap * 2,
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          alignment: WrapAlignment.center,
          children: cards.map((c) {
            final selected = !ownerView && state.selectedPersonId == c.id;
            return PersonCardWidget(
              card: c,
              ownerView: ownerView,
              size: size,
              selected: selected,
              selectable: selectable,
              highlight: _highlightFor(state, c, ownerView),
              onTap: () =>
                  ref.read(gameControllerProvider.notifier).selectPerson(c.id),
            );
          }).toList(),
        ),
      ),
    );
  }

  CardHighlight _highlightFor(GameState state, PersonCard card, bool ownerView) {
    final o = state.lastOutcome;
    if (o == null) return CardHighlight.none;
    final owner = ownerView ? TurnOwner.player : TurnOwner.cpu;
    if (o.targetPersonId != card.id || o.targetOwner != owner) {
      return CardHighlight.none;
    }
    if (o.guardBlocked) return CardHighlight.guard;
    return o.success ? CardHighlight.success : CardHighlight.fail;
  }
}

/// CPU 情報バー。
class _CpuInfoBar extends StatelessWidget {
  const _CpuInfoBar({required this.cpu});
  final PlayerState cpu;

  @override
  Widget build(BuildContext context) {
    final isGood = cpu.faction == Faction.good;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isGood ? Icons.balance : Icons.local_fire_department,
              color: AppTheme.factionColor(isGood), size: 18),
          const SizedBox(width: 6),
          Text('CPU：${GameLabels.faction(cpu.faction)}',
              style: TextStyle(
                  color: AppTheme.factionColor(isGood),
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const Spacer(),
          _pill(Icons.style, '手札 ${cpu.usableCards.length}'),
          const SizedBox(width: 6),
          _pill(Icons.delete_outline, '破棄 ${cpu.discardedCount}'),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFB9B2A2)),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(fontSize: 12, color: Color(0xFFB9B2A2))),
      ],
    );
  }
}

/// ターン表示。
class _TurnIndicator extends StatelessWidget {
  const _TurnIndicator({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    switch (state.phase) {
      case GamePhase.playerTurn:
        text = 'あなたのターン';
        color = AppTheme.good;
        break;
      case GamePhase.cpuTurn:
        text = 'CPU のターン…';
        color = AppTheme.evil;
        break;
      case GamePhase.resolving:
        text = '判定中…';
        color = AppTheme.accent;
        break;
      case GamePhase.finished:
        text = '決着';
        color = AppTheme.accent;
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

/// 画面下部：選択中カード情報＋手札＋決定ボタン。
/// 縦スクロールを避けるため、手札幅は上位で算出した [lifeWidth] を用いる。
class _HandArea extends ConsumerWidget {
  const _HandArea({required this.state, required this.lifeWidth});
  final GameState state;
  final double lifeWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    LifeDeathCard? selectedCard;
    final selId = state.selectedLifeDeathCardId;
    if (selId != null) {
      for (final c in state.player.hand) {
        if (c.id == selId) {
          selectedCard = c;
          break;
        }
      }
    }

    final canConfirm = state.phase == GamePhase.playerTurn &&
        !state.isBusy &&
        state.selectedLifeDeathCardId != null &&
        state.selectedPersonId != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Color(0x33B8862F))),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // メッセージ行（無効操作の理由など）。高さは常に確保しレイアウトを安定させる。
            SizedBox(
              height: 15,
              child: state.message == null
                  ? null
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline,
                            size: 13, color: AppTheme.evil),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(state.message!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.evil)),
                        ),
                      ],
                    ),
            ),
            // 選択中の生死カード情報。
            _SelectedInfo(
              selected: selectedCard,
              hasTarget: state.selectedPersonId != null,
            ),
            const SizedBox(height: 4),
            // 手札（横スクロールせず、幅を算出して2段に折り返し）。
            Wrap(
              spacing: 5,
              runSpacing: 5,
              alignment: WrapAlignment.center,
              children: state.player.hand.map((c) {
                return LifeDeathCardWidget(
                  card: c,
                  width: lifeWidth,
                  selected: state.selectedLifeDeathCardId == c.id,
                  enabled:
                      state.phase == GamePhase.playerTurn && !state.isBusy,
                  onTap: () => controller.selectLifeDeathCard(c.id),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canConfirm ? () => controller.confirm() : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: Text(state.isBusy ? '処理中…' : '決定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedInfo extends StatelessWidget {
  const _SelectedInfo({required this.selected, required this.hasTarget});
  final LifeDeathCard? selected;
  final bool hasTarget;

  @override
  Widget build(BuildContext context) {
    final card = selected;
    if (card == null) {
      return const Text('生死カードを選択してください',
          style: TextStyle(fontSize: 12, color: Color(0xFF9A9384)));
    }
    final effect = card.effect;
    final number = card.number;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(CardVisuals.effectIcon(effect),
            size: 16, color: CardVisuals.effectColor(effect)),
        const SizedBox(width: 4),
        Text('${CardVisuals.effectLabel(effect)} $number を選択中',
            style: TextStyle(
                fontSize: 13,
                color: CardVisuals.effectColor(effect),
                fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text(hasTarget ? '→ 対象選択済み' : '→ 対象を選んでください',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9A9384))),
      ],
    );
  }
}
