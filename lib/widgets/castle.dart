import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// Every player's castle looks different: the [seed] picks the roof colour,
/// stone, number and height of towers and the banner emblem. Trophies won in
/// battle ([accessories]) are added on top: gold roofs, a cannon, torches…
class CastleLook {
  CastleLook(this.seed, this.accessories) : _r = Random(seed) {
    // Draw from the random generator in a fixed order so a seed always gives the same castle.
    _baseRoof;
    stone;
    towers;
    keepHeight;
    emblem;
    banner;
  }

  final int seed;
  final List<String> accessories;
  final Random _r;

  static const _roofs = [
    Color(0xFFC8F05A), Color(0xFF6E94E0), Color(0xFFF28C3A), Color(0xFFE0566E),
    Color(0xFF9B6EE0), Color(0xFF3EB8A6), Color(0xFFE0C04A), Color(0xFF5A8FD8),
  ];
  static const _stones = [
    [Color(0xFFEDE7DA), Color(0xFFD5CCB8)],
    [Color(0xFFD9D4CC), Color(0xFFBDB6AA)],
    [Color(0xFFE8D9C0), Color(0xFFCDB894)],
    [Color(0xFFCFD6DB), Color(0xFFAAB4BC)],
  ];

  late final Color _baseRoof = _roofs[_r.nextInt(_roofs.length)];
  late final Color roof = has('gold_roof') ? const Color(0xFFF2C94C) : _baseRoof;
  late final List<Color> stone = _stones[_r.nextInt(_stones.length)];
  late final int towers = 2 + _r.nextInt(3); // 2..4 side towers
  late final double keepHeight = 0.42 + _r.nextDouble() * 0.12;
  late final int emblem = _r.nextInt(4);
  late final Color banner = _roofs[(_roofs.indexOf(_baseRoof) + 3) % _roofs.length];

  bool has(String a) => accessories.contains(a);
}

const accessoryNames = {
  'gold_roof': 'Oltin tom',
  'banner_tall': 'Baland bayroq',
  'cannon': "To'p",
  'torches': "Mash'alalar",
  'crystal_spire': 'Billur minora',
  'dragon_flag': 'Ajdar bayroq',
  'moat': 'Xandaq',
  'shield_wall': 'Qalqon devor',
};

class CastleView extends StatefulWidget {
  const CastleView({
    super.key,
    required this.seed,
    this.accessories = const [],
    this.size = 200,
    this.shake = 0,
    this.damage = 0,
  });

  final int seed;
  final List<String> accessories;
  final double size;

  /// 0..1 — how hard the castle shakes (used in battles).
  final double shake;

  /// 0..1 — cracks and smoke after a lost battle.
  final double damage;

  @override
  State<CastleView> createState() => _CastleViewState();
}

class _CastleViewState extends State<CastleView> with SingleTickerProviderStateMixin {
  late final AnimationController _wave =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = CastleLook(widget.seed, widget.accessories);
    return Semantics(
      label: "Qal'a",
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _wave,
          builder: (context, child) => CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _CastlePainter(look, _wave.value, widget.shake, widget.damage),
          ),
        ),
      ),
    );
  }
}

class _CastlePainter extends CustomPainter {
  _CastlePainter(this.look, this.t, this.shake, this.damage);

  final CastleLook look;
  final double t;
  final double shake;
  final double damage;

  static const _ink = Color(0xFF1A1A1A);

  Paint _fill(Color c) => Paint()..color = c;
  Paint get _stroke => Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (shake > 0) {
      final dx = sin(t * 2 * pi * 9) * 4 * shake;
      canvas.translate(dx, 0);
    }
    final ground = h * 0.86;

