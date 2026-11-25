import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../game/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'attack_result_screen.dart';
import 'inbox_screen.dart';
import '../widgets/real_gps_map.dart';
import '../widgets/region_selector_sheet.dart';

/// Where things sit on assets/images/map.jpg (864×1536 px).
const _imageSize = Size(864, 1536);
const _ownCastle = Offset(465, 760);
const _castles = {
  'ali': Offset(675, 430), // wooden tower, blue land
  'madina': Offset(215, 300), // orange-roof castle
};

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _mapMode = 0; // 0: Jonli GPS Xarita, 1: Taktik Orol
  String _selected = 'ali';
  final _view = TransformationController();
  Size? _laidOutFor;

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    final Rival? rival = g.rivals.isEmpty
        ? null
        : g.rivals.firstWhere((r) => r.id == _selected, orElse: () => g.rivals.first);

    return LayoutBuilder(builder: (context, c) {
      final box = Size(c.maxWidth, c.maxHeight);
      // The island is drawn a bit wider than the screen so it can be panned.
      final mapWidth = box.width * 1.25;
      final scale = mapWidth / _imageSize.width;
      final mapHeight = _imageSize.height * scale;
      Offset place(Offset p) => Offset(p.dx * scale, p.dy * scale);
      final own = place(_ownCastle);

      // First layout: centre the view on the player's castle.
      if (_laidOutFor != box) {
        _laidOutFor = box;
        final tx = -(mapWidth - box.width) / 2;
        final ty = -(own.dy - box.height * 0.36).clamp(0.0, max(0.0, mapHeight - box.height)).toDouble();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _view.value = Matrix4.translationValues(tx, ty, 0);
        });
      }

      return Stack(children: [
        // 1. Map content according to mode
        if (_mapMode == 0)
          const Positioned.fill(child: RealGpsMapWidget())
        else ...[
          Container(color: const Color(0xFF0E3A57)),
          InteractiveViewer(
            transformationController: _view,
            constrained: false,
            minScale: 0.8,
            maxScale: 2.5,
            boundaryMargin: const EdgeInsets.all(80),
            child: SizedBox(
              width: mapWidth,
              height: mapHeight,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/map.jpg',
                    fit: BoxFit.fill,
                    semanticLabel: "Orol xaritasi: o'z qal'angiz, Alining minorasi va Madinaning qal'asi",
                  ),
                ),
                // Tap areas + labels for rivals that have a castle on the map.
                for (final entry in _castles.entries)
                  if (g.rivals.any((r) => r.id == entry.key))
                    _CastleMarker(
                      at: place(entry.value),
                      rival: g.rivals.firstWhere((r) => r.id == entry.key),
                      selected: entry.key == _selected,
                      onTap: () => setState(() => _selected = entry.key),
                    ),
                Positioned(
                  left: own.dx - 40,
                  top: own.dy - 40,
                  child: _Tag(text: 'Siz · Lv ${g.castleLevel}', color: QC.lime),
                ),
              ]),
            ),
          ),
        ],

        // Header fade
        IgnorePointer(
          child: Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [QC.bg, Color(0xE60B0B0B), Color(0x000B0B0B)],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
        ),

        // Header controls
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Xarita', style: display(30))),
                GestureDetector(
                  onTap: () => showRegionSelector(context),
                  child: Chip2(
                    g.league,
                    dot: QC.lime,
                    background: QC.surface,
                    trailingIcon: Icons.keyboard_arrow_down_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                const InboxBell(),
              ]),
              const SizedBox(height: 10),
              // Segmented mode switcher
              Row(children: [
                _ModePill(
                  label: 'GPS Xarita',
                  icon: Icons.map_rounded,
                  selected: _mapMode == 0,
                  onTap: () => setState(() => _mapMode = 0),
                ),
                const SizedBox(width: 8),
                _ModePill(
                  label: 'Taktik Orol',
                  icon: Icons.shield_rounded,
                  selected: _mapMode == 1,
                  onTap: () => setState(() => _mapMode = 1),
                ),
              ]),
              if (_mapMode == 1) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  const Chip2('Siz', dot: Color(0xFFC8F05A), background: QC.navBg),
                  for (final r in g.rivals) Chip2(r.name, dot: r.color, background: QC.navBg),
                ]),
              ],
            ]),
          ),
        ),

        // Bottom rival card only in Tactical Island mode (GPS map has its own interactive card)
        if (_mapMode == 1)
          Positioned(
            left: 12,
            right: 12,
            bottom: 96 + MediaQuery.paddingOf(context).bottom,
            child: rival == null
                ? GlassCard(
                    color: const Color(0xF0141414),
                    radius: 32,
                    padding: const EdgeInsets.all(20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      HandNote('siz birinchilardansiz!', size: 26),
                      const SizedBox(height: 8),
                      Text(
                        "Ligangizda hali boshqa o'yinchi yo'q. Do'stlaringizni chaqiring — ular kirishi bilan shu yerda paydo bo'ladi.",
                        textAlign: TextAlign.center,
                        style: body(14, color: QC.textSoft, height: 1.4),
                      ),
                    ]),
                  )
                : _RivalSheet(
                    rival: rival,
                    rivals: g.rivals,
                    myPower: g.power,
                    onSelect: (id) => setState(() => _selected = id),
                  ),
          ),
      ]);
    });
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? QC.lime : QC.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? QC.lime : QC.glassBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? QC.bg : QC.textSoft,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: body(
                12,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? QC.bg : QC.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CastleMarker extends StatelessWidget {
  const _CastleMarker({required this.at, required this.rival, required this.selected, required this.onTap});

  final Offset at;
  final Rival rival;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: at.dx - 60,
      top: at.dy - 100,
      width: 120,
      height: 130,
      child: Semantics(
        button: true,
        label: '${rival.name} qal\'asini tanlash',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
            if (selected) const Positioned(bottom: 6, child: PulseRing()),
            Positioned(
              top: 0,
              child: selected
                  ? Transform.rotate(
                      angle: -0.14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        decoration: BoxDecoration(
                          color: QC.lime,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: QC.bg, width: 2),
                          boxShadow: const [BoxShadow(color: QC.bg, offset: Offset(0, 5))],
                        ),
                        child: Text('nishon: ${rival.name}!', style: hand(22, color: QC.bg)),
                      ),
                    )
                  : _Tag(text: '${rival.name} · Lv ${rival.castleLevel}', color: rival.color),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: QC.bg, width: 2),
          boxShadow: const [BoxShadow(color: QC.bg, offset: Offset(0, 3))],
        ),
        child: Text(text, style: display(12, color: QC.bg, letterSpacing: 0)),
      );
}

