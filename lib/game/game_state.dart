import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'remote.dart';

/// All game rules and the player's progress.
///
/// Two modes:
///  * **online** – Firebase. The server (functions/src) is the only judge of
///    distance, attacks, clans and rewards; this class mirrors its data.
///  * **offline demo** – everything runs on the phone with sample rivals.
///
/// Rules (agreed in the design):
///  * Walking earns land: every [tilesPerKm] km = one new tile, placed in the evening.
///  * Own land and total km never go down, whatever happens in battle.
///  * Attack power = km walked today. Beating a weaker rival gives bonus
///    ("conquered") tiles; the rival only loses from their conquered layer.
///  * A beaten rival carries a flag for 24 h and can't be hit again meanwhile.
class GameState extends ChangeNotifier {
  static const _prefsKey = 'qadam_qala_state_v1';
  static const strideMeters = 0.75;
  static const tilesPerKm = 1.0;
  static const maxAttacksPerDay = 3;
  static const dailyGoalKm = 8.0;

  /// Tiles needed for each castle level (index 0 = level 1).
  static const levelThresholds = [0, 5, 15, 30, 50, 75, 105, 140, 180, 225];

  static const rewards = [
    Reward(id: 'neon_tower', title: 'Neon minora', kind: RewardKind.castleSkin, unlock: Tier.bronza),
    Reward(id: 'silver_crest', title: 'Kumush gerb', kind: RewardKind.emblem, unlock: Tier.kumush),
    Reward(id: 'gold_ring', title: 'Oltin halqa', kind: RewardKind.avatarFrame, unlock: Tier.oltin),
    Reward(id: 'bolt_flag', title: 'Chaqmoq bayroq', kind: RewardKind.flag, unlock: Tier.platina),
    Reward(id: 'diamond_tower', title: 'Olmos minora', kind: RewardKind.castleSkin, unlock: Tier.olmos),
    Reward(id: 'fire_trail', title: 'Olov izi', kind: RewardKind.mapEffect, unlock: Tier.afsona),
  ];

  SharedPreferences? _prefs;
  Remote? _remote;
  bool loaded = false;
  bool get online => _remote != null;

  // Player
  String playerName = '';
  bool get registered => playerName.isNotEmpty;
  double totalKm = 0; // lifetime, never decreases
  double todayKm = 0;
  int todaySteps = 0;
  String dayKey = _keyFor(DateTime.now());
  int ownTiles = 0; // placed, permanent
  int conqueredTiles = 0;
  int wins = 0;
  int attacksToday = 0;
  int? lastStepCounter; // raw pedometer value, to count steps taken while the app was closed
  Map<String, double> history = {}; // dayKey -> km
  Set<String> claimedRewards = {};
  String league = 'Toshkent shahri';
  List<Rival> rivals = [];
  Clan? clan;

  // Army: every km trains soldiers who defend the castle.
  static const infantryPerKm = 10;
  static const cavalryPerKm = 2;
  static const archersPerKm = 3;
  int infantry = 0;
  int cavalry = 0;
  int archers = 0;
  double troopKm = 0;
  int defense = 20; // 0..100 %
  int bombs = 0;
  List<String> accessories = [];
  List<String> ownedWeapons = [];
  DailyBattle? dailyBattle;
  int castleSeed = Random().nextInt(1000000);
  List<InboxItem> inbox = [];

  int get weaponBonusPower {
    var p = 0;
    for (final wid in ownedWeapons) {
      final w = allWeapons.where((x) => x.id == wid);
      if (w.isNotEmpty) p += w.first.bonusPower;
    }
    return p;
  }

  int get weaponBonusDefense {
    var d = 0;
    for (final wid in ownedWeapons) {
      final w = allWeapons.where((x) => x.id == wid);
      if (w.isNotEmpty) d += w.first.bonusDefense;
    }
    return d;
  }

  int get armyStrength => infantry + cavalry * 3 + archers * 2 + weaponBonusPower;
  int get totalDefense => (defense + weaponBonusDefense).clamp(0, 100);
  int get defensePower => (armyStrength * (1 + totalDefense / 100)).round();

  /// True when the phone has no step sensor (e.g. the simulator): the app
  /// then shows a demo button to add distance by hand.
  bool stepSensorMissing = false;

  // Online bookkeeping
  Timer? _refreshTimer;
  Timer? _reportTimer;

  // ---------- derived values ----------

  int get earnedTiles => (totalKm * tilesPerKm).floor();
  int get pendingTiles => max(0, earnedTiles - ownTiles);
  int get totalTiles => ownTiles + conqueredTiles;
  double get power => todayKm;
  int get attacksLeft => max(0, maxAttacksPerDay - attacksToday);

