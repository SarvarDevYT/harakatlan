import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../game/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'inbox_screen.dart';

class ClanScreen extends StatelessWidget {
  const ClanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clan = context.watch<GameState>().clan;
    return SafeArea(
      bottom: false,
      child: clan == null ? const _CreateClan() : _ClanView(clan: clan),
    );
  }
}

class _CreateClan extends StatefulWidget {
  const _CreateClan();

  @override
  State<_CreateClan> createState() => _CreateClanState();
}

class _CreateClanState extends State<_CreateClan> {
  final _name = TextEditingController();
  final _tag = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _tag.dispose();
    super.dispose();
  }

  void _create() {
    final name = _name.text.trim();
    final tag = _tag.text.trim();
    if (name.length < 3 || tag.length < 2 || tag.length > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom kamida 3 harf, teg 2–4 harf bo\'lsin')),
      );
      return;
    }
    runWithSpinner(context, () => context.read<GameState>().createClan(name, tag));
  }

  Future<void> _join() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: QC.surface,
        title: Text("Klanga qo'shilish", style: display(20)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          style: display(22, letterSpacing: 4),
          decoration: const InputDecoration(labelText: "Do'stingiz bergan kod", hintText: 'K7Q2MX', counterText: ''),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text("Qo'shilish")),
        ],
      ),
    );
    ctrl.dispose();
    if (code == null || code.trim().isEmpty || !mounted) return;
    await runWithSpinner(context, () => context.read<GameState>().joinClan(code.trim()), success: "Klanga qo'shildingiz!");
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Row(children: [
          Expanded(child: Text('Klan', style: display(28))),
          const InboxBell(),
        ]),
        const SizedBox(height: 24),
        Center(
          child: HexBlock(
            width: 110,
            top: QC.surface2,
            side: QC.bg,
            depth: 12,
            child: const Icon(Icons.groups_rounded, size: 46, color: QC.lime),
          ),
        ),
        const SizedBox(height: 16),
        Center(child: HandNote("birga kuchliroqmiz!", size: 28)),
        const SizedBox(height: 12),
        Text(
          "Klan yarating, do'stlaringizni chaqiring va boshqa klanlar bilan urushda jamoa km lari bilan g'alaba qiling.",
          textAlign: TextAlign.center,
          style: body(14, color: QC.textSoft, height: 1.5),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.characters,
          style: body(16),
          decoration: const InputDecoration(labelText: 'Klan nomi', hintText: 'Masalan, SHAMOL OYOQLAR'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _tag,
          maxLength: 4,
          textCapitalization: TextCapitalization.characters,
          style: body(16),
          decoration: const InputDecoration(labelText: 'Qisqa teg', hintText: 'SHO', counterText: ''),
        ),
        const SizedBox(height: 16),
        LimeButton(label: 'Klan yaratish', icon: Icons.add_rounded, onPressed: _create),
        if (context.watch<GameState>().online) ...[
          const SizedBox(height: 10),
          OutlinePill(label: "Kod bilan klanga qo'shilish", icon: Icons.vpn_key_rounded, color: QC.lime, onPressed: _join),
        ],
      ],
    );
  }
}

class _ClanView extends StatelessWidget {
  const _ClanView({required this.clan});

  final Clan clan;

