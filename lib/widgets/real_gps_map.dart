import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../game/game_state.dart';
import '../game/models.dart';
import '../screens/attack_result_screen.dart';
import '../theme.dart';
import 'common.dart';

/// Regional coordinate centers in Uzbekistan
const Map<String, LatLng> regionCoordinates = {
  'Toshkent shahri': LatLng(41.311081, 69.279737),
  'Toshkent viloyati': LatLng(41.2858, 69.3400),
  'Samarqand viloyati': LatLng(39.6542, 66.9597),
  'Buxoro viloyati': LatLng(39.7681, 64.4556),
  'Farg\'ona viloyati': LatLng(40.3842, 71.7843),
  'Andijon viloyati': LatLng(40.7821, 72.3442),
  'Namangan viloyati': LatLng(40.9983, 71.6726),
  'Qashqadaryo viloyati': LatLng(38.8606, 65.7891),
  'Surxondaryo viloyati': LatLng(37.2286, 67.2753),
  'Xorazm viloyati': LatLng(41.5545, 60.6313),
  'Jizzax viloyati': LatLng(40.1158, 67.8422),
  'Navoiy viloyati': LatLng(40.0844, 65.3792),
  'Sirdaryo viloyati': LatLng(40.8373, 68.6618),
  'Qoraqalpog\'iston Respublikasi': LatLng(42.4602, 59.6166),
};

class RealGpsMapWidget extends StatefulWidget {
  const RealGpsMapWidget({super.key});

  @override
  State<RealGpsMapWidget> createState() => _RealGpsMapWidgetState();
}