class _RivalSheet extends StatelessWidget {
  const _RivalSheet({required this.rival, required this.rivals, required this.myPower, required this.onSelect});

  final Rival rival;
  final List<Rival> rivals;
  final double myPower;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xF0141414),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: QC.glassBorder),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, -10))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: QC.outline, borderRadius: BorderRadius.circular(999))),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: rivals
                .map((r) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(r.name),
                        selected: r.id == rival.id,
                        onSelected: (_) => onSelect(r.id),
                        labelStyle: body(13, weight: FontWeight.w600, color: r.id == rival.id ? QC.bg : QC.textSoft),
                        selectedColor: QC.lime,
                        backgroundColor: QC.surface2,
                        showCheckmark: false,
                        shape: const StadiumBorder(),
                        side: BorderSide.none,
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Avatar(name: rival.name, color: rival.color, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${rival.name}ning qal'asi · Lv ${rival.castleLevel}", style: display(18), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text.rich(TextSpan(style: body(13, color: QC.muted), children: [
                const TextSpan(text: 'Siz '),
                TextSpan(text: myPower.toStringAsFixed(1), style: const TextStyle(color: QC.lime, fontWeight: FontWeight.w700)),
                const TextSpan(text: ' va u '),
                TextSpan(text: rival.power.toStringAsFixed(1), style: TextStyle(color: rival.color, fontWeight: FontWeight.w700)),
                TextSpan(text: ' km · ${rival.ownTiles} katak'),
              ])),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        LimeButton(
          label: rival.isFlagged ? 'Bayrog\'ingiz ostida' : 'Hujum qilish',
          icon: Icons.bolt_rounded,
          height: 58,
          onPressed: rival.isFlagged ? null : () => startAttack(context, rival),
        ),
      ]),
    );
  }
}