  int get castleLevel {
    var level = 1;
    for (var i = 0; i < levelThresholds.length; i++) {
      if (totalTiles >= levelThresholds[i]) level = i + 1;
    }
    return level;
  }

  int get nextLevelTiles =>
      castleLevel < levelThresholds.length ? levelThresholds[castleLevel] : levelThresholds.last;

  int get rankPoints => max(0, (castleLevel - 1) * 100 + wins * 15 + totalKm.floor());

  Tier get tier {
    var t = Tier.bronza;
    for (final candidate in Tier.values) {
      if (rankPoints >= candidate.minPoints) t = candidate;
    }
    return t;
  }

  Tier? get nextTier => tier.index + 1 < Tier.values.length ? Tier.values[tier.index + 1] : null;

  /// I, II or III inside the current tier. Starts at I.
  String get division {
    final next = nextTier;
    if (next == null) return '';
    final span = next.minPoints - tier.minPoints;
    final into = rankPoints - tier.minPoints;
    if (into < span / 3) return 'I';
    if (into < span * 2 / 3) return 'II';
    return 'III';
  }

  double get tierProgress {
    final next = nextTier;
    if (next == null) return 1;
    return ((rankPoints - tier.minPoints) / (next.minPoints - tier.minPoints)).clamp(0, 1).toDouble();
  }

  bool isUnlocked(Reward r) => tier.index >= r.unlock.index;

