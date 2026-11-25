import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/daily_battle_card.dart';
import 'attack_result_screen.dart';
import 'food_scanner_screen.dart';
import 'inbox_screen.dart';

const _months = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr'
];
const _weekdays = ['Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba'];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.goTo});

  final ValueChanged<int> goTo;

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    final now = DateTime.now();
    final progress = (g.todayKm / GameState.dailyGoalKm).clamp(0.0, 1.0);
    const ticks = 22;

    return Stack(children: [
      const ContourBackground(),
      SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Row(children: [
              Avatar(name: g.playerName, color: QC.lime, size: 46, ring: QC.lime),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_weekdays[now.weekday - 1]}, ${now.day}-${_months[now.month - 1]}',
                      style: body(13, color: QC.muted)),
                  Text('Salom, ${g.playerName}', style: display(20), overflow: TextOverflow.ellipsis),
                ]),
              ),
              Chip2('Hujum ${g.attacksLeft}/${GameState.maxAttacksPerDay}', dot: QC.lime),
              const SizedBox(width: 8),
              const InboxBell(),
            ]),
            const SizedBox(height: 26),
            Text('BUGUN YURDINGIZ', style: body(13, color: QC.muted, weight: FontWeight.w500).copyWith(letterSpacing: 1.2)),
            Stack(clipBehavior: Clip.none, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(km(g.todayKm), style: display(100, height: 0.95, letterSpacing: -4)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('km', style: display(24, color: QC.muted, weight: FontWeight.w600)),
                ),
              ]),
              Positioned(
                right: 0,
                top: -4,
                child: HandNote(progress >= 1 ? 'maqsad\nbajarildi!' : "zo'r\nketyapsiz!", size: 28),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Semantics(
                  label: 'Kunlik maqsadning ${(progress * 100).round()} foizi',
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: QC.glass,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: QC.glassBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(ticks, (i) {
                        final on = i < (progress * ticks).round();
                        return Container(
                          width: 4,
                          height: on ? 16 : 12,
                          decoration: BoxDecoration(
                            color: on ? QC.lime : QC.outline,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${GameState.dailyGoalKm.toStringAsFixed(0)} km maqsad', style: body(13, color: QC.textSoft)),
            ]),
            const SizedBox(
              height: 92,
              child: Center(child: Ribbon(text: 'HAR QADAM · YANGI HUDUD', angle: -0.08)),
            ),
            Row(children: [
              Expanded(child: StatTile(label: 'Qadamlar', value: '${g.todaySteps}')),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: 'Kuch', value: '${g.power.toStringAsFixed(1)} km')),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: 'Jami', value: '${g.totalKm.toStringAsFixed(1)} km', valueColor: QC.lime)),
            ]),
            const SizedBox(height: 8),
            // Qo'shin holati (Piyoda, Otliq, Kamonchi)
            GlassCard(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text("🛡️ ${g.infantry} piyoda", style: body(12, color: QC.textSoft, weight: FontWeight.w600)),
                  Container(width: 1, height: 16, color: QC.outline),
                  Text("🐎 ${g.cavalry} otliq", style: body(12, color: QC.textSoft, weight: FontWeight.w600)),
                  Container(width: 1, height: 16, color: QC.outline),
                  Text("🏹 ${g.archers} kamonchi", style: body(12, color: QC.lime, weight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const DailyBattleCard(),
            const SizedBox(height: 12),
            _BuildCard(pending: g.pendingTiles, onTap: () => goTo(2)),
            const SizedBox(height: 12),
            // AI Kaloriya va Taom Skaneri (Gemini 1.5 Flash Vision)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FoodScannerScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E2812), Color(0xFF141A0B)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: QC.lime.withAlpha(100)),
                ),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: QC.lime.withAlpha(30),
                      shape: BoxShape.circle,
                      border: Border.all(color: QC.lime, width: 1.5),
                    ),
                    child: const Icon(Icons.restaurant_rounded, color: QC.lime, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text("AI Taom Skaneri", style: body(15, weight: FontWeight.w700, color: QC.text)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: QC.lime, borderRadius: BorderRadius.circular(6)),
                          child: Text("Gemini AI", style: body(10, color: QC.bg, weight: FontWeight.w800)),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text("Suratga oling va kaloriya/makrolarni aniqlang", style: body(12, color: QC.muted)),
                    ]),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: QC.lime, size: 16),
                ]),
              ),
            ),
            const SizedBox(height: 22),
            SectionHeader("Qo'shni qal'alar", trailing: 'Kuchingiz ${g.power.toStringAsFixed(1)} km'),
            const SizedBox(height: 10),
            ...g.rivals.map((r) {
              final stronger = g.power > r.power;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  radius: 20,
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(children: [
                    Avatar(name: r.name, color: r.color, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.name, style: body(15, weight: FontWeight.w600)),
                        Text(
                          r.isFlagged
                              ? 'Bayrog\'ingiz ostida'
                              : 'Kuch ${r.power.toStringAsFixed(1)} · ${stronger ? 'siz kuchliroqsiz' : 'hozircha kuchliroq'}',
                          style: body(13, color: QC.muted),
                        ),
                      ]),
                    ),
                    FilledButton(
                      onPressed: r.isFlagged ? null : () => startAttack(context, r),
                      style: FilledButton.styleFrom(
                        backgroundColor: stronger ? QC.lime : QC.surface2,
                        foregroundColor: stronger ? QC.bg : QC.textSoft,
                        minimumSize: const Size(0, 44),
                      ),
                      child: Text('Hujum', style: body(14, weight: FontWeight.w700, color: stronger ? QC.bg : QC.textSoft)),
                    ),
                  ]),
                ),
              );
            }),
            if ((g.stepSensorMissing || kDebugMode) && !g.online) ...[
              const SizedBox(height: 8),
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sinov rejimi', style: body(14, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    g.stepSensorMissing
                        ? 'Bu qurilmada qadam sensori yo\'q (masalan, simulyator). Masofani qo\'lda qo\'shing.'
                        : 'Faqat sinov uchun: masofani qo\'lda qo\'shish.',
                    style: body(13, color: QC.muted),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: OutlinePill(label: '+0.5 km', onPressed: () => g.addDistance(0.5), color: QC.lime)),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinePill(label: '+2 km', onPressed: () => g.addDistance(2), color: QC.lime)),
                  ]),
                ]),
              ),
            ],
          ],
        ),
      ),
    ]);
  }
}

