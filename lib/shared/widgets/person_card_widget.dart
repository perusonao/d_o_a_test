import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/game/domain/enums.dart';
import '../../features/game/domain/person_card.dart';
import '../utils/card_visuals.dart';

/// 対象カードに対する直近結果のハイライト種別。
enum CardHighlight { none, success, fail }

/// 中央共有の場に並ぶ人カード1枚（Ver.0.3）。
///
/// - [revealed] が true のとき正体（種類・数字）を表示する
///   （自分が知る3枚、またはゲーム終了時）。
/// - false のときは正体を伏せ、位置番号と状態だけを示す。
class PersonCardWidget extends StatefulWidget {
  const PersonCardWidget({
    super.key,
    required this.card,
    required this.revealed,
    this.selected = false,
    this.selectable = false,
    this.onTap,
    this.highlight = CardHighlight.none,
    this.size = 96,
  });

  final PersonCard card;
  final bool revealed;
  final bool selected;
  final bool selectable;
  final VoidCallback? onTap;
  final CardHighlight highlight;
  final double size;

  @override
  State<PersonCardWidget> createState() => _PersonCardWidgetState();
}

class _PersonCardWidgetState extends State<PersonCardWidget>
    with TickerProviderStateMixin {
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  late final AnimationController _flash =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    _animate(widget.highlight);
  }

  @override
  void didUpdateWidget(covariant PersonCardWidget old) {
    super.didUpdateWidget(old);
    if (old.highlight != widget.highlight) _animate(widget.highlight);
  }

  void _animate(CardHighlight h) {
    if (h == CardHighlight.success) _flash.forward(from: 0);
    if (h == CardHighlight.fail) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final s = widget.size;
    final typeColor = widget.revealed
        ? CardVisuals.personTypeColor(card.type)
        : AppTheme.accent;

    Widget content = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: s,
          height: s * 1.28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected
                  ? AppTheme.good
                  : typeColor.withValues(alpha: 0.55),
              width: widget.selected ? 3 : 1.5,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.parchmentLight, AppTheme.parchment],
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: s,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.revealed
                        ? CardVisuals.personTypeIcon(card.type)
                        : Icons.help_outline,
                    color: typeColor,
                    size: s * 0.34,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.revealed ? '${card.number}' : '？',
                    style: TextStyle(
                      fontSize: s * 0.32,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEDE6D4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.revealed
                        ? CardVisuals.personTypeLabel(card.type)
                        : '？',
                    style: TextStyle(fontSize: s * 0.15, color: typeColor),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 位置番号バッジ（左上）。
        Positioned(
          top: 2,
          left: 4,
          child: Text(
            '${card.position + 1}',
            style: TextStyle(
              fontSize: s * 0.18,
              fontWeight: FontWeight.bold,
              color: AppTheme.accent.withValues(alpha: 0.85),
            ),
          ),
        ),

        // dead オーバーレイ。
        if (card.isDead)
          Container(
            width: s,
            height: s * 1.28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black.withValues(alpha: 0.6),
            ),
            child: Icon(CardVisuals.statusIcon(PersonStatus.dead),
                color: AppTheme.dead, size: s * 0.5),
          ),

        // 封印バッジ（右上）。
        if (card.sealed)
          Positioned(
            top: 2,
            right: 2,
            child: Icon(Icons.lock, color: AppTheme.keep, size: s * 0.26),
          ),

        // 成功フラッシュ。
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _flash,
            builder: (context, _) {
              if (_flash.isDismissed) return const SizedBox.shrink();
              final v = 1 - _flash.value;
              return Container(
                width: s,
                height: s * 1.28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppTheme.good.withValues(alpha: 0.5 * v),
                ),
              );
            },
          ),
        ),
      ],
    );

    content = AnimatedScale(
      scale: widget.selected ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: content,
    );

    content = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final dx = math.sin(_shake.value * math.pi * 4) * 6 * (1 - _shake.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: content,
    );

    return Semantics(
      button: widget.selectable,
      label: _label(card),
      child: GestureDetector(
        onTap: widget.selectable ? widget.onTap : null,
        child: content,
      ),
    );
  }

  String _label(PersonCard card) {
    final id = widget.revealed
        ? '${CardVisuals.personTypeLabel(card.type)}${card.number}'
        : '正体不明';
    final st = card.isDead ? '死亡' : '生存';
    final se = card.sealed ? '・封印' : '';
    return '位置${card.position + 1} $id $st$se';
  }
}
