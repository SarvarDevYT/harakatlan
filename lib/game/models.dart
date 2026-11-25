import 'package:material_ui/material_ui.dart';

/// Another player on the map (local stand-ins until the server exists).
class Rival {
  Rival({
    required this.id,
    required this.name,
    required this.color,
    required this.power,
    required this.ownTiles,
    required this.conqueredTiles,
    required this.castleLevel,
    this.flaggedUntil,
    this.infantry = 0,
    this.cavalry = 0,
    this.defense = 20,
    this.castleSeed = 0,
    this.accessories = const [],
  });

  int infantry;
  int cavalry;
  int defense;
  int castleSeed;
  List<String> accessories;

  /// What an attacker has to beat: army × (1 + defence%).
  int get defensePower => ((infantry + cavalry * 3) * (1 + defense / 100)).round();

  final String id;
  final String name;
  final Color color;

  /// Today's walked km – this is the rival's defence.
  double power;

  /// Land earned by walking. Never taken away by attacks.
  int ownTiles;

  /// Bonus land won in battles. The only layer that changes hands.
  int conqueredTiles;
  int castleLevel;

  /// While set and in the future, this rival carries our flag and can't be attacked again.
  DateTime? flaggedUntil;

  bool get isFlagged => flaggedUntil != null && flaggedUntil!.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.toARGB32(),
        'power': power,
        'ownTiles': ownTiles,
        'conqueredTiles': conqueredTiles,
        'castleLevel': castleLevel,
        'flaggedUntil': flaggedUntil?.toIso8601String(),
        'infantry': infantry,
        'cavalry': cavalry,
        'defense': defense,
        'castleSeed': castleSeed,
        'accessories': accessories,
      };

  factory Rival.fromJson(Map<String, dynamic> j) => Rival(
        id: j['id'] as String,
        name: j['name'] as String,
        color: Color(j['color'] as int),
        power: (j['power'] as num).toDouble(),
        ownTiles: j['ownTiles'] as int,
        conqueredTiles: j['conqueredTiles'] as int,
        castleLevel: j['castleLevel'] as int,
        flaggedUntil: j['flaggedUntil'] == null ? null : DateTime.parse(j['flaggedUntil'] as String),
        infantry: (j['infantry'] as num?)?.toInt() ?? 0,
        cavalry: (j['cavalry'] as num?)?.toInt() ?? 0,
        defense: (j['defense'] as num?)?.toInt() ?? 20,
        castleSeed: (j['castleSeed'] as num?)?.toInt() ?? 0,
        accessories: ((j['accessories'] as List?) ?? []).cast<String>(),
      );
}

class ClanMember {
  ClanMember({required this.name, required this.role, required this.weekKm, required this.color});

  final String name;
  final String role;
  double weekKm;
  final Color color;

  Map<String, dynamic> toJson() =>
      {'name': name, 'role': role, 'weekKm': weekKm, 'color': color.toARGB32()};

  factory ClanMember.fromJson(Map<String, dynamic> j) => ClanMember(
        name: j['name'] as String,
        role: j['role'] as String,
        weekKm: (j['weekKm'] as num).toDouble(),
        color: Color(j['color'] as int),
      );
}

class Clan {
  Clan({
    required this.name,
    required this.tag,
    required this.members,
    this.level = 1,
    this.score = 0,
    this.enemyName = 'TEMIR TOVON',
    this.enemyScore = 0,
    required this.warEnds,
    this.lastWarDay,
    this.id,
    this.inviteCode,
  });

  static const maxMembers = 30;

  /// Server-side id and the 6-letter code friends use to join (online mode).
  final String? id;
  final String? inviteCode;

  final String name;
  final String tag;
  final List<ClanMember> members;
  int level;
  double score;
  String enemyName;
  double enemyScore;
  DateTime warEnds;

  /// Day key of the last time the player pushed their km into the war.
  String? lastWarDay;

  Map<String, dynamic> toJson() => {
        'name': name,
        'tag': tag,
        'members': members.map((m) => m.toJson()).toList(),
        'level': level,
        'score': score,
        'enemyName': enemyName,
        'enemyScore': enemyScore,
        'warEnds': warEnds.toIso8601String(),
        'lastWarDay': lastWarDay,
      };

