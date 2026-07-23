import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/game/domain/human_card.dart';
import '../utils/card_visuals.dart';

/// 直近アクションのハイライト種別。
enum HumanHighlight { none, life, death, protect }

/// 中央3×3に並ぶ人間カード1枚（Ver.0.4）。
///
/// [faceUp] が true のとき正体（種類・得点・生死）を表示する。
class HumanCardWidget extends StatefulWidget {
  const HumanCardWidget({
    super.key,
    required this.card,
    required this.faceUp,
    this.selected = false,
    this.selectable = false,
    this.onTap,
    this.highlight = HumanHighlight.none,
    this.size = 96,
  });

  final HumanCard card;
  final bool faceUp;
  final bool selected;
  final bool selectable;
  final VoidCallback? onTap;
  final HumanHighlight highlight;
  final double size;

  @override
  State<HumanCardWidget> createState() => _HumanCardWidgetState();
}

class _HumanCardWidgetState extends State<HumanCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    if (widget.highlight != HumanHighlight.none) _flash.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant HumanCardWidget old) {
    super.didUpdateWidget(old);
    if (old.highlight != widget.highlight &&
        widget.highlight != HumanHighlight.none) {
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  Color get _flashColor {
    switch (widget.highlight) {
      case HumanHighlight.life:
        return AppTheme.alive;
      case HumanHighlight.death:
        return AppTheme.evil;
      case HumanHighlight.protect:
        return AppTheme.keep;
      case HumanHighlight.none:
        return AppTheme.good;
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final s = widget.size;
    final typeColor = widget.faceUp
        ? CardVisuals.humanTypeColor(card.type)
        : AppTheme.accent;

    Widget face = widget.faceUp ? _buildFace(card, s, typeColor) : _buildBack(s);

    Widget content = Stack(
      alignment: Alignment.center,
      children: [
        face,
        // 位置番号バッジ。
        Positioned(
          top: 2,
          left: 4,
          child: Text('${card.position + 1}',
              style: TextStyle(
                  fontSize: s * 0.17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent.withValues(alpha: 0.85))),
        ),
        // 保護バッジ。
        if (card.protected)
          Positioned(
            top: 2,
            right: 2,
            child: Icon(Icons.shield, color: AppTheme.keep, size: s * 0.26),
          ),
        // フラッシュ。
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
                  color: _flashColor.withValues(alpha: 0.5 * v),
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

    return Semantics(
      button: widget.selectable,
      label: _label(card),
      child: GestureDetector(
        onTap: widget.selectable ? widget.onTap : null,
        child: content,
      ),
    );
  }

  Widget _buildBack(double s) {
    return Container(
      width: s,
      height: s * 1.28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.selected
              ? AppTheme.good
              : AppTheme.accent.withValues(alpha: 0.5),
          width: widget.selected ? 3 : 1.5,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF23202A), Color(0xFF14121A)],
        ),
      ),
      child: Center(
        child: Icon(Icons.help_outline,
            color: AppTheme.accent.withValues(alpha: 0.7), size: s * 0.4),
      ),
    );
  }

  Widget _buildFace(HumanCard card, double s, Color typeColor) {
    return Stack(
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
                  Icon(CardVisuals.humanTypeIcon(card.type),
                      color: typeColor, size: s * 0.34),
                  const SizedBox(height: 2),
                  Text('${card.points}',
                      style: TextStyle(
                          fontSize: s * 0.32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEDE6D4))),
                  const SizedBox(height: 2),
                  Text(CardVisuals.humanTypeLabel(card.type),
                      style: TextStyle(fontSize: s * 0.15, color: typeColor)),
                ],
              ),
            ),
          ),
        ),
        if (card.isDead)
          Container(
            width: s,
            height: s * 1.28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black.withValues(alpha: 0.6),
            ),
            child: Icon(Icons.heart_broken,
                color: AppTheme.dead, size: s * 0.5),
          ),
      ],
    );
  }

  String _label(HumanCard card) {
    final id = widget.faceUp
        ? '${CardVisuals.humanTypeLabel(card.type)}${card.points}点'
        : '正体不明';
    final st = card.isDead ? '死' : '生';
    final pr = card.protected ? '・保護' : '';
    return '位置${card.position + 1} $id $st$pr';
  }
}
