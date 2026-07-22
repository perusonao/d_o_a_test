import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/game/domain/enums.dart';
import '../../features/game/domain/person_card.dart';
import '../utils/card_visuals.dart';

/// 対象カードに対する直近結果のハイライト種別。
enum CardHighlight { none, success, fail, guard }

/// 場に並ぶ人カード1枚を描画する Widget。
///
/// - [ownerView] が true の場合、常に種類と数字を表示する（プレイヤー自身の場）。
/// - false の場合は [PersonCard.reveal] に従って表示する（CPU の場）。
class PersonCardWidget extends StatefulWidget {
  const PersonCardWidget({
    super.key,
    required this.card,
    required this.ownerView,
    this.selected = false,
    this.selectable = false,
    this.onTap,
    this.highlight = CardHighlight.none,
    this.size = 96,
  });

  final PersonCard card;
  final bool ownerView;
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
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    _maybeAnimate(widget.highlight);
  }

  @override
  void didUpdateWidget(covariant PersonCardWidget old) {
    super.didUpdateWidget(old);
    if (old.highlight != widget.highlight) {
      _maybeAnimate(widget.highlight);
    }
  }

  void _maybeAnimate(CardHighlight h) {
    switch (h) {
      case CardHighlight.success:
      case CardHighlight.guard:
        _flash.forward(from: 0);
        break;
      case CardHighlight.fail:
        _shake.forward(from: 0);
        break;
      case CardHighlight.none:
        break;
    }
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
    final faceDown = !widget.ownerView && card.reveal == RevealLevel.none;
    final showNumber = widget.ownerView || card.reveal != RevealLevel.none;
    final showType = widget.ownerView || card.reveal == RevealLevel.full;

    Widget content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) {
        // Y軸回転による簡易フリップ。
        final rotate = Tween(begin: math.pi / 2, end: 0.0).animate(anim);
        return AnimatedBuilder(
          animation: rotate,
          child: child,
          builder: (context, ch) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(rotate.value),
            child: ch,
          ),
        );
      },
      child: faceDown
          ? _buildBack(card)
          : _buildFace(card, showType: showType, showNumber: showNumber),
    );

    // 選択時の拡大。
    content = AnimatedScale(
      scale: widget.selected ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: content,
    );

    // 失敗時のシェイク。
    content = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final dx = math.sin(_shake.value * math.pi * 4) *
            6 *
            (1 - _shake.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: content,
    );

    return Semantics(
      button: widget.selectable,
      label: _semanticsLabel(card, faceDown, showType, showNumber),
      child: GestureDetector(
        onTap: widget.selectable ? widget.onTap : null,
        child: content,
      ),
    );
  }

  String _semanticsLabel(
      PersonCard card, bool faceDown, bool showType, bool showNumber) {
    if (faceDown) return '非公開のカード';
    final t = showType ? CardVisuals.personTypeLabel(card.type) : '不明';
    final n = showNumber ? '${card.number}' : '?';
    return '$t $n ${card.isDead ? "死亡" : "生存"}';
  }

  Widget _buildBack(PersonCard card) {
    return Container(
      key: const ValueKey('back'),
      width: widget.size,
      height: widget.size * 1.28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF23202A), Color(0xFF14121A)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.help_outline,
          color: AppTheme.accent.withValues(alpha: 0.7),
          size: widget.size * 0.4,
        ),
      ),
    );
  }

  Widget _buildFace(PersonCard card,
      {required bool showType, required bool showNumber}) {
    final typeColor =
        showType ? CardVisuals.personTypeColor(card.type) : AppTheme.neutral;
    final isDead = card.isDead;

    return Stack(
      key: ValueKey('face_${card.reveal}_${card.status}_${card.isGuarded}'),
      alignment: Alignment.center,
      children: [
        // 本体（石板風）。
        Container(
          width: widget.size,
          height: widget.size * 1.28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected ? AppTheme.good : typeColor.withValues(alpha: 0.6),
              width: widget.selected ? 3 : 1.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [AppTheme.parchmentLight, AppTheme.parchment],
            ),
          ),
          padding: const EdgeInsets.all(3),
          // 小さいサイズでも溢れないよう内容を縮小して収める。
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: widget.size,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 種類アイコン or ？
                  Icon(
                    showType
                        ? CardVisuals.personTypeIcon(card.type)
                        : Icons.help,
                    color: typeColor,
                    size: widget.size * 0.34,
                  ),
                  const SizedBox(height: 2),
                  // 数字
                  Text(
                    showNumber ? '${card.number}' : '？',
                    style: TextStyle(
                      fontSize: widget.size * 0.34,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEDE6D4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 種類ラベル
                  Text(
                    showType ? CardVisuals.personTypeLabel(card.type) : '？',
                    style: TextStyle(
                      fontSize: widget.size * 0.16,
                      color: typeColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // dead オーバーレイ（暗くする＋墓標アイコン）。
        AnimatedOpacity(
          opacity: isDead ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: widget.size,
            height: widget.size * 1.28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black.withValues(alpha: 0.6),
            ),
            child: Icon(
              CardVisuals.statusIcon(PersonStatus.dead),
              color: AppTheme.dead,
              size: widget.size * 0.5,
            ),
          ),
        ),

        // keep 盾バッジ。
        if (card.isGuarded)
          Positioned(
            top: 2,
            right: 2,
            child: Icon(
              Icons.shield,
              color: AppTheme.keep,
              size: widget.size * 0.28,
            ),
          ),

        // 成功フラッシュ。
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _flash,
            builder: (context, _) {
              final v = (1 - _flash.value);
              if (_flash.value == 0 || _flash.isDismissed) {
                return const SizedBox.shrink();
              }
              final color = widget.highlight == CardHighlight.guard
                  ? AppTheme.keep
                  : AppTheme.good;
              return Container(
                width: widget.size,
                height: widget.size * 1.28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: color.withValues(alpha: 0.5 * v),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