  factory Clan.fromJson(Map<String, dynamic> j) => Clan(
        name: j['name'] as String,
        tag: j['tag'] as String,
        members: (j['members'] as List)
            .map((m) => ClanMember.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
        level: j['level'] as int,
        score: (j['score'] as num).toDouble(),
        enemyName: j['enemyName'] as String,
        enemyScore: (j['enemyScore'] as num).toDouble(),
        warEnds: DateTime.parse(j['warEnds'] as String),
        lastWarDay: j['lastWarDay'] as String?,
      );
}

enum Tier { bronza, kumush, oltin, platina, olmos, afsona }

extension TierInfo on Tier {
  String get label => const ['Bronza', 'Kumush', 'Oltin', 'Platina', 'Olmos', 'Afsona'][index];

  Color get color => const [
        Color(0xFFC98A5A),
        Color(0xFFC9CED6),
        Color(0xFFF2C94C),
        Color(0xFF7FE3D6),
        Color(0xFF8FB8FF),
        Color(0xFFD4FF3F),
      ][index];

  /// Rank points needed to enter this tier.
  int get minPoints => const [0, 300, 700, 1200, 1800, 2500][index];
}

enum RewardKind { castleSkin, avatarFrame, flag, mapEffect, emblem }

class Reward {
  const Reward({required this.id, required this.title, required this.kind, required this.unlock});

  final String id;
  final String title;
  final RewardKind kind;
  final Tier unlock;

  String get kindLabel => switch (kind) {
        RewardKind.castleSkin => "Qal'a skini",
        RewardKind.avatarFrame => 'Avatar ramkasi',
        RewardKind.flag => "Hudud bayrog'i",
        RewardKind.mapEffect => 'Xarita effekti',
        RewardKind.emblem => 'Klan gerbi',
      };
}

class AttackResult {
  AttackResult({
    required this.won,
    required this.gained,
    required this.rivalName,
    required this.rivalColor,
    required this.myPower,
    required this.rivalPower,
    required this.rivalOwnTiles,
    this.rivalCastleSeed = 0,
    this.rivalAccessories = const [],
    this.bombsUsed = 0,
    this.bombsWon = 0,
    this.reward,
    this.defenseLost = 0,
    this.myInfantry = 0,
    this.myCavalry = 0,
    this.enemyInfantry = 0,
    this.enemyCavalry = 0,
    this.myLosses = 0,
    this.enemyLosses = 0,
  });

  final int rivalCastleSeed;
  final List<String> rivalAccessories;
  final int bombsUsed;
  final int bombsWon;
  final String? reward;
  final int defenseLost;
  final int myInfantry;
  final int myCavalry;
  final int enemyInfantry;
  final int enemyCavalry;
  final int myLosses;
  final int enemyLosses;

  final bool won;
  final int gained;
  final String rivalName;
  final Color rivalColor;
  final double myPower;
  final double rivalPower;
  final int rivalOwnTiles;
}


/// "Your castle was attacked" message from the server.
class InboxItem {
  InboxItem({required this.id, required this.attacked, required this.by, required this.defenseLost, required this.soldiersLost});

  final String id;
  final bool attacked; // false = we held the walls
  final String by;
  final int defenseLost;
  final int soldiersLost;

