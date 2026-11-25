import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../game/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SeasonScreen extends StatefulWidget {
  const SeasonScreen({super.key});

  @override
  State<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends State<SeasonScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    final tier = g.tier;
    final next = g.nextTier;
    final now = DateTime.now();
    final seasonEnd = DateTime(now.year, now.month + 1, 1);
    final daysLeft = seasonEnd.difference(now).inDays + 1;

    return Scaffold(
      body: Stack(children: [
        Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [tier.color.withAlpha(72), tier.color.withAlpha(0)], stops: const [0, 0.65]),
              ),
            ),
          ),
        ),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(children: [
                RoundIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Orqaga', onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(child: Text('Mavsum ${now.month}', style: display(28))),
                Chip2('$daysLeft kun qoldi'),
              ]),
              SizedBox(
                height: 200,
                child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                  RotationTransition(
                    turns: _spin,
                    child: CustomPaint(size: const Size(180, 180), painter: _DashedRing(tier.color)),
                  ),
                  Bob(
                    ms: 2000,
                    child: HexBlock(
                      width: 104,
                      top: tier.color,
                      side: Color.lerp(tier.color, Colors.black, 0.5)!,
                      depth: 14,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color.lerp(tier.color, Colors.white, 0.55)!, tier.color, Color.lerp(tier.color, Colors.black, 0.25)!],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.workspace_premium_rounded, size: 34, color: Color(0xFF2A2005)),
                        Text(g.division, style: display(22, color: const Color(0xFF2A2005), height: 1)),
                      ]),
                    ),
                  ),
                  if (next != null)
                    Positioned(
                      right: 0,
                      bottom: 30,
                      child: HandNote('${next.label.toLowerCase()}ga\noz qoldi!', color: tier.color, size: 24),
                    ),
                ]),
              ),
              Center(child: Text('${tier.label.toUpperCase()} ${g.division}', style: display(34, color: tier.color, letterSpacing: 0.5))),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  next == null
                      ? "Qal'a Lv ${g.castleLevel} · ${g.rankPoints} RP · eng yuqori rank!"
                      : "Qal'a Lv ${g.castleLevel} · ${g.rankPoints} / ${next.minPoints} RP",
                  style: body(13, color: QC.textSoft),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: g.tierProgress,
                  minHeight: 12,
                  backgroundColor: QC.surface2,
                  valueColor: AlwaysStoppedAnimation(tier.color),
                  semanticsLabel: 'Keyingi rankgacha',
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: Tier.values.map((t) {
                  final current = t == tier;
                  final locked = t.index > tier.index;
                  return Opacity(
                    opacity: locked ? 0.4 : 1,
                    child: Column(children: [
                      HexBlock(
                        width: current ? 44 : 32,
                        top: t.color,
                        side: Color.lerp(t.color, Colors.black, 0.5)!,
                        depth: current ? 6 : 4,
                        child: locked ? const Icon(Icons.lock_rounded, size: 14, color: QC.bg) : null,
                      ),
                      const SizedBox(height: 6),
                      Text(t.label,
                          style: body(11, color: current ? t.color : QC.muted, weight: current ? FontWeight.w700 : FontWeight.w400)),
                    ]),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const SectionHeader("Mavsum sovg'alari", trailing: "qal'a va profil uchun"),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: GameState.rewards.map((r) => _RewardCard(reward: r)).toList(),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward});

  final Reward reward;

  IconData get _icon => switch (reward.kind) {
        RewardKind.castleSkin => Icons.castle_rounded,
        RewardKind.avatarFrame => Icons.account_circle_rounded,
        RewardKind.flag => Icons.flag_rounded,
        RewardKind.mapEffect => Icons.local_fire_department_rounded,
        RewardKind.emblem => Icons.shield_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    final unlocked = g.isUnlocked(reward);
    final claimed = g.claimedRewards.contains(reward.id);
    final c = reward.unlock.color;

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(12),
      color: unlocked && !claimed ? c.withAlpha(20) : QC.glass,
      borderColor: unlocked && !claimed ? c.withAlpha(100) : QC.glassBorder,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Opacity(
            opacity: unlocked ? 1 : 0.5,
            child: HexBlock(width: 40, top: c, side: Color.lerp(c, Colors.black, 0.5)!, depth: 5, child: Icon(_icon, size: 20, color: QC.bg)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(reward.title, style: body(14, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(reward.kindLabel, style: body(12, color: QC.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        const Spacer(),
        SizedBox(
          height: 32,
          child: claimed
              ? Container(
                  decoration: BoxDecoration(color: const Color(0x1FD4FF3F), borderRadius: BorderRadius.circular(999)),
                  alignment: Alignment.center,
                  child: Text('Olingan', style: body(13, color: QC.lime, weight: FontWeight.w600)),
                )
              : unlocked
                  ? FilledButton(
                      onPressed: () => runWithSpinner(context, () => g.claimReward(reward), success: '${reward.title} olindi!'),
                      style: FilledButton.styleFrom(backgroundColor: c, foregroundColor: QC.bg, padding: EdgeInsets.zero),
                      child: Text('Olish', style: body(13, color: QC.bg, weight: FontWeight.w700)),
                    )
                  : Container(
                      decoration: BoxDecoration(color: QC.surface2, borderRadius: BorderRadius.circular(999)),
                      alignment: Alignment.center,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.lock_rounded, size: 13, color: QC.muted),
                        const SizedBox(width: 4),
                        Text('${reward.unlock.label}da', style: body(12, color: QC.muted)),
                      ]),
                    ),
        ),
      ]),
    );
  }
}

class _DashedRing extends CustomPainter {
  _DashedRing(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const dashes = 36;
    for (var i = 0; i < dashes; i++) {
      final a = i * 2 * 3.14159265 / dashes;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, 0.06, false, p);
    }
    canvas.drawCircle(c, r - 12, Paint()
      ..color = color.withAlpha(76)
      ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _DashedRing old) => old.color != color;
}
