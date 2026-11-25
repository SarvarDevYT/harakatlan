import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../game/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// PUBG Mobile uslubidagi Duel g'alabasi sovrinlarini tanlash yoki Jangovar Qutini ochish dialogi
Future<void> showDailyBattleRewardDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _RewardDialog(),
  );
}

class _RewardDialog extends StatefulWidget {
  const _RewardDialog();

  @override
  State<_RewardDialog> createState() => _RewardDialogState();
}

class _RewardDialogState extends State<_RewardDialog> with SingleTickerProviderStateMixin {
  int _tab = 0; // 0: Tanlash, 1: Quti ochish, 2: Quti natijasi
  Weapon? _openedWeapon;
  late final AnimationController _crateAnim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _crateAnim.dispose();
    super.dispose();
  }

  void _claimSoldiers(String type) {
    context.read<GameState>().claimDailySoldiers(type);
    HapticFeedback.heavyImpact();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          type == 'archers'
              ? "+30 Kamonchilar qo'shiningizga qo'shildi!"
              : type == 'cavalry'
                  ? "+15 Otliq askarlar qo'shildi!"
                  : "+40 Piyoda askarlar qo'shildi!",
        ),
      ),
    );
  }

  Future<void> _openCrate() async {
    HapticFeedback.heavyImpact();
    setState(() => _tab = 1);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    final w = context.read<GameState>().openDailyLootBox();
    HapticFeedback.vibrate();
    setState(() {
      _openedWeapon = w;
      _tab = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: QC.gold, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x66F2C94C), blurRadius: 40, spreadRadius: 4),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_tab == 0) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: QC.gold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('PUBG BATTLE G\'ALABASI!',
                      style: body(12, color: QC.bg, weight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text('Sovrinni tanlang', style: display(24, color: QC.gold))),
              const SizedBox(height: 6),
              Text(
                'Kuchli dushmanni yengdingiz! Askarlar to\'plamini tanlang yoki sirli qutini oching:',
                textAlign: TextAlign.center,
                style: body(13, color: QC.textSoft, height: 1.3),
              ),
              const SizedBox(height: 18),
              // Option A: Soldiers
              Text('VARIANT 1: QO\'SHIN TANLASH', style: body(11, color: QC.muted, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _SoldierOption(
                    title: '+30 Kamonchi',
                    icon: Icons.call_missed_outgoing_rounded,
                    color: QC.lime,
                    onTap: () => _claimSoldiers('archers'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SoldierOption(
                    title: '+15 Otliq',
                    icon: Icons.flight_takeoff_rounded,
                    color: QC.orange,
                    onTap: () => _claimSoldiers('cavalry'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SoldierOption(
                    title: '+40 Piyoda',
                    icon: Icons.sports_martial_arts_rounded,
                    color: QC.blueSoft,
                    onTap: () => _claimSoldiers('infantry'),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              // Option B: Loot Crate
              Text('VARIANT 2: JANGOVAR QUTI (10 XIL QUROL)', style: body(11, color: QC.muted, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _openCrate,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E2207), Color(0xFF1F1705)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: QC.gold),
                  ),
                  child: Row(children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0x33F2C94C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: QC.gold, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Sirli Jangovar Quti', style: body(15, weight: FontWeight.w700, color: QC.gold)),
                        Text('10 xil qurol-aslahadan 1 tasi kafolatlangan', style: body(12, color: QC.textSoft)),
                      ]),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: QC.gold, size: 16),
                  ]),
                ),
              ),
            ] else if (_tab == 1) ...[
              // Animatsiya: Crate ochilmoqda
              const SizedBox(height: 20),
              Center(
                child: AnimatedBuilder(
                  animation: _crateAnim,
                  builder: (context, _) => Transform.scale(
                    scale: 1.0 + _crateAnim.value * 0.12,
                    child: Transform.rotate(
                      angle: sin(_crateAnim.value * 2 * pi) * 0.08,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0x33F2C94C),
                          shape: BoxShape.circle,
                          border: Border.all(color: QC.gold, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Color(0x88F2C94C), blurRadius: 40, spreadRadius: 6),
                          ],
                        ),
                        child: const Icon(Icons.inventory_2_rounded, size: 64, color: QC.gold),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(child: Text('QUTI OCHILMOQDA...', style: display(22, color: QC.gold))),
              const SizedBox(height: 8),
              Center(child: Text('Tasodifiy qurol tanlanmoqda', style: body(13, color: QC.muted))),
              const SizedBox(height: 20),
            ] else if (_tab == 2 && _openedWeapon != null) ...[
              // Natija: Qurol tushdi!
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _openedWeapon!.color.withAlpha(35),
                    shape: BoxShape.circle,
                    border: Border.all(color: _openedWeapon!.color, width: 2),
                    boxShadow: [
                      BoxShadow(color: _openedWeapon!.color.withAlpha(100), blurRadius: 30),
                    ],
                  ),
                  child: Icon(_openedWeapon!.icon, size: 48, color: _openedWeapon!.color),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text('YANGI QUROL TUSHDI!',
                    style: body(13, color: QC.gold, weight: FontWeight.w800)),
              ),
              const SizedBox(height: 4),
              Center(child: Text(_openedWeapon!.name, style: display(24, color: _openedWeapon!.color))),
              const SizedBox(height: 6),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: QC.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: QC.glassBorder),
                  ),
                  child: Text(_openedWeapon!.description,
                      style: body(13, color: QC.lime, weight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
              LimeButton(
                label: 'Qabul qilish',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SoldierOption extends StatelessWidget {
  const _SoldierOption({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(title,
              textAlign: TextAlign.center,
              style: body(12, weight: FontWeight.w700, color: QC.text)),
        ]),
      ),
    );
  }
}
