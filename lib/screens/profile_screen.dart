import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../game/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'inbox_screen.dart';
import 'season_screen.dart';

const _dayShort = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    final week = g.lastWeek;
    final maxKm = week.fold<double>(1, (m, e) => e.value > m ? e.value : m);
    final hasGoldRing = g.claimedRewards.contains('gold_ring');

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Row(children: [
            Avatar(name: g.playerName, color: QC.lime, size: 56, ring: hasGoldRing ? QC.gold : null),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.playerName, style: display(24), overflow: TextOverflow.ellipsis),
                Text("Qal'a Lv ${g.castleLevel} · ${g.wins} g'alaba", style: body(13, color: QC.muted)),
              ]),
            ),
            const InboxBell(),
          ]),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SeasonScreen())),
              child: GlassCard(
                color: g.tier.color.withAlpha(26),
                borderColor: g.tier.color.withAlpha(110),
                child: Row(children: [
                  HexBlock(
                    width: 40,
                    top: g.tier.color,
                    side: Color.lerp(g.tier.color, Colors.black, 0.5)!,
                    depth: 6,
                    child: const Icon(Icons.workspace_premium_rounded, size: 20, color: QC.bg),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Mavsum reytingi', style: body(12, color: QC.muted)),
                      Text('${g.tier.label.toUpperCase()} ${g.division}', style: display(20, color: g.tier.color)),
                    ]),
                  ),
                  Text('${g.rankPoints} RP', style: body(13, color: QC.textSoft)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: QC.muted),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            color: QC.surface,
            radius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Jami yurilgan', style: body(13, color: QC.muted)),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: g.totalKm.toStringAsFixed(1), style: display(40, height: 1)),
                      TextSpan(text: ' km', style: display(18, color: QC.muted)),
                    ])),
                  ]),
                ),
                const Chip2('Hech qachon kamaymaydi', foreground: QC.lime, background: QC.surface2),
              ]),
              const SizedBox(height: 16),
              Semantics(
                label: 'Haftalik masofa: ${week.map((e) => '${_dayShort[e.key.weekday - 1]} ${e.value.toStringAsFixed(1)}').join(', ')} km',
                child: SizedBox(
                  height: 100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(week.length, (i) {
                      final e = week[i];
                      final isToday = i == week.length - 1;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Container(
                              height: 4 + 70 * (e.value / maxKm),
                              decoration: BoxDecoration(
                                color: isToday ? QC.lime : QC.outline,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_dayShort[e.key.weekday - 1], style: body(11, color: QC.muted)),
                          ]),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: QC.lime, borderRadius: BorderRadius.circular(24)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.shield_rounded, color: QC.bg, size: 22),
                  const SizedBox(height: 6),
                  Text('${g.ownTiles}', style: display(32, color: QC.bg, height: 1)),
                  Text("O'z yerim · doimiy", style: body(13, color: QC.bg, weight: FontWeight.w500)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GlassCard(
                color: QC.surface,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.flag_rounded, color: QC.lime, size: 22),
                  const SizedBox(height: 6),
                  Text('${g.conqueredTiles}', style: display(32, height: 1)),
                  Text('Bosib olingan', style: body(13, color: QC.muted)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          SectionHeader("Qurolxona (Arsenal)", trailing: "${g.ownedWeapons.length} / ${allWeapons.length} qurol"),
          const SizedBox(height: 10),
          GlassCard(
            color: QC.surface,
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.sports_kabaddi_rounded, color: QC.gold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    g.weaponBonusPower > 0 || g.weaponBonusDefense > 0
                        ? "Qurollar bonusi: +${g.weaponBonusPower} Kuch, +${g.weaponBonusDefense}% Mudofaa"
                        : "Duelda yutib qutidan qurollar yig'ing!",
                    style: body(13, color: QC.gold, weight: FontWeight.w600),
                  ),
                ]),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allWeapons.map((w) {
                    final has = g.ownedWeapons.contains(w.id);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: has ? w.color.withAlpha(30) : QC.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: has ? w.color : QC.glassBorder),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(has ? w.icon : Icons.lock_rounded,
                            size: 16, color: has ? w.color : QC.muted),
                        const SizedBox(width: 6),
                        Text(w.name,
                            style: body(12,
                                color: has ? QC.text : QC.muted,
                                weight: has ? FontWeight.w600 : FontWeight.w400)),
                      ]),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: QC.surface,
                  title: Text("Akkauntni o'chirish", style: display(20)),
                  content: Text(
                    "Hududingiz, km laringiz va sovg'alaringiz butunlay o'chadi. Buni qaytarib bo'lmaydi. Davom etasizmi?",
                    style: body(14, color: QC.textSoft),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("O'chirish", style: TextStyle(color: QC.red))),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await runWithSpinner(context, () => context.read<GameState>().deleteAccount());
              }
            },
            child: Text("Akkauntni o'chirish", style: body(14, color: QC.muted)),
          ),
        ],
      ),
    );
  }
}
