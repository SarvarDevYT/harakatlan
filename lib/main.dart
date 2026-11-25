import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'game/game_state.dart';
import 'game/remote.dart';
import 'game/step_service.dart';
import 'screens/clan_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/territory_screen.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // Firebase (push notifications). Needs google-services.json / GoogleService-Info.plist.
  try {
    await Firebase.initializeApp();
    await NotificationService.init();
    await NotificationService.requestPermission();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  final game = GameState();
  // Draw the first frame straight away; saved progress loads behind a splash.
  runApp(ChangeNotifierProvider.value(value: game, child: const HarakatlanApp()));
  try {
    if (kOnline) {
      final remote = await Remote.connect().timeout(const Duration(seconds: 15));
      await game.connect(remote).timeout(const Duration(seconds: 15));
      // Register FCM token so the server can push "you're under attack" alerts.
      final token = await NotificationService.getToken();
      if (token != null) {
        remote.saveFcmToken(token).catchError((_) {});
        NotificationService.onTokenRefresh((t) => remote.saveFcmToken(t).catchError((_) {}));
      }
    } else {
      await game.load().timeout(const Duration(seconds: 6));
    }
  } catch (e) {
    debugPrint('Harakatlan: could not start: $e');
    game.startWithoutSave();
  }
}

class HarakatlanApp extends StatelessWidget {
  const HarakatlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final loaded = context.select<GameState, bool>((g) => g.loaded);
    final registered = context.select<GameState, bool>((g) => g.registered);
    return MaterialApp(
      title: 'Harakatlan',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: !loaded
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : registered
              ? const AppShell()
              : const OnboardingScreen(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  late final StepService _steps = StepService(context.read<GameState>());

  @override
  void initState() {
    super.initState();
    _steps.start();
  }

  @override
  void dispose() {
    _steps.dispose();
    super.dispose();
  }

  void _goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(goTo: _goTo),
          const MapScreen(),
          const TerritoryScreen(),
          const ClanScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _NavBar(index: _tab, onTap: _goTo),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.directions_walk_rounded, 'Bugun'),
    (Icons.map_rounded, 'Xarita'),
    (Icons.castle_rounded, 'Hudud'),
    (Icons.groups_rounded, 'Klan'),
    (Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: QC.navBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: QC.glassBorder),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 10))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_items.length, (i) {
            final selected = i == index;
            final (icon, label) = _items[i];
            return Semantics(
              button: true,
              selected: selected,
              label: label,
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  height: 52,
                  padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 12),
                  decoration: BoxDecoration(
                    color: selected ? QC.lime : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(children: [
                    Icon(icon, size: 22, color: selected ? QC.bg : QC.textSoft),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      Text(label, style: body(14, color: QC.bg, weight: FontWeight.w700)),
                    ],
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
