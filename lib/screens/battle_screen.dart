import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../game/models.dart';
import '../theme.dart';
import '../widgets/castle.dart';
import 'attack_result_screen.dart';

/// The fight itself, animated: your soldiers and cavalry charge the enemy
/// castle, bombs fly, defenders fall, then the result appears.
class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key, required this.result});

  final AttackResult result;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 6200))
    ..addListener(_haptics)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 900), _finish);
      }
    })
    ..forward();

  final _hits = <double>{};
  bool _done = false;

  late final List<double> _bombTimes = [
    for (var i = 0; i < widget.result.bombsUsed; i++) 0.38 + i * 0.09,
  ];

  void _haptics() {
    final t = _c.value;
    for (final b in [..._bombTimes, 0.62]) {
      if (t >= b + 0.06 && !_hits.contains(b)) {
        _hits.add(b);
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, animation, secondaryAnimation) => AttackResultScreen(result: widget.result),
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1A12),
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // castle shakes on each bomb and at the clash
          var shake = 0.0;
          for (final b in [..._bombTimes, 0.62]) {
            final d = t - (b + 0.06);
            if (d >= 0 && d < 0.06) shake = max(shake, 1 - d / 0.06);
          }
          final damage = r.won ? ((t - 0.66) / 0.2).clamp(0.0, 1.0) : 0.0;
          return LayoutBuilder(builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            final castleSize = min(size.width * 0.62, 260.0);
            final castleTop = size.height * 0.12;
            final target = Offset(size.width / 2, castleTop + castleSize * 0.72);
            return Stack(children: [
              // battlefield backdrop
              Positioned.fill(
                child: Opacity(
                  opacity: 0.35,
                  child: Image.asset('assets/images/map.jpg', fit: BoxFit.cover, alignment: const Alignment(0, 0.4)),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [const Color(0xEE0B0B0B), const Color(0x880B0B0B), Color.lerp(const Color(0xCC0B0B0B), QC.bg, t)!],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: castleTop,
                left: (size.width - castleSize) / 2,
                child: CastleView(
                  seed: r.rivalCastleSeed,
                  accessories: r.rivalAccessories,
                  size: castleSize,
                  shake: shake,
                  damage: damage,
                ),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _BattlePainter(t: t, result: r, target: target, bombTimes: _bombTimes)),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _PowerLabel(name: 'Siz', power: r.myPower, color: QC.lime)),
                      Transform.scale(
                        scale: Curves.elasticOut.transform((t / 0.15).clamp(0.0, 1.0)),
                        child: Text('JANG!', style: display(30, color: QC.text, letterSpacing: 2)),
                      ),
                      Expanded(
                        child: _PowerLabel(name: r.rivalName, power: r.rivalPower, color: r.rivalColor, alignEnd: true),
                      ),
                    ]),
                  ]),
                ),
              ),
              if (t > 0.86)
                Center(
                  child: Transform.scale(
                    scale: Curves.easeOutBack.transform(((t - 0.86) / 0.14).clamp(0.0, 1.0)),
                    child: Transform.rotate(
                      angle: -0.08,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: r.won ? QC.lime : QC.text,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: QC.bg, width: 3),
                          boxShadow: const [BoxShadow(color: QC.bg, offset: Offset(0, 6))],
                        ),
                        child: Text(r.won ? "QAL'A OLINDI!" : 'HUJUM QAYTARILDI',
                            style: display(28, color: QC.bg, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 16,
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
                child: TextButton(
                  onPressed: _finish,
                  child: Text("O'tkazib yuborish", style: body(14, color: QC.textSoft)),
                ),
              ),
            ]);
          });
        },
      ),
    );
  }
}

class _PowerLabel extends StatelessWidget {
  const _PowerLabel({required this.name, required this.power, required this.color, this.alignEnd = false});

  final String name;
  final double power;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(name, style: body(13, color: QC.textSoft), overflow: TextOverflow.ellipsis),
          Text('${power.round()} kuch', style: display(20, color: color)),
        ],
      );
}

class _BattlePainter extends CustomPainter {
  _BattlePainter({required this.t, required this.result, required this.target, required this.bombTimes});

  final double t;
  final AttackResult result;
  final Offset target;
  final List<double> bombTimes;