  Future<void> _invite(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InviteFriendSheet(clan: clan),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    final total = clan.score + clan.enemyScore;
    final share = total == 0 ? 0.5 : clan.score / total;
    final left = clan.warEnds.difference(DateTime.now());
    final leftText = left.isNegative ? 'urush tugadi' : '${left.inDays} kun ${left.inHours % 24} soat qoldi';
    final members = [...clan.members]..sort((a, b) => b.weekKm.compareTo(a.weekKm));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Row(children: [
          Expanded(child: Text('Klan', style: display(28))),
          const InboxBell(),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Klan sozlamalari',
            icon: const Icon(Icons.more_horiz_rounded, color: QC.text),
            color: QC.surface,
            onSelected: (_) => runWithSpinner(context, () => g.leaveClan()),
            itemBuilder: (_) => const [PopupMenuItem(value: 'leave', child: Text('Klandan chiqish'))],
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: QC.lime, borderRadius: BorderRadius.circular(30)),
          child: Row(children: [
            ClipPath(
              clipper: const HexClipper(pointy: false),
              child: Container(
                width: 84,
                height: 92,
                color: QC.bg,
                child: const Icon(Icons.air_rounded, size: 42, color: QC.lime),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('bizning klan!', style: hand(22, color: QC.bg)),
                const SizedBox(height: 4),
                Text(clan.name, style: display(22, color: QC.bg, height: 1.05), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Chip2('[${clan.tag}]', background: QC.bg, foreground: QC.lime),
                  Chip2('Lv ${clan.level}', background: const Color(0x1F0B0B0B), foreground: QC.bg),
                  Chip2('${clan.members.length} / ${Clan.maxMembers}', background: const Color(0x1F0B0B0B), foreground: QC.bg),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        GlassCard(
          color: const Color(0xFF141414),
          radius: 30,
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: QC.red, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text('KLAN URUSHI', style: display(15, letterSpacing: 1.5))),
              Text(leftText, style: body(12, color: QC.textSoft)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(clan.tag, style: body(13, color: QC.textSoft)),
                  Text(clan.score.toStringAsFixed(0), style: display(36, color: QC.lime, height: 1.1)),
                  Text('km jamoa', style: body(12, color: QC.muted)),
                ]),
              ),
              Transform.rotate(angle: -0.14, child: Text('vs', style: hand(34, color: QC.text))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(clan.enemyName, style: body(13, color: QC.textSoft), overflow: TextOverflow.ellipsis),
                  Text(clan.enemyScore.toStringAsFixed(0), style: display(36, color: QC.blueSoft, height: 1.1)),
                  Text('km jamoa', style: body(12, color: QC.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              height: 12,
              child: Row(children: [
                Expanded(
                  flex: (share * 100).round().clamp(1, 99),
                  child: Container(decoration: BoxDecoration(color: QC.lime, borderRadius: BorderRadius.circular(999))),
                ),
                const SizedBox(width: 3),
                Expanded(
                  flex: (100 - share * 100).round().clamp(1, 99),
                  child: Container(decoration: BoxDecoration(color: QC.blue, borderRadius: BorderRadius.circular(999))),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: g.canPushClanWar
                  ? () async {
                      final added = await runWithSpinner(context, () => context.read<GameState>().pushClanWar());
                      if (added == null || !context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Klanga +${added.toStringAsFixed(1)} km qo\'shildi!')),
                      );
                    }
                  : null,
              icon: const Icon(Icons.bolt_rounded),
              label: Text(
                g.canPushClanWar
                    ? 'Klan bilan hujum (+${g.todayKm.toStringAsFixed(1)} km)'
                    : (g.todayKm == 0 ? 'Avval yuring' : 'Bugun hujum qildingiz'),
                style: body(15, weight: FontWeight.w700, color: g.canPushClanWar ? QC.bg : QC.muted),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: QC.text,
                foregroundColor: QC.bg,
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        SectionHeader('Bu hafta eng faollar', trailing: "${clan.members.length} a'zo"),
        const SizedBox(height: 10),
        ...List.generate(members.length, (i) {
          final m = members[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              radius: 18,
              padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
              child: Row(children: [
                SizedBox(width: 26, child: Text('${i + 1}', textAlign: TextAlign.center, style: display(15, color: QC.muted))),
                Avatar(name: m.name, color: m.color, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.name, style: body(14, weight: FontWeight.w600)),
                    Text(m.role, style: body(12, color: QC.muted)),
                  ]),
                ),
                Text(m.weekKm.toStringAsFixed(1), style: display(16)),
              ]),
            ),
          );
        }),
        const SizedBox(height: 6),
        OutlinePill(
          label: "Do'stlarni qo'shish / qidirish",
          icon: Icons.person_add_alt_1_rounded,
          color: QC.lime,
          onPressed: () => _invite(context),
        ),
      ],
    );
  }
}

class _InviteFriendSheet extends StatefulWidget {
  const _InviteFriendSheet({required this.clan});

  final Clan clan;

  @override
  State<_InviteFriendSheet> createState() => _InviteFriendSheetState();
}

class _InviteFriendSheetState extends State<_InviteFriendSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  final Set<String> _added = {};

  @override
  void initState() {
    super.initState();
    // Dastlabki tavsiya qilinadigan o'yinchilar
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String text) async {
    setState(() => _searching = true);
    final g = context.read<GameState>();
    final q = text.trim();
    final res = await g.searchUsers(q.isEmpty ? 'a' : q);
    if (!mounted) return;
    setState(() {
      _results = res;
      _searching = false;
    });
  }

  Future<void> _add(Map<String, dynamic> user) async {
    final name = user['name'] as String;
    final uid = user['uid'] as String?;
    final g = context.read<GameState>();

    final ok = await runWithSpinner(
      context,
      () => g.addFriendToClan(name: name, uid: uid),
      success: "$name klanga muvaffaqiyatli qo'shildi!",
    );

    if (ok == true && mounted) {
      setState(() => _added.add(name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.clan.inviteCode;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: QC.glassBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: QC.outline, borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text("Do'stlarni qo'shish", style: display(22))),
            RoundIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Yopish',
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          const SizedBox(height: 14),
          // Username qidiruv maydoni
          TextField(
            controller: _searchCtrl,
            style: body(15),
            onChanged: _search,
            decoration: InputDecoration(
              hintText: "Do'stingizning username/ismini yozing...",
              prefixIcon: const Icon(Icons.search_rounded, color: QC.muted),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: QC.muted, size: 20),
                      onPressed: () {
                        _searchCtrl.clear();
                        _search('');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          // Qidiruv natijalari
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator(color: QC.lime))
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_search_rounded, size: 48, color: QC.muted),
                            const SizedBox(height: 10),
                            Text("Bunday username topilmadi", style: body(14, color: QC.muted)),
                            const SizedBox(height: 4),
                            Text("Boshqa nom bilan qidirib ko'ring", style: body(12, color: QC.outline)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) {
                          final u = _results[i];
                          final name = u['name'] as String;
                          final level = u['castleLevel'] ?? 1;
                          final inClan = widget.clan.members.any((m) => m.name == name) || _added.contains(name);
                          final hasOtherClan = u['clanId'] != null && !inClan;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              radius: 18,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(children: [
                                Avatar(name: name, color: QC.lime, size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: body(15, weight: FontWeight.w600)),
                                      Text(
                                        hasOtherClan
                                            ? "Boshqa klanda"
                                            : "Qal'a Lv $level · ${(u['totalKm'] as num? ?? 0).toStringAsFixed(0)} km",
                                        style: body(12, color: hasOtherClan ? QC.red : QC.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                if (inClan)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0x1FD4FF3F),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.check_rounded, size: 16, color: QC.lime),
                                      const SizedBox(width: 4),
                                      Text("A'zo", style: body(13, color: QC.lime, weight: FontWeight.w700)),
                                    ]),
                                  )
                                else
                                  FilledButton(
                                    onPressed: hasOtherClan ? null : () => _add(u),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: QC.lime,
                                      foregroundColor: QC.bg,
                                      minimumSize: const Size(0, 38),
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                    ),
                                    child: Text(
                                      "+ Qo'shish",
                                      style: body(13, weight: FontWeight.w700, color: QC.bg),
                                    ),
                                  ),
                              ]),
                            ),
                          );
                        },
                      ),
          ),
          if (code != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: QC.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: QC.glassBorder),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Taklif kodi orqali ham kirish mumkin:", style: body(11, color: QC.muted)),
                    Text(code, style: display(18, color: QC.lime, letterSpacing: 3)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Kodni nusxalash',
                  icon: const Icon(Icons.copy_rounded, color: QC.lime, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Taklif kodi nusxalandi!')),
                    );
                  },
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}
