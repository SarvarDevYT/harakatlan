import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../screens/battle_screen.dart';
import '../screens/loot_box_dialog.dart';
import '../theme.dart';
import 'common.dart';

class DailyBattleCard extends StatefulWidget {
  const DailyBattleCard({super.key});

  @override
  State<DailyBattleCard> createState() => _DailyBattleCardState();
}

class _DailyBattleCardState extends State<DailyBattleCard> {
  Timer? _timer;
  bool _forceOpenForTesting = false;

  @override
  void initState() {
    super.initState();
    // Taymerni har soniyada yangilab turish (19:00 ga qancha qolganini ko'rsatish)
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return 'Hozir';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _attack() async {
    final g = context.read<GameState>();
    final res = await runWithSpinner(context, () => g.attackDailyBoss());
    if (res == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BattleScreen(result: res)),
    );

    if (res.won && mounted) {
      await showDailyBattleRewardDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    final battle = g.dailyBattle;
    if (battle == null) return const SizedBox.shrink();

    final isOpen = battle.isOpen || _forceOpenForTesting;
    final timeLeft = battle.timeUntilOpen;
    final myPower = g.armyStrength;
    final bossPower = battle.defensePower;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: battle.completed && battle.won
              ? [const Color(0xFF1E3A1A), const Color(0xFF0F1E0F)]
              : isOpen
                  ? [const Color(0xFF3A1814), const Color(0xFF1E0E0C)]
                  : [const Color(0xFF261D15), const Color(0xFF16120E)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: battle.completed && battle.won
              ? QC.lime
              : isOpen
                  ? QC.red
                  : const Color(0xFF6E523A),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (battle.completed && battle.won
                    ? QC.lime
                    : isOpen
                        ? QC.red
                        : Colors.orange)
                .withAlpha(isOpen ? 45 : 20),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOpen ? QC.red : QC.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.flash_on_rounded, size: 14, color: QC.bg),
              const SizedBox(width: 4),
              Text('KUNLIK DUEL · PUBG BATTLE',
                  style: body(11, color: QC.bg, weight: FontWeight.w800)),
            ]),
          ),
          const Spacer(),
          if (!battle.completed)
            Chip2(
              isOpen ? '19:00 OCHILDI' : '19:00 DA OCHILADI',
              foreground: isOpen ? QC.lime : QC.orange,
              background: const Color(0x33000000),
            ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0x2E000000),
              shape: BoxShape.circle,
              border: Border.all(color: isOpen ? QC.red : QC.orange, width: 2),
            ),
            child: const Icon(Icons.sports_kabaddi_rounded, size: 30, color: QC.text),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(battle.bossName, style: display(18, color: QC.text)),
              const SizedBox(height: 2),
              Text(
                'Dushman kuchi: $bossPower · Siz: $myPower',
                style: body(13, color: myPower >= bossPower ? QC.lime : QC.red, weight: FontWeight.w600),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        if (!battle.completed) ...[
          if (!isOpen) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x2A000000),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: Row(children: [
                const Icon(Icons.timer_outlined, color: QC.orange, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Jangga ${_formatDuration(timeLeft)} qoldi. Ungacha ko'proq yuring va qo'shiningizni to'ldiring!",
                    style: body(12.5, color: QC.textSoft),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: Text("19:00 da ochiladi (${_formatDuration(timeLeft)})",
                  style: body(14, weight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                disabledBackgroundColor: const Color(0x33FFFFFF),
                disabledForegroundColor: QC.muted,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => setState(() => _forceOpenForTesting = true),
                child: Text('Sinov: 19:00 deb ochish', style: body(11, color: QC.muted)),
              ),
            ],
          ] else ...[
            // 19:00 dan keyin: Hujum qilish ochiq!
            LimeButton(
              label: 'Hujum qilish (Duelga kirishish)',
              icon: Icons.sports_kabaddi_rounded,
              background: QC.red,
              foreground: Colors.white,
              onPressed: _attack,
            ),
          ],
        ] else if (battle.won) ...[
          // G'alaba qozonildi
          Row(children: [
            const Icon(Icons.emoji_events_rounded, color: QC.gold, size: 24),
            const SizedBox(width: 8),
            Text("Bugungi dushman tor-mor etildi!",
                style: body(14, color: QC.gold, weight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          if (!battle.rewardClaimed)
            LimeButton(
              label: 'Sovrinni tanlash / Qutini ochish',
              icon: Icons.card_giftcard_rounded,
              background: QC.gold,
              foreground: QC.bg,
              onPressed: () => showDailyBattleRewardDialog(context),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0x1FD4FF3F),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text("✓ Sovg'a qabul qilindi",
                  style: body(13, color: QC.lime, weight: FontWeight.w600)),
            ),
        ] else ...[
          // Yutqazildi
          Text("Hujum qaytarildi. Qo'shinni ko'paytirib qayta urining!",
              style: body(13, color: QC.red)),
          const SizedBox(height: 10),
          LimeButton(
            label: 'Qayta urinish',
            icon: Icons.replay_rounded,
            background: QC.surface2,
            foreground: QC.text,
            onPressed: _attack,
          ),
        ],
      ]),
    );
  }
}
