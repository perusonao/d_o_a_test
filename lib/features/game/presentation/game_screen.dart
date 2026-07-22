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
            // 人カードは3列。画面幅からサイズを算出（320px でも収まるよう）。
            const outerPad = 8.0;
            const gap = 6.0;
            final maxW = constraints.maxWidth.clamp(280.0, 560.0);
            final personSize =
                ((maxW - outerPad * 2 - gap * 2) / 3).clamp(64.0, 120.0);

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: outerPad, vertical: 6),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          children: [
                            _CpuInfoBar(cpu: state.cpu),
                            const SizedBox(height: 6),
                            _personGrid(
                              cards: state.cpu.persons,
                              ownerView: false,
                              state: state,
                              size: personSize,
                              gap: gap,
                              selectable: state.phase == GamePhase.playerTurn &&
                                  !state.isBusy,
                            ),
                            const SizedBox(height: 8),
                            _TurnIndicator(state: state),
                            const SizedBox(height: 6),
                            GameLogView(state: state),
                            const SizedBox(height: 10),
                            const _SectionLabel(
                                icon: Icons.person, text: 'あなたの場'),
                            const SizedBox(height: 4),
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
                      ),
                    ),
                  ),
                ),
                _HandArea(state: state),
              ],
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
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      alignment: WrapAlignment.center,
      children: cards.map((c) {
        final selected =
            !ownerView && state.selectedPersonId == c.id;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isGood ? Icons.balance : Icons.local_fire_department,
              color: AppTheme.factionColor(isGood), size: 20),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.accent),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFB9B2A2),
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// 画面下部：選択中カード情報＋手札＋決定ボタン。
class _HandArea extends ConsumerWidget {
  const _HandArea({required this.state});
  final GameState state;

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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // メッセージ（無効操作の理由など）。
            if (state.message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 15, color: AppTheme.evil),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(state.message!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.evil)),
                    ),
                  ],
                ),
              ),
            // 選択中の生死カード情報。
            _SelectedInfo(
              selected: selectedCard,
              hasTarget: state.selectedPersonId != null,
            ),
            const SizedBox(height: 6),
            // 手札（横スクロールせず折り返し）。
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 210),
              child: SingleChildScrollView(
                child: Center(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: state.player.hand.map((c) {
                      return LifeDeathCardWidget(
                        card: c,
                        width: 62,
                        selected: state.selectedLifeDeathCardId == c.id,
                        enabled: state.phase == GamePhase.playerTurn &&
                            !state.isBusy,
                        onTap: () => controller.selectLifeDeathCard(c.id),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canConfirm ? () => controller.confirm() : null,
                icon: const Icon(Icons.check),
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