    // shadow + moat
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, ground + h * 0.03), width: w * 0.92, height: h * 0.1),
        _fill(const Color(0x55000000)));
    if (look.has('moat')) {
      final moat = Rect.fromCenter(center: Offset(w / 2, ground + h * 0.03), width: w * 0.98, height: h * 0.13);
      canvas.drawOval(moat, _fill(const Color(0xFF4FB3E8)));
      canvas.drawOval(moat.deflate(4), _fill(const Color(0xFF6CC6F0)));
      canvas.drawOval(moat, _stroke);
    }

    // side towers, outer first
    final n = look.towers;
    final towerW = w * 0.16;
    final span = w * 0.78;
    for (var i = 0; i < n; i++) {
      final cx = w / 2 - span / 2 + towerW / 2 + i * (span - towerW) / (n - 1);
      if ((cx - w / 2).abs() < w * 0.08) continue; // the keep sits in the middle
      final th = h * (0.36 + 0.06 * ((i * 7 + look.seed) % 3));
      _tower(canvas, cx, ground, towerW, th, look.roof);
    }

    // curtain wall
    final wallTop = ground - h * 0.26;
    final wall = Rect.fromLTRB(w * 0.18, wallTop, w * 0.82, ground);
    canvas.drawRect(wall, _fill(look.stone[0]));
    _bricks(canvas, wall);
    _crenels(canvas, wall.left, wall.right, wallTop, w * 0.05);
    canvas.drawRect(wall, _stroke);
    if (look.has('shield_wall')) {
      for (var i = 0; i < 4; i++) {
        final c = Offset(wall.left + wall.width * (0.12 + i * 0.25), wallTop + wall.height * 0.42);
        final shield = Path()
          ..moveTo(c.dx - 7, c.dy - 7)
          ..lineTo(c.dx + 7, c.dy - 7)
          ..lineTo(c.dx + 7, c.dy + 2)
          ..quadraticBezierTo(c.dx, c.dy + 10, c.dx - 7, c.dy + 2)
          ..close();
        canvas.drawPath(shield, _fill(i.isEven ? look.roof : look.banner));
        canvas.drawPath(shield, _stroke..strokeWidth = 1.5);
      }
    }

    // keep (central tower)
    final keepW = w * 0.24;
    final keepH = h * look.keepHeight;
    _tower(canvas, w / 2, ground - h * 0.06, keepW, keepH, look.roof, keep: true);

    // gate
    final gate = Path()
      ..moveTo(w / 2 - w * 0.06, ground)
      ..lineTo(w / 2 - w * 0.06, ground - h * 0.1)
      ..arcToPoint(Offset(w / 2 + w * 0.06, ground - h * 0.1), radius: Radius.circular(w * 0.06))
      ..lineTo(w / 2 + w * 0.06, ground)
      ..close();
    canvas.drawPath(gate, _fill(const Color(0xFF6B4527)));
    canvas.drawPath(gate, _stroke);

    // torches
    if (look.has('torches')) {
      for (final x in [w / 2 - w * 0.1, w / 2 + w * 0.1]) {
        final flick = 0.7 + 0.3 * sin(t * 2 * pi * 3 + x);
        canvas.drawCircle(Offset(x, ground - h * 0.13), w * 0.035 * flick, _fill(const Color(0x66FFB13D)));
        canvas.drawCircle(Offset(x, ground - h * 0.13), w * 0.016 * flick, _fill(const Color(0xFFFFD23D)));
        canvas.drawLine(Offset(x, ground - h * 0.12), Offset(x, ground - h * 0.07), _stroke);
      }
    }

    // cannon
    if (look.has('cannon')) {
      final base = Offset(w * 0.78, ground - h * 0.01);
      canvas.drawCircle(base.translate(-6, -4), 6, _fill(const Color(0xFF6B4527)));
      canvas.drawCircle(base.translate(6, -4), 6, _fill(const Color(0xFF6B4527)));
      final barrel = RRect.fromRectAndRadius(Rect.fromLTWH(base.dx - 14, base.dy - 16, 28, 9), const Radius.circular(4));
      canvas.save();
      canvas.translate(base.dx, base.dy - 12);
      canvas.rotate(-0.35);
      canvas.translate(-base.dx, -(base.dy - 12));
      canvas.drawRRect(barrel, _fill(const Color(0xFF3A3A38)));
      canvas.drawRRect(barrel, _stroke);
      canvas.restore();
    }

    // damage: cracks + smoke
    if (damage > 0) {
      final crack = Paint()
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      final p = Path()
        ..moveTo(w * 0.3, wallTop + 6)
        ..lineTo(w * 0.34, wallTop + 18)
        ..lineTo(w * 0.31, wallTop + 30)
        ..moveTo(w * 0.66, wallTop + 8)
        ..lineTo(w * 0.62, wallTop + 22);
      canvas.drawPath(p, crack);
      for (var i = 0; i < 3; i++) {
        final rise = (t + i / 3) % 1;
        canvas.drawCircle(
          Offset(w * (0.38 + i * 0.12), wallTop - rise * h * 0.3),
          w * (0.04 + rise * 0.05),
          _fill(Color.fromRGBO(60, 60, 60, 0.5 * damage * (1 - rise))),
        );
      }
    }
  }

  void _tower(Canvas c, double cx, double ground, double tw, double th, Color roof, {bool keep = false}) {
    final body = Rect.fromLTRB(cx - tw / 2, ground - th, cx + tw / 2, ground);
    c.drawRect(body, _fill(keep ? look.stone[0] : look.stone[1]));
    _bricks(c, body);
    c.drawRect(body, _stroke);
    // window
    final win = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, ground - th * 0.62), width: tw * 0.26, height: tw * 0.4), Radius.circular(tw));
    c.drawRRect(win, _fill(_ink));
    // roof
    final roofH = tw * (keep ? 1.05 : 0.9);
    final roofPath = Path()
      ..moveTo(cx - tw * 0.62, ground - th)
      ..lineTo(cx, ground - th - roofH)
      ..lineTo(cx + tw * 0.62, ground - th)
      ..close();
    c.drawPath(roofPath, _fill(roof));
    c.drawPath(
        Path()
          ..moveTo(cx, ground - th - roofH)
          ..lineTo(cx + tw * 0.62, ground - th)
          ..lineTo(cx, ground - th)
          ..close(),
        _fill(Color.lerp(roof, Colors.black, 0.18)!));
    c.drawPath(roofPath, _stroke);
    if (keep && look.has('crystal_spire')) {
      final top = Offset(cx, ground - th - roofH);
      final spire = Path()
        ..moveTo(top.dx, top.dy - tw * 0.55)
        ..lineTo(top.dx + tw * 0.12, top.dy)
        ..lineTo(top.dx - tw * 0.12, top.dy)
        ..close();
      c.drawPath(spire, _fill(const Color(0xFF8FF0FF)));
      c.drawPath(spire, _stroke..strokeWidth = 1.5);
    }
    if (keep) _flag(c, Offset(cx, ground - th - roofH - (look.has('crystal_spire') ? tw * 0.55 : 0)), tw);
  }

  void _flag(Canvas c, Offset top, double tw) {
    final pole = look.has('banner_tall') ? tw * 1.1 : tw * 0.6;
    c.drawLine(top, top.translate(0, -pole), _stroke..strokeWidth = 2.2);
    final wave = sin(t * 2 * pi) * tw * 0.06;
    final fw = tw * (look.has('banner_tall') ? 0.9 : 0.6);
    final fh = fw * 0.55;
    final o = top.translate(0, -pole);
    final flag = Path()
      ..moveTo(o.dx, o.dy)
      ..quadraticBezierTo(o.dx + fw * 0.5, o.dy - wave, o.dx + fw, o.dy + wave)
      ..lineTo(o.dx + fw, o.dy + fh + wave)
      ..quadraticBezierTo(o.dx + fw * 0.5, o.dy + fh - wave, o.dx, o.dy + fh)
      ..close();
    final color = look.has('dragon_flag') ? const Color(0xFFB0263A) : look.banner;
    c.drawPath(flag, _fill(color));
    c.drawPath(flag, _stroke..strokeWidth = 1.5);
    // emblem
    final e = Offset(o.dx + fw * 0.5, o.dy + fh * 0.5);
    final ep = _fill(look.has('dragon_flag') ? const Color(0xFFF2C94C) : Colors.white);
    final r = fh * 0.24;
    switch (look.has('dragon_flag') ? 9 : look.emblem) {
      case 0:
        c.drawCircle(e, r, ep);
      case 1:
        c.drawPath(
            Path()
              ..moveTo(e.dx, e.dy - r)
              ..lineTo(e.dx + r, e.dy)
              ..lineTo(e.dx, e.dy + r)
              ..lineTo(e.dx - r, e.dy)
              ..close(),
            ep);
      case 2:
        c.drawRect(Rect.fromCenter(center: e, width: r * 1.6, height: r * 1.6), ep);
      case 3:
        c.drawPath(
            Path()
              ..moveTo(e.dx, e.dy - r)
              ..lineTo(e.dx + r, e.dy + r)
              ..lineTo(e.dx - r, e.dy + r)
              ..close(),
            ep);
      default: // dragon: a little zig-zag
        c.drawPath(
            Path()
              ..moveTo(e.dx - r, e.dy + r * 0.6)
              ..lineTo(e.dx - r * 0.3, e.dy - r * 0.6)
              ..lineTo(e.dx + r * 0.2, e.dy + r * 0.3)
              ..lineTo(e.dx + r, e.dy - r * 0.8),
            Paint()
              ..color = ep.color
              ..strokeWidth = 2
              ..style = PaintingStyle.stroke);
    }
  }

  void _bricks(Canvas c, Rect r) {
    final p = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    for (var y = r.top + 8; y < r.bottom - 2; y += 8) {
      c.drawLine(Offset(r.left + 2, y), Offset(r.right - 2, y), p);
    }
  }

  void _crenels(Canvas c, double left, double right, double top, double size) {
    for (var x = left; x < right - 1; x += size * 2) {
      final r = Rect.fromLTWH(x, top - size * 0.8, size, size * 0.8);
      c.drawRect(r, _fill(look.stone[0]));
      c.drawRect(r, _stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _CastlePainter old) =>
      old.t != t || old.shake != shake || old.damage != damage || old.look.seed != look.seed;
}
