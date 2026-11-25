import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../game/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Full-screen list of "you were attacked" messages from the server.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameState>().readInbox();
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<GameState>().inbox;

    return Scaffold(
      body: Stack(children: [
        const ContourBackground(),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(children: [
                Expanded(child: Text('Bildirishnomalar', style: display(26))),
                RoundIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Yopish',
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Expanded(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(color: QC.glass, shape: BoxShape.circle),
                      child: const Icon(Icons.shield_outlined, size: 36, color: QC.muted),
                    ),
                    const SizedBox(height: 16),
                    Text("Hech qanday hujum bo'lmagan", style: body(16, color: QC.muted)),
                    const SizedBox(height: 6),
                    Text("Qal'angiz xavfsiz!", style: hand(22)),
                  ]),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[items.length - 1 - i]; // newest first
                    return _InboxCard(item: item);
                  },
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.item});

  final InboxItem item;

  @override
  Widget build(BuildContext context) {
    final won = item.attacked; // "attacked" = we lost
    final icon = won ? Icons.local_fire_department_rounded : Icons.shield_rounded;
    final color = won ? QC.red : QC.lime;
    final title = won ? "Qal'angizga hujum bo'ldi!" : "Hujum qaytarildi!";
    final sub = won
        ? "${item.by} hujum qildi · mudofaa −${item.defenseLost} · ${item.soldiersLost} askar yo'qoldi"
        : "${item.by} hujum qildi, lekin qal'angiz ushlab qoldi";

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(16),
        color: won ? const Color(0x14FF5A4E) : QC.glass,
        borderColor: won ? const Color(0x33FF5A4E) : QC.glassBorder,
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: body(14, weight: FontWeight.w700, color: color)),
              const SizedBox(height: 4),
              Text(sub, style: body(13, color: QC.textSoft, height: 1.35)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A small bell icon that shows a red dot if there are unread messages.
class InboxBell extends StatelessWidget {
  const InboxBell({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<GameState>().inbox.length;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const InboxScreen()),
      ),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: QC.glass,
              shape: BoxShape.circle,
              border: Border.all(color: QC.glassBorder),
            ),
            child: Icon(
              count > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
              color: count > 0 ? QC.lime : QC.muted,
              size: 20,
            ),
          ),
          if (count > 0)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(color: QC.red, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