  factory InboxItem.fromJson(Map<String, dynamic> j) => InboxItem(
        id: j['id'] as String,
        attacked: j['kind'] == 'attacked',
        by: j['by'] as String? ?? '?',
        defenseLost: (j['defenseLost'] as num?)?.toInt() ?? 0,
        soldiersLost: (j['soldiersLost'] as num?)?.toInt() ?? 0,
      );
}

/// 10 xil jangovar qurol-aslahalar (Loot Crate / Battle qutisidan tushadi)
class Weapon {
  const Weapon({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.bonusPower,
    required this.bonusDefense,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int bonusPower;
  final int bonusDefense;
}

const allWeapons = [
  Weapon(id: 'diamond_sword', name: 'Olmos Qilich', description: 'Hujumga +25 kuch', icon: Icons.sports_kabaddi_rounded, color: Color(0xFF7FE3D6), bonusPower: 25, bonusDefense: 0),
  Weapon(id: 'flame_bow', name: 'Olovli Kamon', description: 'Hujumga +30 kuch', icon: Icons.call_missed_outgoing_rounded, color: Color(0xFFFF7A3D), bonusPower: 30, bonusDefense: 0),
  Weapon(id: 'iron_shield', name: 'Temir Qalqon', description: 'Mudofaaga +15%', icon: Icons.shield_rounded, color: Color(0xFFC9CED6), bonusPower: 0, bonusDefense: 15),
  Weapon(id: 'dragon_spear', name: 'Ajdar Nayzasi', description: 'Hujumga +40 kuch', icon: Icons.gps_fixed_rounded, color: Color(0xFFFF5A4E), bonusPower: 40, bonusDefense: 0),
  Weapon(id: 'mythic_helmet', name: 'Afsonaviy Dubulg\'a', description: 'Mudofaaga +20%', icon: Icons.military_tech_rounded, color: Color(0xFFF2C94C), bonusPower: 0, bonusDefense: 20),
  Weapon(id: 'titan_hammer', name: 'Titan Bolg\'asi', description: 'Hujumga +50 kuch', icon: Icons.gavel_rounded, color: Color(0xFFE07F9A), bonusPower: 50, bonusDefense: 0),
  Weapon(id: 'golden_armor', name: 'Oltin Sovut', description: 'Mudofaaga +25%', icon: Icons.security_rounded, color: Color(0xFFF2C94C), bonusPower: 0, bonusDefense: 25),
  Weapon(id: 'magic_staff', name: 'Sehrli Asso', description: 'Hujumga +35 kuch', icon: Icons.auto_awesome_rounded, color: Color(0xFFB07FE0), bonusPower: 35, bonusDefense: 5),
  Weapon(id: 'thunder_dagger', name: 'Chaqmoq Xanjari', description: 'Hujumga +35 kuch', icon: Icons.flash_on_rounded, color: Color(0xFFD4FF3F), bonusPower: 35, bonusDefense: 0),
  Weapon(id: 'winged_boots', name: 'Qanotli Etik', description: 'Hujumga +20, Mudofaaga +10%', icon: Icons.flight_rounded, color: Color(0xFF8FB8FF), bonusPower: 20, bonusDefense: 10),
];

/// PUBG Mobile uslubidagi har kunlik Duel / Battle raqibi
class DailyBattle {
  DailyBattle({
    required this.dayKey,
    required this.bossName,
    required this.bossPower,
    required this.bossInfantry,
    required this.bossCavalry,
    required this.bossArchers,
    required this.bossDefense,
    this.completed = false,
    this.rewardClaimed = false,
    this.won = false,
  });

  final String dayKey;
  final String bossName;
  final double bossPower;
  final int bossInfantry;
  final int bossCavalry;
  final int bossArchers;
  final int bossDefense;
  bool completed;
  bool rewardClaimed;
  bool won;

  int get defensePower =>
      ((bossInfantry + bossCavalry * 3 + bossArchers * 2) * (1 + bossDefense / 100)).round();

  bool get isOpen {
    final now = DateTime.now();
    return now.hour >= 19;
  }

  Duration get timeUntilOpen {
    final now = DateTime.now();
    if (now.hour >= 19) return Duration.zero;
    final target = DateTime(now.year, now.month, now.day, 19, 0, 0);
    return target.difference(now);
  }

  Map<String, dynamic> toJson() => {
        'dayKey': dayKey,
        'bossName': bossName,
        'bossPower': bossPower,
        'bossInfantry': bossInfantry,
        'bossCavalry': bossCavalry,
        'bossArchers': bossArchers,
        'bossDefense': bossDefense,
        'completed': completed,
        'rewardClaimed': rewardClaimed,
        'won': won,
      };

  factory DailyBattle.fromJson(Map<String, dynamic> j) => DailyBattle(
        dayKey: j['dayKey'] as String? ?? '',
        bossName: j['bossName'] as String? ?? 'Qora Ritsar',
        bossPower: (j['bossPower'] as num?)?.toDouble() ?? 5.0,
        bossInfantry: (j['bossInfantry'] as num?)?.toInt() ?? 50,
        bossCavalry: (j['bossCavalry'] as num?)?.toInt() ?? 10,
        bossArchers: (j['bossArchers'] as num?)?.toInt() ?? 15,
        bossDefense: (j['bossDefense'] as num?)?.toInt() ?? 35,
        completed: j['completed'] as bool? ?? false,
        rewardClaimed: j['rewardClaimed'] as bool? ?? false,
        won: j['won'] as bool? ?? false,
      );
}
