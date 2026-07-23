import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/utils/card_visuals.dart';
import '../../../shared/widgets/action_card_widget.dart';
import '../../../shared/widgets/human_card_widget.dart';
import '../application/game_controller.dart';
import '../domain/action_card.dart';
import '../domain/enums.dart';
import '../domain/game_state.dart';
import '../domain/human_card.dart';

/// ゲーム本編画面（Ver.0.4・ホットシート2人対戦）。
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);

    ref.listen<GameState?>(gameControllerProvider, (prev, next) {
      if (next?.phase == GamePhase.finished) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(AppRoutes.result);
        });
      }
    });

    if (state == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.title);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final peeking = state.phase == GamePhase.peekA || state.phase == GamePhase.peekB;

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

            final lifeW = ((contentW - gap * 4) / 5).clamp(42.0, 60.0);
            final handH = 2 * (lifeW * 1.35) + gap;

            const headerH = 52.0;
            const bottomChrome = 120.0;
            final reservedBottom = peeking ? 96.0 : (handH + bottomChrome);
            final avail = h - headerH - reservedBottom - gap * 4;
            final pByWidth = (contentW - gap * 2) / 3;
            final pByHeight = (avail / 3) / 1.28;
            final size = math.min(pByWidth, pByHeight).clamp(56.0, 132.0);

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
                            _board(ref, state, size, gap),
                          ],
                        ),
                      ),
                    ),
                    peeking
                        ? _PeekBar(state: state)
                        : _HandArea(state: state, lifeWidth: lifeW),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _board(WidgetRef ref, GameState state, double size, double gap) {
    final humans = [...state.humans]
      ..sort((a, b) => a.position.compareTo(b.position));
    final playing = state.phase == GamePhase.playing;
    final interactive = playing && !state.isBusy && !state.currentPlayer.isCpu;
    return Center(
      child: SizedBox(
        width: size * 3 + gap * 2,
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          alignment: WrapAlignment.center,
          children: humans.map((hcard) {
            final canPeek = interactive &&
                state.isKnownBy(state.current, hcard.position) &&
                !hcard.revealed &&
                !state.peeked.contains(hcard.position);
            return HumanCardWidget(
              card: hcard,
              faceUp: _faceUp(state, hcard),
              size: size,
              selected: state.selectedPosition == hcard.position,
              selectable: interactive,
              peekable: canPeek,
              highlight: _highlight(state, hcard),
              onTap: () => ref
                  .read(gameControllerProvider.notifier)
                  .selectPosition(hcard.position),
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _faceUp(GameState state, HumanCard card) {
    switch (state.phase) {
      case GamePhase.finished:
        return true;
      case GamePhase.peekA:
        return card.column == 0; // 左列
      case GamePhase.peekB:
        return card.column == 2; // 右列
      case GamePhase.playing:
        return card.revealed || state.peeked.contains(card.position);
    }
  }

  HumanHighlight _highlight(GameState state, HumanCard card) {
    if (state.phase != GamePhase.playing) return HumanHighlight.none;
    if (state.lastActionPosition != card.position) return HumanHighlight.none;
    if (state.lastProtectAbsorbed) return HumanHighlight.protect;
    switch (state.lastActionType) {
      case ActionType.life:
        return HumanHighlight.life;
      case ActionType.death:
        return HumanHighlight.death;
      case ActionType.protect:
        return HumanHighlight.protect;
      case null:
        return HumanHighlight.none;
    }
  }
}

/// ヘッダー：手番・暫定得点（公開分）・残り手札。
class _Header extends StatelessWidget {
  const _Header({required this.state});
  final GameState state;

  int _provisional(Faction f) {
    var savior = 0, exec = 0;
    for (final h in state.humans) {
      if (!h.revealed) continue;
      final toSavior = switch (h.type) {
        HumanType.good || HumanType.neutral => h.isAlive,
        HumanType.evil => h.isDead,
      };
      if (toSavior) {
        savior += h.points;
      } else {
        exec += h.points;
      }
    }
    return f == Faction.savior ? savior : exec;
  }

  @override
  Widget build(BuildContext context) {
    final playing = state.phase == GamePhase.playing;
    final cur = state.currentPlayer;
    final curColor = CardVisuals.factionColor(cur.faction);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: curColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          if (playing) ...[
            Icon(CardVisuals.factionIcon(cur.faction), color: curColor, size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${cur.id == PlayerId.a ? "プレイヤーA" : "プレイヤーB"}${cur.isCpu ? "(CPU)" : ""}の番'
                      '（${CardVisuals.factionLabel(cur.faction)}）',
                      style: TextStyle(
                          color: curColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Text(
                      '残り 生${cur.countUsable(ActionType.life)} 死${cur.countUsable(ActionType.death)} 保${cur.countUsable(ActionType.protect)}',
                      style: const TextStyle(
                          color: Color(0xFFB9B2A2), fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('暫定(公開分)',
                    style: TextStyle(
                        color: AppTheme.accent.withValues(alpha: 0.8),
                        fontSize: 10)),
                Text(
                    '救${_provisional(Faction.savior)} / 執${_provisional(Faction.executioner)}',
                    style: const TextStyle(
                        color: Color(0xFFCFC7B5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ] else
            const Expanded(
              child: Text('初期情報の確認フェーズ',
                  style: TextStyle(color: Color(0xFFCFC7B5), fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

/// 確認フェーズの下部バー。
class _PeekBar extends ConsumerWidget {
  const _PeekBar({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isA = state.phase == GamePhase.peekA;
    final who = isA ? 'プレイヤーA' : 'プレイヤーB';
    final side = isA ? '左列' : '右列';
    // CPU 対戦では A の確認後すぐ対戦開始（B の確認は無い）。
    final nextIsStart = !isA || state.playerB.isCpu;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Color(0x33B8862F))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$who は${side}3枚（種類と得点）を覚えてください',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFFCFC7B5))),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    ref.read(gameControllerProvider.notifier).confirmPeek(),
                icon: const Icon(Icons.visibility_off),
                label: Text(nextIsStart ? '確認した → ゲーム開始' : '確認した → プレイヤーBへ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 手札・選択情報・決定ボタン。
class _HandArea extends ConsumerWidget {
  const _HandArea({required this.state, required this.lifeWidth});
  final GameState state;
  final double lifeWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final hand = state.currentPlayer.hand;
    ActionCard? selected;
    final selId = state.selectedActionCardId;
    if (selId != null) {
      for (final c in hand) {
        if (c.id == selId) {
          selected = c;
          break;
        }
      }
    }
    final interactive = !state.isBusy && !state.currentPlayer.isCpu;
    final canConfirm = interactive &&
        state.selectedActionCardId != null &&
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
                selected: selected,
                hasTarget: state.selectedPosition != null),
            const SizedBox(height: 4),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              alignment: WrapAlignment.center,
              children: hand.map((card) {
                return ActionCardWidget(
                  card: card,
                  width: lifeWidth,
                  selected: state.selectedActionCardId == card.id,
                  enabled: interactive,
                  onTap: () => controller.selectActionCard(card.id),
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
                label: Text(interactive ? '決定' : 'CPU の番…'),
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
  final ActionCard? selected;
  final bool hasTarget;

  @override
  Widget build(BuildContext context) {
    final card = selected;
    if (card == null) {
      return const Text('カードを選択 → 対象を選択 → 決定',
          style: TextStyle(fontSize: 12, color: Color(0xFF9A9384)));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(CardVisuals.actionIcon(card.type),
            size: 16, color: CardVisuals.actionColor(card.type)),
        const SizedBox(width: 4),
        Text('${CardVisuals.actionLabel(card.type)}カード',
            style: TextStyle(
                fontSize: 13,
                color: CardVisuals.actionColor(card.type),
                fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text(hasTarget ? '→ 対象選択済み' : '→ 対象を選択',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9A9384))),
      ],
    );
  }
}