class _RealGpsMapWidgetState extends State<RealGpsMapWidget> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  StreamSubscription<Position>? _posSub;
  final List<LatLng> _walkTrack = [];
  String _selectedTerritory = 'own'; // 'own', 'ali', 'madina', 'clan'
  bool _trackingActive = true;

  late final AnimationController _pulseAnim =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _pulseAnim.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          _generateMockTrackIfNeeded(_currentPosition!);
        });
      }
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((p) {
        if (!mounted) return;
        setState(() {
          _currentPosition = LatLng(p.latitude, p.longitude);
          _walkTrack.add(_currentPosition!);
        });
      });
    } catch (_) {}
  }

  void _generateMockTrackIfNeeded(LatLng center) {
    if (_walkTrack.isNotEmpty) return;
    // Initial walk polygon representing recently conquered real area
    const offset = 0.003;
    _walkTrack.addAll([
      LatLng(center.latitude - offset, center.longitude - offset),
      LatLng(center.latitude + offset * 0.8, center.longitude - offset * 1.2),
      LatLng(center.latitude + offset * 1.4, center.longitude + offset * 0.5),
      LatLng(center.latitude - offset * 0.5, center.longitude + offset * 1.1),
      LatLng(center.latitude - offset, center.longitude - offset),
    ]);
  }

  LatLng _getCenter(GameState g) {
    if (_currentPosition != null) return _currentPosition!;
    return regionCoordinates[g.league] ?? const LatLng(41.311081, 69.240562);
  }

  void _recenter(LatLng pos) {
    _mapController.move(pos, 15.2);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    final center = _getCenter(g);
    _generateMockTrackIfNeeded(center);

    // Realistic neighboring zones in the city
    final aliCenter = LatLng(center.latitude + 0.0065, center.longitude + 0.0075);
    final madinaCenter = LatLng(center.latitude - 0.007, center.longitude - 0.008);
    final clanWarCenter = LatLng(center.latitude + 0.004, center.longitude - 0.006);

    // Conquered Polygons
    final ownPolygon = [
      LatLng(center.latitude - 0.0035, center.longitude - 0.0035),
      LatLng(center.latitude + 0.0030, center.longitude - 0.0040),
      LatLng(center.latitude + 0.0045, center.longitude + 0.0025),
      LatLng(center.latitude - 0.0020, center.longitude + 0.0040),
    ];

    final aliPolygon = [
      LatLng(aliCenter.latitude - 0.0030, aliCenter.longitude - 0.0030),
      LatLng(aliCenter.latitude + 0.0025, aliCenter.longitude - 0.0035),
      LatLng(aliCenter.latitude + 0.0035, aliCenter.longitude + 0.0025),
      LatLng(aliCenter.latitude - 0.0020, aliCenter.longitude + 0.0035),
    ];

    final madinaPolygon = [
      LatLng(madinaCenter.latitude - 0.0032, madinaCenter.longitude - 0.0032),
      LatLng(madinaCenter.latitude + 0.0030, madinaCenter.longitude - 0.0030),
      LatLng(madinaCenter.latitude + 0.0038, madinaCenter.longitude + 0.0030),
      LatLng(madinaCenter.latitude - 0.0025, madinaCenter.longitude + 0.0035),
    ];

    final clanWarPolygon = [
      LatLng(clanWarCenter.latitude - 0.0040, clanWarCenter.longitude - 0.0040),
      LatLng(clanWarCenter.latitude + 0.0038, clanWarCenter.longitude - 0.0042),
      LatLng(clanWarCenter.latitude + 0.0045, clanWarCenter.longitude + 0.0038),
      LatLng(clanWarCenter.latitude - 0.0035, clanWarCenter.longitude + 0.0045),
    ];

    final Rival selectedRival = g.rivals.firstWhere(
      (r) => r.id == _selectedTerritory,
      orElse: () => g.rivals.isNotEmpty ? g.rivals.first : Rival(id: 'ali', name: 'Ali', color: QC.blue, power: 3.1, ownTiles: 31, conqueredTiles: 4, castleLevel: 2),
    );

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14.8,
            minZoom: 10,
            maxZoom: 18.5,
          ),
          children: [
            // CARTO Dark Matter Retina tiles when CARTO_API_KEY is supplied via --dart-define;
            // falls back to dark-inverted OpenStreetMap tiles so clones without a key still render cleanly.
            if (kCartoApiKey.isNotEmpty)
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}{r}.png?key=$kCartoApiKey',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'uz.qadamqala.qadam_qala',
                retinaMode: RetinaMode.isHighDensity(context),
              )
            else
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'uz.qadamqala.qadam_qala',
                tileBuilder: (context, tileWidget, tile) => ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    -0.7, 0, 0, 0, 178,
                    0, -0.7, 0, 0, 178,
                    0, 0, -0.7, 0, 178,
                    0, 0, 0, 1, 0,
                  ]),
                  child: tileWidget,
                ),
              ),

            // Captured Territories on Real Streets
            PolygonLayer(
              polygons: [
                // 1. O'z hududingiz (Neon Yashil)
                Polygon(
                  points: ownPolygon,
                  color: QC.lime.withAlpha(50),
                  borderColor: QC.lime,
                  borderStrokeWidth: 2.8,
                ),
                // 2. Alining hududi (Moviy)
                Polygon(
                  points: aliPolygon,
                  color: QC.blue.withAlpha(50),
                  borderColor: QC.blue,
                  borderStrokeWidth: 2.5,
                ),
                // 3. Madinaning hududi (Olovrang)
                Polygon(
                  points: madinaPolygon,
                  color: QC.orange.withAlpha(50),
                  borderColor: QC.orange,
                  borderStrokeWidth: 2.5,
                ),
                // 4. Klanlar urushi sektori (Qizil/Platina)
                Polygon(
                  points: clanWarPolygon,
                  color: const Color(0xFF7FE3D6).withAlpha(40),
                  borderColor: const Color(0xFF7FE3D6),
                  borderStrokeWidth: 2.0,
                ),
              ],
            ),

            // Walk Path (Real-time Walked Route GPS Track)
            if (_walkTrack.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _walkTrack,
                    color: QC.lime,
                    strokeWidth: 4.5,
                  ),
                ],
              ),

            // Castle Markers on Real Streets
            MarkerLayer(
              markers: [
                // Sizning Qal'angiz
                Marker(
                  point: center,
                  width: 90,
                  height: 90,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTerritory = 'own'),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, _) => Container(
                            width: 60 + _pulseAnim.value * 24,
                            height: 60 + _pulseAnim.value * 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: QC.lime.withAlpha((40 * (1 - _pulseAnim.value)).toInt()),
                              border: Border.all(color: QC.lime, width: 1.5),
                            ),
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: QC.lime,
                            shape: BoxShape.circle,
                            border: Border.all(color: QC.bg, width: 3),
                            boxShadow: const [BoxShadow(color: QC.lime, blurRadius: 10)],
                          ),
                          child: const Icon(Icons.castle_rounded, color: QC.bg, size: 24),
                        ),
                        Positioned(
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: QC.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: QC.lime),
                            ),
                            child: Text(
                              'Siz · Lv ${g.castleLevel}',
                              style: body(11, color: QC.lime, weight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Alining Minorasi
                Marker(
                  point: aliCenter,
                  width: 80,
                  height: 80,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTerritory = 'ali'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: QC.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: QC.bg, width: 3),
                            boxShadow: const [BoxShadow(color: QC.blue, blurRadius: 8)],
                          ),
                          child: const Icon(Icons.fort_rounded, color: Colors.white, size: 20),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: QC.bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: QC.blue),
                          ),
                          child: Text('Ali · Lv 2', style: body(10, color: QC.blue, weight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),

                // Madinaning Qal'asi
                Marker(
                  point: madinaCenter,
                  width: 80,
                  height: 80,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTerritory = 'madina'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: QC.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: QC.bg, width: 3),
                            boxShadow: const [BoxShadow(color: QC.orange, blurRadius: 8)],
                          ),
                          child: const Icon(Icons.castle_outlined, color: Colors.white, size: 20),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: QC.bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: QC.orange),
                          ),
                          child: Text('Madina · Lv 5', style: body(10, color: QC.orange, weight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),

                // Klan Maydoni
                Marker(
                  point: clanWarCenter,
                  width: 90,
                  height: 80,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTerritory = 'clan'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7FE3D6),
                            shape: BoxShape.circle,
                            border: Border.all(color: QC.bg, width: 3),
                          ),
                          child: const Icon(Icons.groups_rounded, color: QC.bg, size: 22),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: QC.bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF7FE3D6)),
                          ),
                          child: Text('Klan jangi', style: body(10, color: const Color(0xFF7FE3D6), weight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Floating Action Buttons (GPS Recenter, Track Toggle)
        Positioned(
          right: 18,
          top: 155,
          child: Column(
            children: [
              RoundIconButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Meni topish',
                onPressed: () => _recenter(center),
              ),
              const SizedBox(height: 10),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _trackingActive ? QC.lime : QC.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: QC.glassBorder),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.directions_walk_rounded,
                    color: _trackingActive ? QC.bg : QC.text,
                    size: 24,
                  ),
                  tooltip: "Yurish yo'lini yozish",
                  onPressed: () {
                    setState(() => _trackingActive = !_trackingActive);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_trackingActive ? "GPS yo'li yozilmoqda!" : "GPS yozish to'xtatildi"),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Bottom Selected Territory Info Card
        Positioned(
          left: 14,
          right: 14,
          bottom: 96 + MediaQuery.paddingOf(context).bottom,
          child: _selectedTerritory == 'own'
              ? GlassCard(
                  color: const Color(0xF2141414),
                  radius: 28,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(color: QC.lime, shape: BoxShape.circle),
                            child: const Icon(Icons.castle_rounded, color: QC.bg, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Sizning shahar hududingiz", style: display(17)),
                                const SizedBox(height: 2),
                                Text(
                                  "${g.ownTiles} katak · ${(g.ownTiles * 0.15).toStringAsFixed(1)} km² himoyalangan",
                                  style: body(13, color: QC.muted),
                                ),
                              ],
                            ),
                          ),
                          Chip2('${g.castleLevel}-daraja', background: QC.lime, foreground: QC.bg),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Yuring — yurgan ko'chalaringiz yashil chiziq bilan chiziladi va sizning hududingizga aylanadi!",
                              style: body(12, color: QC.textSoft),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : _selectedTerritory == 'clan'
                  ? GlassCard(
                      color: const Color(0xF2141414),
                      radius: 28,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: const BoxDecoration(color: Color(0xFF7FE3D6), shape: BoxShape.circle),
                                child: const Icon(Icons.groups_rounded, color: QC.bg, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Markaziy klan sektori", style: display(17)),
                                    Text("Hozirda 4 ta klan da'vogarlik qilmoqda", style: body(13, color: QC.muted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LimeButton(
                            label: "Klan bilan hududni bosib olish",
                            icon: Icons.flag_rounded,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Klaningiz bilan ushbu sektorga da'vogarlik qildingiz!")),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  : GlassCard(
                      color: const Color(0xF2141414),
                      radius: 28,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: selectedRival.color,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    selectedRival.name.isNotEmpty ? selectedRival.name[0] : '?',
                                    style: display(18, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${selectedRival.name}ning qal'asi · Lv ${selectedRival.castleLevel}", style: display(17)),
                                    Text(
                                      "Siz ${g.power.toStringAsFixed(1)} km · U ${selectedRival.power.toStringAsFixed(1)} km",
                                      style: body(13, color: QC.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          LimeButton(
                            label: "${selectedRival.name} hududiga hujum",
                            icon: Icons.bolt_rounded,
                            onPressed: () async {
                              final err = g.attackBlockReason(selectedRival);
                              if (err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                return;
                              }
                              final res = await runWithSpinner(context, () => g.attack(selectedRival));
                              if (res == null || !context.mounted) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => AttackResultScreen(result: res)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}
