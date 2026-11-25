import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'inbox_screen.dart';

class TerritoryScreen extends StatelessWidget {
  const TerritoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    final level = g.castleLevel;
    final next = g.nextLevelTiles;
    final ownShare = next == 0 ? 0.0 : (g.ownTiles / next).clamp(0.0, 1.0);
    final conqShare = next == 0 ? 0.0 : (g.conqueredTiles / next).clamp(0.0, 1.0 - ownShare);
    final pending = g.pendingTiles;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Row(children: [
            Expanded(child: Text('Mening hududim', style: display(26))),
            Chip2('$level-daraja', background: QC.lime, foreground: QC.bg),
            const SizedBox(width: 8),
            const InboxBell(),
          ]),
          SizedBox(
            height: 300,
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth + 40;
              final h = w / 1.5;
              return Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: -20,
                  top: 20,
                  width: w,
                  height: h,
                  child: ShaderMask(
                    shaderCallback: (r) => const RadialGradient(
                      radius: 0.75,
                      colors: [Colors.black, Colors.transparent],
                      stops: [0.7, 1],
                    ).createShader(r),
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/island.jpg',
                      fit: BoxFit.cover,
                      semanticLabel: "Sizning orolingiz: markazda qal'a, atrofida yer bo'laklari",
                    ),
                  ),
                ),
                if (pending > 0) ...[
                  Positioned(left: -20 + w * 0.13 - 14, top: 20 + h * 0.42 - 14, child: const _PlusMarker()),
                  Positioned(left: -20 + w * 0.86 - 14, top: 20 + h * 0.53 - 14, child: const _PlusMarker(delay: 400)),
                ],
                Positioned(
                  right: 0,
                  top: 0,
                  child: HandNote("sizning\nqal'angiz!", size: 26, angle: -0.1),
                ),
                if (pending > 0)
                  Positioned(left: 0, bottom: 0, child: HandNote('+ $pending ta yangi katak', size: 22, color: QC.textSoft, angle: -0.06)),
              ]);
            }),
          ),
          const SizedBox(height: 12),
          GlassCard(
            color: QC.surface,
            radius: 28,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${level + 1}-darajaga o'tish uchun", style: body(15, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        (next - g.totalTiles) > 0
                            ? 'Yana ${next - g.totalTiles} ta yangi katak kerak'
                            : 'Yangi darajaga tayyor!',
                        style: body(12, color: QC.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: QC.glass,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: QC.glassBorder),
                  ),
                  child: Text(
                    '${g.totalTiles} / $next katak',
                    style: display(14, weight: FontWeight.w700, color: QC.lime),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 12,
                  child: Stack(children: [
                    Container(color: QC.surface2),
                    FractionallySizedBox(widthFactor: ownShare + conqShare, child: Container(color: const Color(0xFF9DBE2A))),
                    FractionallySizedBox(widthFactor: ownShare, child: Container(color: QC.lime)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 14, runSpacing: 6, children: [
                _Legend(color: QC.lime, text: "O'z hududingiz: ${g.ownTiles} ta katak"),
                _Legend(color: const Color(0xFF9DBE2A), text: 'Bosib olingan: ${g.conqueredTiles} ta katak'),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: StatTile(label: 'Mudofaa', value: '${g.power.toStringAsFixed(1)} km')),
            const SizedBox(width: 8),
            Expanded(child: StatTile(label: "G'alabalar", value: '${g.wins}')),
            const SizedBox(width: 8),
            Expanded(child: StatTile(label: 'Kutmoqda', value: '+$pending', valueColor: QC.lime)),
          ]),
          const SizedBox(height: 18),
          LimeButton(
            label: pending > 0 ? '$pending ta yangi katakni joylash' : 'Yangi katak uchun yuring',
            onPressed: pending > 0
                ? () async {
                    final placed = await runWithSpinner(context, () => context.read<GameState>().placeTiles());
                    if (placed == null || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("$placed ta katak hududingizga qo'shildi!")),
                    );
                  }
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            "O'z yeringiz hech qachon yo'qolmaydi. Hujumda faqat bosib olingan yer qo'ldan qo'lga o'tadi.",
            textAlign: TextAlign.center,
            style: body(12.5, color: QC.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PlusMarker extends StatelessWidget {
  const _PlusMarker({this.delay = 0});

  final int delay;

  @override
  Widget build(BuildContext context) => Bob(
        ms: 800 + delay,
        distance: 5,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: QC.lime,
            shape: BoxShape.circle,
            border: Border.all(color: QC.bg, width: 2),
          ),
          child: const Icon(Icons.add_rounded, color: QC.bg, size: 18),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(text, style: body(12, color: QC.textSoft)),
      ]);
}