class _BuildCard extends StatelessWidget {
  const _BuildCard({required this.pending, required this.onTap});

  final int pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 172,
      decoration: BoxDecoration(color: QC.lime, borderRadius: BorderRadius.circular(30)),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        const Positioned(
          right: 6,
          top: 14,
          child: ExcludeSemantics(
            child: SizedBox(
              width: 130,
              height: 120,
              child: Stack(children: [
                Positioned(left: 20, top: 0, child: HexBlock(width: 38, top: QC.bg, side: Color(0xFF5E7716), depth: 7)),
                Positioned(left: 60, top: 0, child: HexBlock(width: 38, top: QC.bg, side: Color(0xFF5E7716), depth: 7)),
                Positioned(left: 0, top: 33, child: HexBlock(width: 38, top: QC.bg, side: Color(0xFF5E7716), depth: 7)),
                Positioned(left: 80, top: 33, child: HexBlock(width: 38, top: QC.bg, side: Color(0xFF5E7716), depth: 7)),
                Positioned(
                  left: 40,
                  top: 25,
                  child: HexBlock(
                    width: 38,
                    top: QC.text,
                    side: QC.outline,
                    depth: 14,
                    child: Icon(Icons.castle_rounded, size: 20, color: QC.bg),
                  ),
                ),
                Positioned(left: 20, top: 66, child: HexBlock(width: 38, top: QC.bg, side: Color(0xFF5E7716), depth: 7)),
                Positioned(left: 60, top: 66, child: HexBlock(width: 38, top: Color(0x2E0B0B0B), side: Colors.transparent, depth: 0)),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("qal'ang o'smoqda", style: hand(24, color: QC.bg)),
            const SizedBox(height: 4),
            SizedBox(
              width: 190,
              child: Text(
                pending > 0 ? '$pending ta yangi katak tayyor' : 'Yuring — har km yangi katak',
                style: display(23, color: QC.bg, height: 1.1),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onTap,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text('Hududni qurish', style: body(15, weight: FontWeight.w700, color: QC.lime)),
              style: FilledButton.styleFrom(
                backgroundColor: QC.bg,
                foregroundColor: QC.lime,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
