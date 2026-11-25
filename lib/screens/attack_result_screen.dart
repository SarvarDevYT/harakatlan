import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../game/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Runs an attack (if allowed) and shows the result screen.
Future<void> startAttack(BuildContext context, Rival rival) async {
  final g = context.read<GameState>();
  final reason = g.attackBlockReason(rival);
  if (reason != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
    return;
  }
  final result = await runWithSpinner(context, () => g.attack(rival));
  if (result == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AttackResultScreen(result: result)));
}

class AttackResultScreen extends StatelessWidget {
  const AttackResultScreen({super.key, required this.result});

  final AttackResult result;

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    final r = result;
    final total = (r.myPower + r.rivalPower) == 0 ? 1 : r.myPower + r.rivalPower;
    final myShare = r.myPower / total;
    final now = TimeOfDay.now();

    return Scaffold(
      body: Stack(children: [
        Positioned(
          left: -140,
          top: -120,
          child: _Glow(color: r.won ? QC.lime : QC.red, size: 460, opacity: 0.22),
        ),
        Positioned(right: -160, top: 220, child: _Glow(color: r.rivalColor, size: 420, opacity: 0.28)),
        const ContourBackground(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                RoundIconButton(icon: Icons.close_rounded, tooltip: 'Yopish', onPressed: () => Navigator.pop(context)),
                const Spacer(),
                Chip2('Hujum · ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'),
              ]),
              const SizedBox(height: 18),
              Text('NATIJA', style: body(13, color: QC.muted, weight: FontWeight.w500).copyWith(letterSpacing: 1.2)),
              Stack(clipBehavior: Clip.none, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(r.won ? "G'ALABA!" : 'BU SAFAR YO\'Q',
                      style: display(64, color: r.won ? QC.lime : QC.text, height: 1, letterSpacing: -2)),
                ),
                if (r.won)
                  Positioned(right: 0, top: -16, child: HandNote('+${r.gained} katak!', color: QC.text, size: 28)),
              ]),
              const SizedBox(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _Fighter(name: 'Siz', initial: g.playerName, color: QC.lime, power: r.myPower, glow: r.won),
                Transform.rotate(
                  angle: -0.14,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: QC.text,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 10))],
                    ),
                    child: const Icon(Icons.sports_martial_arts_rounded, color: QC.bg, size: 30),
                  ),
                ),
                _Fighter(name: r.rivalName, initial: r.rivalName, color: r.rivalColor, power: r.rivalPower, glow: !r.won),
              ]),
              const SizedBox(height: 18),
              Semantics(
                label: 'Kuch nisbati: siz ${(myShare * 100).round()} foiz',
                child: SizedBox(
                  height: 14,
                  child: Row(children: [
                    Expanded(
                      flex: (myShare * 100).round().clamp(1, 99),
                      child: Container(decoration: BoxDecoration(color: QC.lime, borderRadius: BorderRadius.circular(999))),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      flex: (100 - myShare * 100).round().clamp(1, 99),
                      child: Container(decoration: BoxDecoration(color: r.rivalColor, borderRadius: BorderRadius.circular(999))),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: r.won ? QC.lime : QC.glass,
                      borderRadius: BorderRadius.circular(26),
                      border: r.won ? null : Border.all(color: QC.glassBorder),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.won ? 'Siz oldingiz' : 'Siz yo\'qotdingiz',
                          style: body(13, color: r.won ? QC.bg : QC.muted, weight: FontWeight.w600)),
                      Text(r.won ? '+${r.gained}' : '0', style: display(44, color: r.won ? QC.bg : QC.text, height: 1.1)),
                      Text(r.won ? 'bonus katak' : 'hech narsa', style: body(13, color: r.won ? QC.bg : QC.muted)),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassCard(
                    radius: 26,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${r.rivalName} yo\'qotdi', style: body(13, color: QC.muted)),
                      Text('0', style: display(44, height: 1.1)),
                      Text("o'z yeridan", style: body(13, color: QC.muted)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              GlassCard(
                radius: 22,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: Color(0x1FD4FF3F), shape: BoxShape.circle),
                    child: const Icon(Icons.shield_outlined, color: QC.lime, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      r.won
                          ? "${r.rivalName}ning ${r.rivalOwnTiles} katak o'z yeri va km lari joyida. Uning qal'asida 24 soat bayrog'ingiz turadi."
                          : "Hech narsa yo'qotmadingiz: yeringiz va km laringiz joyida. Ko'proq yuring va qayta urining!",
                      style: body(13, color: QC.textSoft, height: 1.45),
                    ),
                  ),
                ]),
              ),
              const Spacer(),
              LimeButton(label: 'Xaritaga qaytish', onPressed: () => Navigator.pop(context)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Fighter extends StatelessWidget {
  const _Fighter({required this.name, required this.initial, required this.color, required this.power, required this.glow});

  final String name;
  final String initial;
  final Color color;
  final double power;
  final bool glow;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 120,
        child: Column(children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: glow ? [BoxShadow(color: color.withAlpha(115), blurRadius: 40)] : null,
            ),
            child: Avatar(name: initial, color: color, size: 80, ring: color),
          ),
          const SizedBox(height: 14),
          Text(name, style: body(15, weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${power.toStringAsFixed(1)} km', style: display(26, color: glow ? QC.text : QC.textSoft)),
        ]),
      );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color.withAlpha((opacity * 255).round()), color.withAlpha(0)], stops: const [0, 0.65]),
          ),
        ),
      );
}