  static const _ink = Color(0xFF111111);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7);
    final r = result;
    final infShown = min(36, max(r.myInfantry > 0 ? 6 : 0, (r.myInfantry / 3).round()));
    final cavShown = min(10, max(r.myCavalry > 0 ? 2 : 0, (r.myCavalry / 2).round()));
    final defShown = min(24, max(r.enemyInfantry + r.enemyCavalry > 0 ? 4 : 0, ((r.enemyInfantry + r.enemyCavalry) / 4).round()));
    final myLossShare = (r.myInfantry + r.myCavalry) == 0 ? 0.0 : r.myLosses / (r.myInfantry + r.myCavalry);
    final enLossShare = (r.enemyInfantry + r.enemyCavalry) == 0 ? 0.0 : r.enemyLosses / (r.enemyInfantry + r.enemyCavalry);
    final clashY = target.dy + 36;
    final falling = ((t - 0.6) / 0.2).clamp(0.0, 1.0);

    // defenders in front of the gate
    for (var i = 0; i < defShown; i++) {
      final x = target.dx + (i - defShown / 2) * 13 + rnd.nextDouble() * 6;
      final y = clashY - 6 + rnd.nextDouble() * 18;
      final dies = i / max(1, defShown) < enLossShare;
      final alpha = dies ? 1 - falling : 1.0;
      if (alpha <= 0) continue;
      _soldier(canvas, Offset(x, y), r.rivalColor, alpha, facingUp: false, step: t * 20 + i);
    }

    // my infantry marching up
    for (var i = 0; i < infShown; i++) {
      final col = i % 9, row = i ~/ 9;
      final start = Offset(size.width * (0.1 + col * 0.1) + rnd.nextDouble() * 8, size.height + 30 + row * 26);
      final end = Offset(target.dx + (col - 4) * 14 + rnd.nextDouble() * 6, clashY + 24 + row * 10);
      final p = Curves.easeInOut.transform(((t - 0.08 - row * 0.03) / 0.5).clamp(0.0, 1.0));
      final pos = Offset.lerp(start, end, p)!;
      final dies = i / max(1, infShown) < myLossShare;
      final alpha = dies ? 1 - falling : 1.0;
      if (alpha <= 0) continue;
      _soldier(canvas, pos, QC.lime, alpha, facingUp: true, step: t * 30 + i);
    }

    // cavalry: fewer, faster
    for (var i = 0; i < cavShown; i++) {
      final start = Offset(size.width * (0.15 + i * 0.08), size.height + 60);
      final end = Offset(target.dx + (i - cavShown / 2) * 22, clashY + 10);
      final p = Curves.easeIn.transform(((t - 0.14) / 0.34).clamp(0.0, 1.0));
      final pos = Offset.lerp(start, end, p)!;
      final dies = i / max(1, cavShown) < myLossShare;
      final alpha = dies ? 1 - falling : 1.0;
      if (alpha <= 0) continue;
      _rider(canvas, pos, alpha, t * 40 + i);
    }

    // dust at the clash
    if (t > 0.5 && t < 0.9) {
      final k = ((t - 0.5) / 0.4);
      for (var i = 0; i < 14; i++) {
        final a = i / 14 * 2 * pi;
        final rad = 20 + k * 60 + rnd.nextDouble() * 20;
        canvas.drawCircle(
          Offset(target.dx + cos(a) * rad, clashY + 20 + sin(a) * rad * 0.35),
          8 + k * 10,
          Paint()..color = Color.fromRGBO(210, 190, 150, 0.25 * (1 - k)),
        );
      }
    }

    // bombs: arc from below, explode on the walls
    for (var i = 0; i < bombTimes.length; i++) {
      final b = bombTimes[i];
      final fly = ((t - b) / 0.06).clamp(0.0, 1.0);
      final boom = ((t - b - 0.06) / 0.08).clamp(0.0, 1.0);
      final hit = target.translate((i - 1) * 28.0, -30);
      if (t >= b && fly < 1) {
        final start = Offset(size.width * (0.3 + i * 0.2), size.height);
        final mid = Offset((start.dx + hit.dx) / 2, min(start.dy, hit.dy) - 140);
        final p = _bezier(start, mid, hit, fly);
        canvas.drawCircle(p, 7, Paint()..color = _ink);
        canvas.drawCircle(p.translate(-2, -2), 2, Paint()..color = Colors.white54);
        canvas.drawCircle(p.translate(5, -6), 3, Paint()..color = const Color(0xFFFFB13D));
      }
      if (boom > 0 && boom < 1) {
        canvas.drawCircle(hit, 18 + boom * 50, Paint()..color = Color.fromRGBO(255, 210, 61, 0.7 * (1 - boom)));
        canvas.drawCircle(hit, 10 + boom * 30, Paint()..color = Color.fromRGBO(255, 120, 40, 0.9 * (1 - boom)));
        canvas.drawCircle(hit, 6 + boom * 12, Paint()..color = Color.fromRGBO(255, 255, 255, 1 - boom));
      }
    }

    // white flash at the clash
    final flash = 1 - ((t - 0.62).abs() / 0.03).clamp(0.0, 1.0);
    if (flash > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Color.fromRGBO(255, 255, 255, 0.35 * flash));
    }
  }

  Offset _bezier(Offset a, Offset b, Offset c, double t) =>
      a * ((1 - t) * (1 - t)) + b * (2 * (1 - t) * t) + c * (t * t);

  void _soldier(Canvas c, Offset p, Color color, double alpha, {required bool facingUp, required double step}) {
    final ink = Paint()
      ..color = _ink.withValues(alpha: alpha)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final bob = sin(step) * 1.5;
    final body = Rect.fromCenter(center: p.translate(0, bob), width: 8, height: 11);
    c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(3)), Paint()..color = color.withValues(alpha: alpha));
    c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(3)), ink);
    c.drawCircle(p.translate(0, -9 + bob), 3.6, Paint()..color = const Color(0xFFF1D3B3).withValues(alpha: alpha));
    c.drawCircle(p.translate(0, -9 + bob), 3.6, ink);
    // spear
    final dir = facingUp ? -1.0 : 1.0;
    c.drawLine(p.translate(6, 4 + bob), p.translate(6, (facingUp ? -16 : 12) + bob), ink);
    c.drawCircle(p.translate(6, (facingUp ? -17 : 13) + bob), 1.8, Paint()..color = Colors.white70.withValues(alpha: alpha));
    // legs
    final leg = sin(step * 1.3) * 3 * dir;
    c.drawLine(p.translate(-2, 5 + bob), p.translate(-2 + leg, 10 + bob), ink);
    c.drawLine(p.translate(2, 5 + bob), p.translate(2 - leg, 10 + bob), ink);
  }

  void _rider(Canvas c, Offset p, double alpha, double step) {
    final ink = Paint()
      ..color = _ink.withValues(alpha: alpha)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final gallop = sin(step) * 2;
    final horse = Rect.fromCenter(center: p.translate(0, gallop), width: 20, height: 10);
    c.drawRRect(RRect.fromRectAndRadius(horse, const Radius.circular(5)), Paint()..color = const Color(0xFF8A5A35).withValues(alpha: alpha));
    c.drawRRect(RRect.fromRectAndRadius(horse, const Radius.circular(5)), ink);
    // head
    c.drawOval(Rect.fromCenter(center: p.translate(0, -8 + gallop), width: 7, height: 9),
        Paint()..color = const Color(0xFF8A5A35).withValues(alpha: alpha));
    // legs
    for (final dx in [-7.0, -3.0, 3.0, 7.0]) {
      final s = sin(step + dx) * 3;
      c.drawLine(p.translate(dx, 4 + gallop), p.translate(dx + s, 11 + gallop), ink);
    }
    // rider
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: p.translate(0, -3 + gallop), width: 8, height: 9), const Radius.circular(3)),
        Paint()..color = QC.lime.withValues(alpha: alpha));
    c.drawCircle(p.translate(0, -10 + gallop), 3.2, Paint()..color = const Color(0xFFF1D3B3).withValues(alpha: alpha));
    c.drawLine(p.translate(-6, -2 + gallop), p.translate(-6, -20 + gallop), ink);
    final flag = Path()
      ..moveTo(p.dx - 6, p.dy - 20 + gallop)
      ..lineTo(p.dx + 2, p.dy - 17 + gallop + sin(step) * 1.5)
      ..lineTo(p.dx - 6, p.dy - 14 + gallop)
      ..close();
    c.drawPath(flag, Paint()..color = QC.lime.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(covariant _BattlePainter old) => old.t != t;
}
