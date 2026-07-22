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
import '../domain/enums.dart';
import '../domain/game_state.dart';
import '../domain/life_death_card.dart';
import '../domain/person_card.dart';
import 'widgets/game_log_view.dart';

/// ゲーム本編画面（Ver.0.3・中央共有の場）。
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);

    ref.listen<GameState?>(gameControllerProvider, (prev, next) {
      if (next == null) return;
      if (next.phase == GamePhase.finished) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(AppRoutes.result);
        });
      }
    });

    if (state == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.title);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;
            const pad = 8.0;
            const gap = 6.0;
            final screenW = math.min(w, 520.0);
            final contentW = screenW - pad * 2;

            // 手札：5枚×最大2段。
            final lifeW =
                ((contentW - gap * 4) / 5).clamp(40.0, 58.0);
            final handH = 2 * (lifeW * 1.35) + gap;

            // 固定要素見積り。
            const headerH = 56.0;
            const turnH = 26.0;
            const logH = 54.0;
            const selInfoH = 18.0;
            const msgH = 14.0;
            const btnH = 44.0;
            const chromePad = 26.0;
            final fixed = headerH +
                turnH +
                logH +
                selInfoH +
                msgH +
                btnH +
                handH +
                gap * 8 +
                chromePad;

            // 3×3の1盤面（3段）。
            final avail = h - fixed;
            final pByWidth = (contentW - gap * 2) / 3;
            final pByHeight = (avail / 3) / 1.28;
            final personSize =
                math.min(pByWidth, pByHeight).clamp(52.0, 128.0);

            final finished = state.phase == GamePhase.finished;
            final selectable =
                state.phase == GamePhase.playerTurn && !state.isBusy;

            return Center(
              child: SizedBox(
                width: screenW,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(pad, 6, pad, 0),
                        child: Column(
                          children: [
                            _Header(state: state),
                            const SizedBox(height: gap),
                            _TurnIndicator(state: state),
                            const SizedBox(height: gap),
                            _board(state, personSize, gap, selectable, finished),
                            const SizedBox(height: gap),
                            GameLogView(state: state),
                          ],
                        ),
                      ),
                    ),
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

  Widget _board(GameState state, double size, double gap, bool selectable,
      bool finished) {
    // position 順に3×3。
    final persons = [...state.persons]..sort((a, b) => a.position.compareTo(b.position));
    return Center(
      child: SizedBox(
        width: size * 3 + gap * 2,
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          alignment: WrapAlignment.center,
          children: persons.map((p) {
            final revealed = finished || p.knownBy == Knower.player;
            return PersonCardWidget(
              card: p,
              revealed: revealed,
              size: size,
              selected: state.selectedPosition == p.position,
              selectable: selectable && !p.sealed,
              highlight: _highlightFor(state, p),
              onTap: () => ref
                  .read(gameControllerProvider.notifier)
                  .selectPosition(p.position),
            );
          }).toList(),
        ),
      ),
    );
  }

  CardHighlight _highlightFor(GameState state, PersonCard card) {
    final o = state.lastOutcome;
    if (o == null || o.position != card.position) return CardHighlight.none;
    return o.success ? CardHighlight.success : CardHighlight.fail;
  }
}

/// ヘッダー：自分の役割・目的・相手・秘密情報の枚数。
class _Header extends StatelessWidget {
  const _Header({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final myRole = state.player.role;
    final cpuRole = state.cpu.role;
    final myColor = CardVisuals.roleColor(myRole);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: myColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(CardVisuals.roleIcon(myRole), color: myColor, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('あなた：${CardVisuals.roleLabel(myRole)}',
                    style: TextStyle(
                        color: myColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text('目的 ${CardVisuals.roleGoal(myRole)}',
                    style: const TextStyle(
                        color: Color(0xFFB9B2A2), fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('CPU：${CardVisuals.roleLabel(cpuRole)}',
                  style: const TextStyle(
                      color: Color(0xFFB9B2A2), fontSize: 12)),
              Text(
                  '手札 あなた${state.player.usableCards.length} / CPU${state.cpu.usableCards.length}',
                  style: const TextStyle(
                      color: Color(0xFF9A9384), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TurnIndicator extends StatelessWidget {
  const _TurnIndicator({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    switch (state.phase) {
      case GamePhase.playerTurn:
        text = 'あなたのターン（正体を知る3枚は表向き）';
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
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

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
        state.selectedPosition != null;

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
            _SelectedInfo(
                selected: selectedCard,
                hasTarget: state.selectedPosition != null),
            const SizedBox(height: 4),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              alignment: WrapAlignment.center,
              children: state.player.hand.map((card) {
                return LifeDeathCardWidget(
                  card: card,
                  width: lifeWidth,
                  selected: state.selectedLifeDeathCardId == card.id,
                  enabled:
                      state.phase == GamePhase.playerTurn && !state.isBusy,
                  onTap: () => controller.selectLifeDeathCard(card.id),
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
      return const Text('生死カードを選択 → 対象を選択 → 決定',
          style: TextStyle(fontSize: 12, color: Color(0xFF9A9384)));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(CardVisuals.effectIcon(card.effect),
            size: 16, color: CardVisuals.effectColor(card.effect)),
        const SizedBox(width: 4),
        Text('${CardVisuals.effectLabel(card.effect)} ${card.number}',
            style: TextStyle(
                fontSize: 13,
                color: CardVisuals.effectColor(card.effect),
                fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text(hasTarget ? '→ 対象選択済み' : '→ 対象を選択',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9A9384))),
      ],
    );
  }
}
