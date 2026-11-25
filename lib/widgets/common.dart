import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Half-transparent card with a hairline border (the "glass" cards of the design).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = QC.glass,
    this.borderColor = QC.glassBorder,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor),
        ),
        child: child,
      );
}

/// Big pill button: label on the left, round arrow badge on the right.
class LimeButton extends StatelessWidget {
  const LimeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.background = QC.lime,
    this.foreground = QC.bg,
    this.height = 60,
    this.glow = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color background;
  final Color foreground;
  final double height;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: glow && enabled
              ? const [BoxShadow(color: Color(0x59D4FF3F), blurRadius: 40)]
              : null,
        ),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          style: body(17, color: foreground, weight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      width: height - 16,
                      height: height - 16,
                      decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
                      child: Icon(icon, color: background, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OutlinePill extends StatelessWidget {
  const OutlinePill({super.key, required this.label, required this.onPressed, this.icon, this.color = QC.text});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18, color: color),
        label: Text(label, style: body(15, color: color, weight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: color == QC.text ? QC.outline : color),
          shape: const StadiumBorder(),
        ),
      );
}

class Chip2 extends StatelessWidget {
  const Chip2(this.text, {super.key, this.background = QC.glass, this.foreground = QC.textSoft, this.dot, this.trailingIcon});

  final String text;
  final Color background;
  final Color foreground;
  final Color? dot;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: QC.glassBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(text, style: body(12.5, color: foreground, weight: FontWeight.w500)),
          if (trailingIcon != null) ...[
            const SizedBox(width: 4),
            Icon(trailingIcon, size: 16, color: foreground),
          ],
        ]),
      );
}

/// Handwritten accent, slightly tilted.
class HandNote extends StatelessWidget {
  const HandNote(this.text, {super.key, this.size = 26, this.color = QC.lime, this.angle = -0.12});

  final String text;
  final double size;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        child: Text(text, textAlign: TextAlign.center, style: hand(size, color: color)),
      );
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, required this.color, this.size = 44, this.ring});

  final String name;
  final Color color;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final fg = color.computeLuminance() > 0.5 ? QC.bg : QC.text;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: ring == null
            ? null
            : [
                const BoxShadow(color: QC.bg, spreadRadius: 3),
                BoxShadow(color: ring!, spreadRadius: 6),
              ],
      ),
      alignment: Alignment.center,
      child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: display(size * 0.4, color: fg)),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onPressed, required this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: QC.text, size: 22),
        style: IconButton.styleFrom(
          fixedSize: const Size(48, 48),
          backgroundColor: QC.glass,
          side: const BorderSide(color: QC.glassBorder),
        ),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: display(17))),
        if (trailing != null) Text(trailing!, style: body(13, color: QC.muted)),
      ]);
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.valueColor = QC.text});

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: body(12, color: QC.muted)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: display(20, color: valueColor))),
        ]),
      );
}

/// Pointy-top hexagon clip (castle emblems, rank badges).
class HexClipper extends CustomClipper<Path> {
  const HexClipper({this.pointy = true});

  final bool pointy;

  @override
  Path getClip(Size s) => pointy
      ? (Path()
        ..moveTo(s.width / 2, 0)
        ..lineTo(s.width, s.height * 0.25)
        ..lineTo(s.width, s.height * 0.75)
        ..lineTo(s.width / 2, s.height)
        ..lineTo(0, s.height * 0.75)
        ..lineTo(0, s.height * 0.25)
        ..close())
      : (Path()
        ..moveTo(s.width / 2, 0)
        ..lineTo(s.width, s.height * 0.18)
        ..lineTo(s.width, s.height * 0.62)
        ..lineTo(s.width / 2, s.height)
        ..lineTo(0, s.height * 0.62)
        ..lineTo(0, s.height * 0.18)
        ..close());

  @override
  bool shouldReclip(covariant HexClipper old) => old.pointy != pointy;
}

