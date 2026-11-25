/**
 * Pure game rules, shared by every server function. Keep in sync with
 * lib/game/rules.dart in the app (the app only uses them for display).
 */

export const TILES_PER_KM = 1;
export const MAX_ATTACKS_PER_DAY = 3;
export const FLAG_HOURS = 24;
/** A person can't plausibly walk/run more than this in one day. */
export const MAX_KM_PER_DAY = 80;
/** Fastest believable average speed between two reports (running). */
export const MAX_KMH = 20;
/** Tiles needed for each castle level (index 0 = level 1). */
export const LEVEL_THRESHOLDS = [0, 5, 15, 30, 50, 75, 105, 140, 180, 225];

export const TIERS = [
  { id: "bronza", min: 0 },
  { id: "kumush", min: 300 },
  { id: "oltin", min: 700 },
  { id: "platina", min: 1200 },
  { id: "olmos", min: 1800 },
  { id: "afsona", min: 2500 },
] as const;
export type TierId = (typeof TIERS)[number]["id"];

export const REWARDS: Record<string, TierId> = {
  neon_tower: "bronza",
  silver_crest: "kumush",
  gold_ring: "oltin",
  bolt_flag: "platina",
  diamond_tower: "olmos",
  fire_trail: "afsona",
};

/** Day key in Tashkent time (UTC+5), e.g. "2026-11-18". */
export function dayKey(at: Date = new Date()): string {
  const local = new Date(at.getTime() + 5 * 3600 * 1000);
  return local.toISOString().slice(0, 10);
}

export function castleLevel(totalTiles: number): number {
  let level = 1;
  LEVEL_THRESHOLDS.forEach((t, i) => {
    if (totalTiles >= t) level = i + 1;
  });
  return level;
}

export function rankPoints(level: number, wins: number, totalKm: number): number {
  return level * 100 + wins * 15 + Math.floor(totalKm);
}

export function tierFor(points: number): TierId {
  let tier: TierId = "bronza";
  for (const t of TIERS) if (points >= t.min) tier = t.id;
  return tier;
}

export function tierIndex(id: TierId): number {
  return TIERS.findIndex((t) => t.id === id);
}

/** Bonus tiles for a win: twice the km advantage, between 1 and 10. */
export function bonusTiles(attackerKm: number, defenderKm: number): number {
  return Math.min(10, Math.max(1, Math.round((attackerKm - defenderKm) * 2)));
}

/**
 * Accepts a new "km walked today" value from the phone, but only as much
 * as is physically believable since the previous report.
 */
export function acceptDistance(opts: {
  previousTodayKm: number;
  reportedTodayKm: number;
  hoursSinceLastReport: number;
}): number {
  const { previousTodayKm, reportedTodayKm, hoursSinceLastReport } = opts;
  if (!Number.isFinite(reportedTodayKm) || reportedTodayKm <= previousTodayKm) {
    return previousTodayKm; // distance never goes down
  }
  const maxGain = Math.max(0.5, MAX_KMH * Math.max(0, hoursSinceLastReport));
  const capped = Math.min(reportedTodayKm, previousTodayKm + maxGain, MAX_KM_PER_DAY);
  return Math.round(capped * 1000) / 1000;
}

// ---------------------------------------------------------------- army

/** Every km walked trains this many soldiers. Cavalry is rarer but stronger. */
export const INFANTRY_PER_KM = 10;
export const CAVALRY_PER_KM = 2;
export const CAVALRY_STRENGTH = 3;
export const BOMB_STRENGTH = 15;
export const MAX_BOMBS_PER_ATTACK = 3;
/** Defence level (0–100) multiplies the defender's army by up to ×2. */
export const DEFENSE_START = 20;
export const DEFENSE_LOSS_ON_DEFEAT = 10;
export const DEFENSE_GAIN_ON_WIN = 5;

export const ACCESSORIES = [
  "gold_roof", // oltin tom
  "banner_tall", // baland bayroq
  "cannon", // to'p
  "torches", // mash'alalar
  "crystal_spire", // billur minora uchi
  "dragon_flag", // ajdar bayroq
  "moat", // xandaq
  "shield_wall", // qalqon devor
] as const;

/** Soldiers earned when lifetime km grows from `before` to `after`. */
export function troopsEarned(before: number, after: number) {
  return {
    infantry: Math.max(0, Math.floor(after * INFANTRY_PER_KM) - Math.floor(before * INFANTRY_PER_KM)),
    cavalry: Math.max(0, Math.floor(after * CAVALRY_PER_KM) - Math.floor(before * CAVALRY_PER_KM)),
  };
}

export function armyStrength(infantry: number, cavalry: number): number {
  return infantry + cavalry * CAVALRY_STRENGTH;
}

/** A defended castle counts its army ×(1 + defence/100). */
export function defenseStrength(infantry: number, cavalry: number, defense: number): number {
  return Math.round(armyStrength(infantry, cavalry) * (1 + Math.max(0, Math.min(100, defense)) / 100));
}

export interface BattleOutcome {
  won: boolean;
  attackPower: number;
  defensePower: number;
  bombsUsed: number;
  attackerLosses: { infantry: number; cavalry: number };
  defenderLosses: { infantry: number; cavalry: number };
}

/**
 * Attack power = army + bombs + a morale bonus of 5% per km walked today.
 * The loser loses 40% of their troops, the winner 15%.
 */
export function resolveBattle(a: {
  infantry: number;
  cavalry: number;
  bombs: number;
  todayKm: number;
}, d: { infantry: number; cavalry: number; defense: number }): BattleOutcome {
  const bombsUsed = Math.min(a.bombs, MAX_BOMBS_PER_ATTACK);
  const morale = 1 + Math.min(1, a.todayKm * 0.05);
  const attackPower = Math.round((armyStrength(a.infantry, a.cavalry) + bombsUsed * BOMB_STRENGTH) * morale);
  const defensePower = defenseStrength(d.infantry, d.cavalry, d.defense);
  const won = attackPower > defensePower;
  const loss = (n: number, share: number) => Math.min(n, Math.ceil(n * share));
  const aShare = won ? 0.15 : 0.4;
  const dShare = won ? 0.4 : 0.15;
  return {
    won,
    attackPower,
    defensePower,
    bombsUsed,
    attackerLosses: { infantry: loss(a.infantry, aShare), cavalry: loss(a.cavalry, aShare) },
    defenderLosses: { infantry: loss(d.infantry, dShare), cavalry: loss(d.cavalry, dShare) },
  };
}