  /// km per day for the last 7 days, oldest first.
  List<MapEntry<DateTime, double>> get lastWeek {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
      return MapEntry(d, history[_keyFor(d)] ?? 0);
    });
  }

  // ---------- loading ----------

  /// Offline demo: progress saved on the phone.
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_prefsKey);
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt save: start fresh rather than crash.
      }
    }
    if (rivals.isEmpty) rivals = _seedRivals();
    _rollDayIfNeeded();
    loaded = true;
    notifyListeners();
  }

  /// Online: load the player's profile from the game server.
  Future<void> connect(Remote remote) async {
    _remote = remote;
    _prefs = await SharedPreferences.getInstance();
    lastStepCounter = _prefs!.getInt('${_prefsKey}_counter');
    dayKey = _tashkentDayKey();
    if (remote.hasAccount) {
      try {
        await refresh();
      } on RemoteError catch (e) {
        debugPrint('refresh failed: $e');
      }
    }
    loaded = true;
    notifyListeners();
    // Keep rivals, clan and war score fresh while the app is open.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => refresh().catchError((_) {}));
  }

  /// Pulls the latest profile, clan and rivals from the server.
  Future<void> refresh() async {
    final r = _remote;
    if (r == null || !r.hasAccount) return;
    final s = await r.call('state');
    _applyServerProfile(Map<String, dynamic>.from(s['profile'] as Map));
    _applyServerClan(s['clan'] == null ? null : Map<String, dynamic>.from(s['clan'] as Map));
    notifyListeners();
    await refreshRivals();
  }

  /// Fallback when saved data can't be read: play with fresh, unsaved state.
  void startWithoutSave() {
    if (rivals.isEmpty) rivals = _seedRivals();
    loaded = true;
    notifyListeners();
  }

  void _applyServerProfile(Map<String, dynamic> d) {
    playerName = d['name'] as String? ?? '';
    totalKm = max(totalKm, (d['totalKm'] as num?)?.toDouble() ?? 0);
    final sameDay = (d['dayKey'] as String? ?? dayKey) == _tashkentDayKey();
    todayKm = sameDay ? max(todayKm, (d['todayKm'] as num?)?.toDouble() ?? 0) : 0;
    todaySteps = sameDay ? max(todaySteps, (d['todaySteps'] as num?)?.toInt() ?? 0) : 0;
    attacksToday = sameDay ? (d['attacksToday'] as num?)?.toInt() ?? 0 : 0;
    ownTiles = (d['ownTiles'] as num?)?.toInt() ?? 0;
    conqueredTiles = (d['conqueredTiles'] as num?)?.toInt() ?? 0;
    wins = (d['wins'] as num?)?.toInt() ?? 0;
    history = ((d['history'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    claimedRewards = ((d['claimedRewards'] as List?) ?? []).cast<String>().toSet();
    infantry = (d['infantry'] as num?)?.toInt() ?? 0;
    cavalry = (d['cavalry'] as num?)?.toInt() ?? 0;
    defense = (d['defense'] as num?)?.toInt() ?? 20;
    bombs = (d['bombs'] as num?)?.toInt() ?? 0;
    accessories = ((d['accessories'] as List?) ?? []).cast<String>();
    castleSeed = (d['castleSeed'] as num?)?.toInt() ?? castleSeed;
    inbox = ((d['inbox'] as List?) ?? []).map((e) => InboxItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Marks the "you were attacked" messages as seen.
  Future<void> readInbox() async {
    inbox = [];
    notifyListeners();
    final r = _remote;
    if (r != null) {
      try {
        await r.call('readInbox');
      } catch (_) {}
    }
  }

  void _applyServerClan(Map<String, dynamic>? d) {
    if (d == null) {
      clan = null;
      return;
    }
    const palette = [Color(0xFFD4FF3F), Color(0xFF8A644E), Color(0xFF3E7A6B), Color(0xFF6E94E0), Color(0xFFB0702E)];
    final leader = d['leaderUid'] as String?;
    final list = ((d['members'] as List?) ?? []).cast<Map>();
    final members = [
      for (var i = 0; i < list.length; i++)
        ClanMember(
          name: list[i]['name'] as String? ?? '?',
          role: list[i]['uid'] == leader ? 'Lider' : "A'zo",
          weekKm: (list[i]['weekKm'] as num?)?.toDouble() ?? 0,
          color: palette[i % palette.length],
        ),
    ];
    final w = d['war'] as Map?;
    clan = Clan(
      id: d['id'] as String?,
      inviteCode: d['inviteCode'] as String?,
      name: d['name'] as String? ?? '',
      tag: d['tag'] as String? ?? '',
      level: (d['level'] as num?)?.toInt() ?? 1,
      members: members,
      score: ((w == null ? d['score'] : w['ourScore']) as num?)?.toDouble() ?? 0,
      enemyName: w == null ? 'Raqib kutilmoqda' : w['enemyName'] as String,
      enemyScore: w == null ? 0 : (w['enemyScore'] as num).toDouble(),
      warEnds: w == null ? _nextMonday() : DateTime.fromMillisecondsSinceEpoch((w['endsAt'] as num).toInt()),
      lastWarDay: d['pushedToday'] == true ? dayKey : null,
    );
  }

  // ---------- saving (offline) ----------

  void _save() {
    if (online) {
      // The server keeps the progress; the phone only remembers the raw
      // step-sensor value so steps walked while the app was closed still count.
      final c = lastStepCounter;
      if (c != null) _prefs?.setInt('${_prefsKey}_counter', c);
      return;
    }
    _prefs?.setString(_prefsKey, jsonEncode(_toJson()));
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  // ---------- actions ----------

  Future<void> register(String name) async {
    final r = _remote;
    if (r != null) {
      final res = await r.register(name.trim());
      _applyServerProfile(Map<String, dynamic>.from(res['profile'] as Map));
      notifyListeners();
      unawaited(refreshRivals());
      return;
    }
    playerName = name.trim();
    _changed();
  }

  Future<void> changeLeague(String newLeague) async {
    league = newLeague;
    _prefs?.setString('player_league', newLeague);
    notifyListeners();
    final r = _remote;
    if (r != null && r.hasAccount) {
      try {
        await r.call('rename', {'league': newLeague});
        await refreshRivals();
      } catch (_) {}
    }
  }

  /// Called with the raw cumulative value from the Android step sensor.
  void onStepCounter(int counter) {
    _rollDayIfNeeded();
    final last = lastStepCounter;
    lastStepCounter = counter;
    if (last == null) {
      _save();
      return;
    }
    // The counter restarts after a phone reboot: then everything counted so far is new.
    final delta = counter >= last ? counter - last : counter;
    if (delta > 0) addSteps(delta);
  }

  /// Called with today's totals from Apple Health.
  void onHealthToday({required double km, required int steps}) {
    _rollDayIfNeeded();
    if (steps > todaySteps) todaySteps = steps;
    if (km > todayKm) {
      addDistance(km - todayKm, countSteps: false);
    } else {
      notifyListeners();
    }
  }

  void addSteps(int steps) {
    todaySteps += steps;
    addDistance(steps * strideMeters / 1000, countSteps: false);
  }

  void addDistance(double km, {bool countSteps = true}) {
    _rollDayIfNeeded();
    if (countSteps) todaySteps += (km * 1000 / strideMeters).round();
    totalKm += km;
    todayKm += km;
    history[dayKey] = todayKm;
    if (!online) {
      infantry += (totalKm * infantryPerKm).floor() - (troopKm * infantryPerKm).floor();
      cavalry += (totalKm * cavalryPerKm).floor() - (troopKm * cavalryPerKm).floor();
      archers += (totalKm * archersPerKm).floor() - (troopKm * archersPerKm).floor();
      troopKm = totalKm;
    }
    _changed();
    _scheduleReport();
  }

  /// Online: tell the server today's km, at most every few seconds.
  void _scheduleReport() {
    final r = _remote;
    if (r == null) return;
    _reportTimer?.cancel();
    _reportTimer = Timer(const Duration(seconds: 3), () async {
      try {
        await r.call('reportDistance', {'todayKm': todayKm, 'todaySteps': todaySteps});
      } catch (e) {
        debugPrint('reportDistance failed: $e');
      }
    });
  }

  void setStepSensorMissing() {
    if (stepSensorMissing) return;
    stepSensorMissing = true;
    notifyListeners();
  }

  /// Places every tile earned by walking. Returns how many were placed.
  Future<int> placeTiles() async {
    final r = _remote;
    if (r != null) {
      final res = await r.call('placeTiles');
      await refresh();
      return (res['placed'] as num?)?.toInt() ?? 0;
    }
    final n = pendingTiles;
    if (n == 0) return 0;
    ownTiles += n;
    _changed();
    return n;
  }

  Future<void> refreshRivals() async {
    final r = _remote;
    if (r == null) return;
    try {
      final res = await r.call('getNeighbors');
      const palette = [Color(0xFF6E94E0), Color(0xFFF2B36B), Color(0xFF3E9A8A), Color(0xFFB07FE0), Color(0xFFE07F9A)];
      final list = (res['players'] as List? ?? []).cast<Map>();

      // Filter out test players and ping accounts
      final filteredList = list.where((p) {
        final n = (p['name'] as String? ?? '').toLowerCase();
        final id = (p['uid'] as String? ?? '').toLowerCase();
        return !n.startsWith('test_') && !n.contains('ping') && !id.contains('ping') && n.isNotEmpty;
      }).toList();

      final fetched = [
        for (var i = 0; i < filteredList.length; i++)
          Rival(
            id: filteredList[i]['uid'] as String,
            name: filteredList[i]['name'] as String,
            color: palette[i % palette.length],
            power: (filteredList[i]['power'] as num).toDouble(),
            ownTiles: (filteredList[i]['ownTiles'] as num).toInt(),
            conqueredTiles: (filteredList[i]['conqueredTiles'] as num).toInt(),
            castleLevel: (filteredList[i]['castleLevel'] as num).toInt(),
            flaggedUntil: filteredList[i]['flaggedUntil'] == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch((filteredList[i]['flaggedUntil'] as num).toInt()),
            infantry: (filteredList[i]['infantry'] as num?)?.toInt() ?? 0,
            cavalry: (filteredList[i]['cavalry'] as num?)?.toInt() ?? 0,
            defense: (filteredList[i]['defense'] as num?)?.toInt() ?? 20,
            castleSeed: (filteredList[i]['castleSeed'] as num?)?.toInt() ?? 0,
            accessories: ((filteredList[i]['accessories'] as List?) ?? []).cast<String>(),
          ),
      ];

      final seed = _seedRivals();
      final combined = [...fetched];
      for (final s in seed) {
        if (!combined.any((c) => c.id == s.id || c.name.toLowerCase() == s.name.toLowerCase())) {
          combined.add(s);
        }
      }
      rivals = combined;
      notifyListeners();
    } catch (e) {
      debugPrint('getNeighbors failed: $e');
    }
  }

  String? attackBlockReason(Rival r) {
    if (r.isFlagged) return '${r.name} hozir bayroq ostida, keyinroq urining';
    if (attacksLeft == 0) return 'Bugungi hujumlar tugadi, ertaga qayting';
    if (infantry + cavalry <= 0) return "Qo'shiningiz yo'q: yuring, har km 10 piyoda va 2 otliq beradi";
    return null;
  }

  Future<AttackResult> attack(Rival r) async {
    final remote = _remote;
    if (remote != null) {
      _reportTimer?.cancel();
      await remote.call('reportDistance', {'todayKm': todayKm, 'todaySteps': todaySteps});
      final res = await remote.call('attack', {'defenderUid': r.id});
      unawaited(refresh());
      return AttackResult(
        won: res['won'] as bool,
        gained: (res['gained'] as num).toInt(),
        rivalName: res['rivalName'] as String,
        rivalColor: r.color,
        myPower: (res['myPower'] as num).toDouble(),
        rivalPower: (res['rivalPower'] as num).toDouble(),
        rivalOwnTiles: (res['rivalOwnTiles'] as num).toInt(),
        rivalCastleSeed: (res['rivalCastleSeed'] as num?)?.toInt() ?? r.castleSeed,
        rivalAccessories: ((res['rivalAccessories'] as List?) ?? []).cast<String>(),
        bombsUsed: (res['bombsUsed'] as num?)?.toInt() ?? 0,
        bombsWon: (res['bombsWon'] as num?)?.toInt() ?? 0,
        reward: res['reward'] as String?,
        defenseLost: (res['defenseLost'] as num?)?.toInt() ?? 0,
        myInfantry: (res['my']?['infantry'] as num?)?.toInt() ?? 0,
        myCavalry: (res['my']?['cavalry'] as num?)?.toInt() ?? 0,
        enemyInfantry: (res['enemy']?['infantry'] as num?)?.toInt() ?? 0,
        enemyCavalry: (res['enemy']?['cavalry'] as num?)?.toInt() ?? 0,
        myLosses: ((res['myLosses']?['infantry'] as num?) ?? 0).toInt() + ((res['myLosses']?['cavalry'] as num?) ?? 0).toInt(),
        enemyLosses:
            ((res['enemyLosses']?['infantry'] as num?) ?? 0).toInt() + ((res['enemyLosses']?['cavalry'] as num?) ?? 0).toInt(),
      );
    }
    _rollDayIfNeeded();
    attacksToday++;
    // Same rules as the server (server/lib/rules.ts).
    final used = min(bombs, 3);
    final morale = 1 + min(1.0, todayKm * 0.05);
    final atk = ((armyStrength + used * 15) * morale).round();
    final def = r.defensePower;
    final won = atk > def;
    int loss(int n, double share) => min(n, (n * share).ceil());
    final aShare = won ? 0.15 : 0.4, dShare = won ? 0.4 : 0.15;
    final myInf = infantry, myCav = cavalry, enInf = r.infantry, enCav = r.cavalry;
    final myLost = loss(infantry, aShare) + loss(cavalry, aShare);
    final enLost = loss(r.infantry, dShare) + loss(r.cavalry, dShare);
    infantry -= loss(myInf, aShare);
    cavalry -= loss(myCav, aShare);
    r.infantry -= loss(enInf, dShare);
    r.cavalry -= loss(enCav, dShare);
    bombs -= used;
    var gained = 0, bombsWon = 0, defenseLost = 0;
    String? reward;
    if (won) {
      gained = ((atk - def) / 10).round().clamp(1, 10);
      conqueredTiles += gained;
      wins++;
      defense = min(100, defense + 5);
      bombsWon = def >= atk * 0.7 ? 2 : 1;
      bombs += bombsWon;
      const all = ['gold_roof', 'banner_tall', 'cannon', 'torches', 'crystal_spire', 'dragon_flag', 'moat', 'shield_wall'];
      final missing = all.where((a) => !accessories.contains(a)).toList();
      if (missing.isNotEmpty) {
        reward = missing[Random().nextInt(missing.length)];
        accessories = [...accessories, reward];
      }
      r.conqueredTiles = max(0, r.conqueredTiles - gained);
      defenseLost = min(r.defense, 10);
      r.defense -= defenseLost;
      r.flaggedUntil = DateTime.now().add(const Duration(hours: 24));
    }
    final result = AttackResult(
      won: won,
      gained: gained,
      rivalName: r.name,
      rivalColor: r.color,
      myPower: atk.toDouble(),
      rivalPower: def.toDouble(),
      rivalOwnTiles: r.ownTiles,
      rivalCastleSeed: r.castleSeed,
      rivalAccessories: r.accessories,
      bombsUsed: used,
      bombsWon: bombsWon,
      reward: reward,
      defenseLost: defenseLost,
      myInfantry: myInf,
      myCavalry: myCav,
      enemyInfantry: enInf,
      enemyCavalry: enCav,
      myLosses: myLost,
      enemyLosses: enLost,
    );
    _changed();
    return result;
  }

  Future<void> claimReward(Reward reward) async {
    if (!isUnlocked(reward)) return;
    final r = _remote;
    if (r != null) {
      await r.call('claimReward', {'rewardId': reward.id});
      await refresh();
      return;
    }
    claimedRewards.add(reward.id);
    _changed();
  }

  Future<void> createClan(String name, String tag) async {
    final r = _remote;
    if (r != null) {
      await r.call('createClan', {'name': name, 'tag': tag});
      await refresh();
      return;
    }
    clan = Clan(
      name: name.trim().toUpperCase(),
      tag: tag.trim().toUpperCase(),
      members: [
        ClanMember(name: playerName, role: 'Lider', weekKm: _weekKm, color: const Color(0xFFD4FF3F)),
      ],
      enemyName: 'TEMIR TOVON',
      enemyScore: 40 + Random().nextInt(40).toDouble(),
      warEnds: DateTime.now().add(const Duration(days: 3)),
    );
    _changed();
  }

  /// Online: join with a friend's invite code.
  Future<void> joinClan(String code) async {
    final r = _remote;
    if (r == null) throw const RemoteError("Klanga qo'shilish uchun internet rejimi kerak");
    await r.call('joinClan', {'inviteCode': code});
    await refresh();
  }

  /// Foydalanuvchilarni qidirish (online yoki offline)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final r = _remote;
    if (r != null) {
      try {
        final res = await r.call('searchUsers', {'query': q});
        final list = (res['users'] as List? ?? []).cast<Map>();
        return list.map((m) => Map<String, dynamic>.from(m)).toList();
      } catch (e) {
        debugPrint('searchUsers failed: $e');
      }
    }

    // Offline / zaxira qidiruv (rivals + do'stlar)
    final allOffline = [
      ...rivals.map((rv) => {
            'uid': rv.id,
            'name': rv.name,
            'castleLevel': rv.castleLevel,
            'totalKm': rv.power * 5,
            'clanId': clan?.members.any((m) => m.name == rv.name) == true ? 'my_clan' : null,
          }),
      {'uid': 'jasur', 'name': 'Jasur', 'castleLevel': 3, 'totalKm': 42.0, 'clanId': null},
      {'uid': 'sardor', 'name': 'Sardor', 'castleLevel': 4, 'totalKm': 58.5, 'clanId': null},
      {'uid': 'dilnoza', 'name': 'Dilnoza', 'castleLevel': 2, 'totalKm': 19.2, 'clanId': null},
      {'uid': 'shahzod', 'name': 'Shahzod', 'castleLevel': 5, 'totalKm': 88.0, 'clanId': null},
    ];

    return allOffline
        .where((u) => (u['name'] as String).toLowerCase().contains(q) && u['name'] != playerName)
        .toList();
  }

  /// Do'stni to'g'ridan-to'g'ri klanga qo'shish
  Future<bool> addFriendToClan({required String name, String? uid}) async {
    final c = clan;
    if (c == null) return false;

    final r = _remote;
    if (r != null) {
      await r.call('addMemberToClan', {'targetUid': uid, 'targetName': name});
      await refresh();
      return true;
    }

    if (c.members.length >= Clan.maxMembers || name.trim().isEmpty) return false;
    if (c.members.any((m) => m.name.toLowerCase() == name.trim().toLowerCase())) return false;

    const palette = [Color(0xFF8A644E), Color(0xFF3E7A6B), Color(0xFF6E94E0), Color(0xFFB0702E)];
    c.members.add(ClanMember(
      name: name.trim(),
      role: "A'zo",
      weekKm: 0,
      color: palette[c.members.length % palette.length],
    ));
    _changed();
    return true;
  }

  /// Offline demo only: adds a pretend member.
  bool inviteFriend(String name) {
    final c = clan;
    if (online || c == null || c.members.length >= Clan.maxMembers || name.trim().isEmpty) return false;
    const palette = [Color(0xFF8A644E), Color(0xFF3E7A6B), Color(0xFF6E94E0), Color(0xFFB0702E)];
    c.members.add(ClanMember(
      name: name.trim(),
      role: "A'zo",
      weekKm: 0,
      color: palette[c.members.length % palette.length],
    ));
    _changed();
    return true;
  }

  Future<void> leaveClan() async {
    final r = _remote;
    if (r != null) {
      await r.call('leaveClan');
      await refresh();
      return;
    }
    clan = null;
    _changed();
  }

  bool get canPushClanWar => clan != null && clan!.lastWarDay != dayKey && todayKm > 0;

  /// Adds today's km to the clan war score (once a day).
  Future<double> pushClanWar() async {
    final c = clan;
    if (c == null || !canPushClanWar) return 0;
    final r = _remote;
    if (r != null) {
      _reportTimer?.cancel();
      await r.call('reportDistance', {'todayKm': todayKm, 'todaySteps': todaySteps});
      final res = await r.call('pushClanWar');
      await refresh();
      c.lastWarDay = dayKey;
      notifyListeners();
      return (res['added'] as num).toDouble();
    }
    c.score += todayKm;
    c.lastWarDay = dayKey;
    final me = c.members.where((m) => m.name == playerName);
    if (me.isNotEmpty) me.first.weekKm = _weekKm;
    _changed();
    return todayKm;
  }

  /// Offline: wipes the phone's save. Online: deletes the account on the server.
  Future<void> deleteAccount() async {
    final r = _remote;
    if (r != null) {
      await r.call('deleteAccount');
      await r.forget();
      _reset();
      notifyListeners();
      return;
    }
    final keepPrefs = _prefs;
    _reset();
    _prefs = keepPrefs;
    await _prefs?.remove(_prefsKey);
    rivals = _seedRivals();
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _reportTimer?.cancel();
    super.dispose();
  }

  // ---------- internals ----------

  double get _weekKm => lastWeek.fold(0.0, (sum, e) => sum + e.value);

  static String _keyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The server counts days in Tashkent time (UTC+5).
  static String _tashkentDayKey() => _keyFor(DateTime.now().toUtc().add(const Duration(hours: 5)));

  static DateTime _nextMonday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: 8 - now.weekday));
  }

  void _rollDayIfNeeded() {
    final today = online ? _tashkentDayKey() : _keyFor(DateTime.now());
    _ensureDailyBattle();
    if (today == dayKey) return;
    dayKey = today;
    todayKm = 0;
    todaySteps = 0;
    attacksToday = 0;
    _generateNewDailyBattle();
    if (online) return;
    // Sample rivals walked a new day too.
    final rnd = Random();
    for (final r in rivals) {
      r.power = double.parse((1 + rnd.nextDouble() * 7).toStringAsFixed(1));
      r.ownTiles += r.power.floor();
    }
    _save();
  }

  void _ensureDailyBattle() {
    final today = online ? _tashkentDayKey() : _keyFor(DateTime.now());
    if (dailyBattle == null || dailyBattle!.dayKey != today) {
      _generateNewDailyBattle();
    }
  }

  void _generateNewDailyBattle() {
    final today = online ? _tashkentDayKey() : _keyFor(DateTime.now());
    const bossNames = [
      'Qora Ritsar',
      'Afsonaviy Bahodir',
      'Temir Qoplon',
      'Cho\'l Bo\'risi',
      'Sulton Alp Arslon',
      'Qonxo\'r Qo\'mondon',
      'Yengilmas Botir',
    ];
    final rnd = Random();
    final name = bossNames[rnd.nextInt(bossNames.length)];

    // Dushman doim o'yinchidan kuchliroq bo'ladi!
    final myCurrentPower = max(armyStrength, 80);
    final targetPower = (myCurrentPower * 1.35).round();

    dailyBattle = DailyBattle(
      dayKey: today,
      bossName: name,
      bossPower: (todayKm + 4.5),
      bossInfantry: max(45, (targetPower * 0.4).round()),
      bossCavalry: max(10, (targetPower * 0.1).round()),
      bossArchers: max(15, (targetPower * 0.15).round()),
      bossDefense: (defense + 15).clamp(30, 80),
      completed: false,
      rewardClaimed: false,
    );
  }

  /// Kunlik duel dushmaniga hujum qilish
  Future<AttackResult> attackDailyBoss() async {
    _ensureDailyBattle();
    final b = dailyBattle!;
    if (b.completed && b.won) throw Exception('Bugungi duel allaqachon g\'alaba bilan yakunlangan');

    final used = min(bombs, 3);
    final morale = 1 + min(1.0, todayKm * 0.05);
    final atk = ((armyStrength + used * 15) * morale).round();
    final def = b.defensePower;
    final won = atk > def;

    int loss(int n, double share) => min(n, (n * share).ceil());
    final aShare = won ? 0.12 : 0.35;

    infantry -= loss(infantry, aShare);
    cavalry -= loss(cavalry, aShare);
    archers -= loss(archers, aShare);
    bombs -= used;

    b.completed = true;
    b.won = won;

    if (won) {
      wins++;
      conqueredTiles += 5;
      defense = min(100, defense + 5);
      bombs += 2;
    }

    final res = AttackResult(
      won: won,
      gained: won ? 5 : 0,
      rivalName: b.bossName,
      rivalColor: const Color(0xFFFF5A4E),
      myPower: atk.toDouble(),
      rivalPower: def.toDouble(),
      rivalOwnTiles: 50,
      bombsUsed: used,
      bombsWon: won ? 2 : 0,
      myInfantry: infantry,
      myCavalry: cavalry,
      enemyInfantry: b.bossInfantry,
      enemyCavalry: b.bossCavalry,
    );

    _changed();
    return res;
  }

  /// Askarlar sovg'asini tanlash: 'archers' (+30), 'cavalry' (+15), 'infantry' (+40)
  void claimDailySoldiers(String type) {
    if (dailyBattle == null || !dailyBattle!.won || dailyBattle!.rewardClaimed) return;
    if (type == 'archers') {
      archers += 30;
    } else if (type == 'cavalry') {
      cavalry += 15;
    } else {
      infantry += 40;
    }
    dailyBattle!.rewardClaimed = true;
    _changed();
  }

  /// PUBG Mobile uslubidagi Jangovar Quti (Loot Crate) ochish
  Weapon openDailyLootBox() {
    final rnd = Random();
    final weapon = allWeapons[rnd.nextInt(allWeapons.length)];
    if (!ownedWeapons.contains(weapon.id)) {
      ownedWeapons = [...ownedWeapons, weapon.id];
    }
    if (dailyBattle != null) {
      dailyBattle!.rewardClaimed = true;
    }
    _changed();
    return weapon;
  }

  void _reset() {
    playerName = '';
    totalKm = 0;
    todayKm = 0;
    todaySteps = 0;
    dayKey = _keyFor(DateTime.now());
    ownTiles = 0;
    conqueredTiles = 0;
    wins = 0;
    attacksToday = 0;
    lastStepCounter = null;
    history = {};
    claimedRewards = {};
    rivals = [];
    clan = null;
    infantry = 0;
    cavalry = 0;
    archers = 0;
    troopKm = 0;
    defense = 20;
    bombs = 0;
    accessories = [];
    ownedWeapons = [];
    dailyBattle = null;
    inbox = [];
  }

  static List<Rival> _seedRivals() => [
        Rival(
            id: 'ali',
            name: 'Ali',
            color: const Color(0xFF6E94E0),
            power: 3.1,
            ownTiles: 31,
            conqueredTiles: 4,
            castleLevel: 2,
            infantry: 30,
            cavalry: 6,
            defense: 20,
            castleSeed: 101),
        Rival(
            id: 'madina',
            name: 'Madina',
            color: const Color(0xFFF2B36B),
            power: 6.8,
            ownTiles: 60,
            conqueredTiles: 12,
            castleLevel: 5,
            infantry: 140,
            cavalry: 28,
            defense: 45,
            castleSeed: 202),
        Rival(
            id: 'bek',
            name: 'Bek',
            color: const Color(0xFF3E9A8A),
            power: 2.4,
            ownTiles: 18,
            conqueredTiles: 0,
            castleLevel: 2,
            infantry: 18,
            cavalry: 3,
            defense: 10,
            castleSeed: 303),
      ];

  Map<String, dynamic> _toJson() => {
        'playerName': playerName,
        'league': league,
        'totalKm': totalKm,
        'todayKm': todayKm,
        'todaySteps': todaySteps,
        'dayKey': dayKey,
        'ownTiles': ownTiles,
        'conqueredTiles': conqueredTiles,
        'wins': wins,
        'attacksToday': attacksToday,
        'lastStepCounter': lastStepCounter,
        'history': history,
        'claimedRewards': claimedRewards.toList(),
        'rivals': rivals.map((r) => r.toJson()).toList(),
        'clan': clan?.toJson(),
        'infantry': infantry,
        'cavalry': cavalry,
        'archers': archers,
        'troopKm': troopKm,
        'defense': defense,
        'bombs': bombs,
        'accessories': accessories,
        'ownedWeapons': ownedWeapons,
        'dailyBattle': dailyBattle?.toJson(),
        'castleSeed': castleSeed,
      };

  void _fromJson(Map<String, dynamic> j) {
    playerName = j['playerName'] as String? ?? '';
    league = j['league'] as String? ?? (_prefs?.getString('player_league') ?? 'Toshkent shahri');
    totalKm = (j['totalKm'] as num?)?.toDouble() ?? 0;
    todayKm = (j['todayKm'] as num?)?.toDouble() ?? 0;
    todaySteps = j['todaySteps'] as int? ?? 0;
    dayKey = j['dayKey'] as String? ?? dayKey;
    ownTiles = j['ownTiles'] as int? ?? 0;
    conqueredTiles = j['conqueredTiles'] as int? ?? 0;
    wins = j['wins'] as int? ?? 0;
    attacksToday = j['attacksToday'] as int? ?? 0;
    lastStepCounter = j['lastStepCounter'] as int?;
    history = (j['history'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    claimedRewards = ((j['claimedRewards'] as List?) ?? []).cast<String>().toSet();
    rivals = ((j['rivals'] as List?) ?? [])
        .map((r) => Rival.fromJson(Map<String, dynamic>.from(r as Map)))
        .where((r) => !r.name.toLowerCase().startsWith('test_') && !r.name.toLowerCase().contains('ping'))
        .toList();
    if (rivals.isEmpty) rivals = _seedRivals();
    final c = j['clan'];
    clan = c == null ? null : Clan.fromJson(Map<String, dynamic>.from(c as Map));
    infantry = (j['infantry'] as num?)?.toInt() ?? (totalKm * infantryPerKm).floor();
    cavalry = (j['cavalry'] as num?)?.toInt() ?? (totalKm * cavalryPerKm).floor();
    archers = (j['archers'] as num?)?.toInt() ?? (totalKm * archersPerKm).floor();
    troopKm = (j['troopKm'] as num?)?.toDouble() ?? totalKm;
    defense = (j['defense'] as num?)?.toInt() ?? 20;
    bombs = (j['bombs'] as num?)?.toInt() ?? 0;
    accessories = ((j['accessories'] as List?) ?? []).cast<String>();
    ownedWeapons = ((j['ownedWeapons'] as List?) ?? []).cast<String>();
    if (j['dailyBattle'] != null) {
      try {
        dailyBattle = DailyBattle.fromJson(Map<String, dynamic>.from(j['dailyBattle'] as Map));
      } catch (_) {}
    }
    castleSeed = (j['castleSeed'] as num?)?.toInt() ?? castleSeed;
    _ensureDailyBattle();
  }
}