/// Hexagon with a darker "side" underneath, so it reads as a 3D block.
class HexBlock extends StatelessWidget {
  const HexBlock({
    super.key,
    required this.width,
    required this.top,
    required this.side,
    this.depth = 10,
    this.child,
    this.gradient,
  });

  final double width;
  final Color top;
  final Color side;
  final double depth;
  final Widget? child;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.15;
    return SizedBox(
      width: width,
      height: h + depth,
      child: Stack(children: [
        Positioned(
          top: depth,
          child: ClipPath(clipper: const HexClipper(), child: Container(width: width, height: h, color: side)),
        ),
        ClipPath(
          clipper: const HexClipper(),
          child: Container(
            width: width,
            height: h,
            decoration: BoxDecoration(color: gradient == null ? top : null, gradient: gradient),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ]),
    );
  }
}

/// Day-goal ring on the home screen.
class RingPainter extends CustomPainter {
  RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    final bg = Paint()
      ..color = QC.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    final fg = Paint()
      ..color = QC.lime
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;
    canvas.drawCircle(c, r, bg);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * progress.clamp(0, 1), false, fg);
  }

  @override
  bool shouldRepaint(covariant RingPainter old) => old.progress != progress;
}

/// Thin topographic lines behind dark screens.
class ContourBackground extends StatelessWidget {
  const ContourBackground({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: _ContourPainter(), size: Size.infinite));
}

class _ContourPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF1C1C1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final y in [0.05, 0.11, 0.18, 0.56, 0.63, 0.83, 0.9]) {
      final yy = size.height * y;
      final path = Path()..moveTo(-10, yy);
      path.cubicTo(size.width * 0.2, yy - 40, size.width * 0.38, yy + 50, size.width * 0.62, yy);
      path.cubicTo(size.width * 0.8, yy - 35, size.width * 0.95, yy - 10, size.width + 10, yy + 5);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pulsing target ring placed on the attacked castle.
class PulseRing extends StatefulWidget {
  const PulseRing({super.key, this.width = 92, this.height = 46, this.color = QC.lime});

  final double width;
  final double height;
  final Color color;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Stack(
            clipBehavior: Clip.none,
            children: [0.0, 0.5].map((offset) {
              final t = (_c.value + offset) % 1;
              return Transform.scale(
                scale: 0.6 + t * 0.9,
                child: Opacity(
                  opacity: 1 - t,
                  child: Container(
                    width: widget.width,
                    height: widget.height,
                    decoration: BoxDecoration(
                      border: Border.all(color: widget.color, width: 3),
                      borderRadius: BorderRadius.all(Radius.elliptical(widget.width / 2, widget.height / 2)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
}

/// Gentle up-and-down float.
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child, this.distance = 6, this.ms = 2000});

  final Widget child;
  final double distance;
  final int ms;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: widget.ms))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, -widget.distance * Curves.easeInOut.transform(_c.value)),
          child: child,
        ),
        child: widget.child,
      );
}

/// Tilted lime ribbon with repeated bold text.
class Ribbon extends StatelessWidget {
  const Ribbon({super.key, required this.text, this.angle = -0.1, this.color = QC.lime, this.textColor = QC.bg});

  final String text;
  final double angle;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        child: OverflowBox(
          maxWidth: 700,
          child: Container(
            width: 700,
            height: 44,
            color: color,
            alignment: Alignment.center,
            child: Text(
              List.filled(4, text).join('  /  '),
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: display(16, color: textColor, letterSpacing: 1.5),
            ),
          ),
        ),
      );
}

String km(double v) => v.toStringAsFixed(v >= 100 ? 1 : 2);

/// Runs a server action with a small blocking spinner. Shows the error as a
/// snackbar and returns null if it fails.
Future<T?> runWithSpinner<T>(BuildContext context, Future<T> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context, rootNavigator: true);
  var open = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: QC.lime)),
  ).whenComplete(() => open = false);
  try {
    final result = await action();
    if (open) nav.pop();
    if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    return result;
  } catch (e) {
    if (open) nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    return null;
  }
}
