import { createHash, randomBytes } from "node:crypto";
import { cert, getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, Firestore, getFirestore, Timestamp, Transaction } from "firebase-admin/firestore";

import {
  acceptDistance,
  bonusTiles,
  castleLevel,
  dayKey,
  FLAG_HOURS,
  MAX_ATTACKS_PER_DAY,
  rankPoints,
  ACCESSORIES,
  defenseStrength,
  DEFENSE_GAIN_ON_WIN,
  DEFENSE_LOSS_ON_DEFEAT,
  DEFENSE_START,
  resolveBattle,
  REWARDS,
  TILES_PER_KM,
  troopsEarned,
  tierFor,
  tierIndex,
} from "./rules";

// ---------------------------------------------------------------- setup

let _db: Firestore | null = null;
export function db(): Firestore {
  if (_db) return _db;
  if (!getApps().length) {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (!raw) throw new Error("FIREBASE_SERVICE_ACCOUNT is not set");
    initializeApp({ credential: cert(JSON.parse(raw)) });
  }
  _db = getFirestore();
  return _db;
}

/** A readable error that the app shows to the player. */
export class GameError extends Error {
  constructor(message: string, public status = 400) {
    super(message);
  }
}

// ---------------------------------------------------------------- types

export interface UserDoc {
  name: string;
  league: string;
  secretHash: string;
  createdAt: Timestamp;
  lastActive: Timestamp;
  totalKm: number;
  todayKm: number;
  todaySteps: number;
  dayKey: string;
  lastReportAt: Timestamp | null;
  history: Record<string, number>;
  ownTiles: number;
  conqueredTiles: number;
  wins: number;
  attacksToday: number;
  castleLevel: number;
  rankPoints: number;
  tier: string;
  clanId: string | null;
  claimedRewards: string[];
  flaggedUntil: Timestamp | null;
  flaggedBy: string | null;
  // army
  infantry: number;
  cavalry: number;
  troopKm: number; // lifetime km already turned into soldiers
  defense: number; // 0..100
  bombs: number;
  accessories: string[];
  castleSeed: number; // picks this player's own castle look
  inbox: InboxItem[];
}

export interface InboxItem {
  id: string;
  kind: "attacked" | "defended";
  by: string;
  at: number;
  defenseLost: number;
  soldiersLost: number;
  read: boolean;
}

interface ClanDoc {
  name: string;
  tag: string;
  leaderUid: string;
  memberUids: string[];
  inviteCode: string;
  level: number;
  score: number;
  warId: string | null;
  createdAt: Timestamp;
}

const MAX_CLAN_MEMBERS = 30;
const userRef = (uid: string) => db().collection("users").doc(uid);

// ---------------------------------------------------------------- helpers

const hash = (s: string) => createHash("sha256").update(s).digest("hex");

/** "Bearer <uid>.<secret>" — the phone got both when it registered. */
export async function authenticate(header: string | undefined): Promise<string> {
  const m = /^Bearer ([A-Za-z0-9]{20})\.([A-Za-z0-9_-]{32,})$/.exec(header ?? "");
  if (!m) throw new GameError("Avval ro'yxatdan o'ting", 401);
  const snap = await userRef(m[1]).get();
  if (!snap.exists || snap.get("secretHash") !== hash(m[2])) throw new GameError("Akkaunt topilmadi", 401);
  return m[1];
}

/** Fills army fields for profiles made before the army existed. */
function withArmy(u: UserDoc): UserDoc {
  u.infantry ??= 0;
  u.cavalry ??= 0;
  u.troopKm ??= 0;
  u.defense ??= DEFENSE_START;
  u.bombs ??= 0;
  u.accessories ??= [];
  u.castleSeed ??= Math.floor(Math.random() * 1e6);
  u.inbox ??= [];
  // Soldiers for km walked before the army existed.
  if (u.troopKm < u.totalKm) {
    const t = troopsEarned(u.troopKm, u.totalKm);
    u.infantry += t.infantry;
    u.cavalry += t.cavalry;
    u.troopKm = u.totalKm;
  }
  return u;
}

function rollDay(u: UserDoc, today = dayKey()): UserDoc {
  withArmy(u);
  if (u.dayKey !== today) {
    u.dayKey = today;
    u.todayKm = 0;
    u.todaySteps = 0;
    u.attacksToday = 0;
  }
  return u;
}

function derive(u: UserDoc) {
  const level = castleLevel(u.ownTiles + u.conqueredTiles);
  const points = rankPoints(level, u.wins, u.totalKm);
  return { castleLevel: level, rankPoints: points, tier: tierFor(points) };
}

async function loadUser(tx: Transaction, uid: string): Promise<UserDoc> {
  const snap = await tx.get(userRef(uid));
  if (!snap.exists) throw new GameError("Profil topilmadi", 404);
  return rollDay(snap.data() as UserDoc);
}

function cleanName(raw: unknown, min: number, max: number, what: string): string {
  if (typeof raw !== "string") throw new GameError(`${what} kerak`);
  const v = raw.trim().replace(/\s+/g, " ");
  if (v.length < min || v.length > max) throw new GameError(`${what} ${min}–${max} belgidan iborat bo'lsin`);
  return v;
}

function publicProfile(uid: string, u: UserDoc) {
  const today = dayKey();
  const sameDay = u.dayKey === today;
  return {
    uid,
    name: u.name,
    totalKm: u.totalKm,
    todayKm: sameDay ? u.todayKm : 0,
    todaySteps: sameDay ? u.todaySteps : 0,
    attacksToday: sameDay ? u.attacksToday : 0,
    dayKey: today,
    history: u.history,
    ownTiles: u.ownTiles,
    conqueredTiles: u.conqueredTiles,
    wins: u.wins,
    castleLevel: u.castleLevel,
    clanId: u.clanId,
    claimedRewards: u.claimedRewards,
    flaggedUntil: u.flaggedUntil?.toMillis() ?? null,
    infantry: u.infantry,
    cavalry: u.cavalry,
    defense: u.defense,
    defensePower: defenseStrength(u.infantry, u.cavalry, u.defense),
    bombs: u.bombs,
    accessories: u.accessories,
    castleSeed: u.castleSeed,
    inbox: (u.inbox ?? []).filter((i) => !i.read).slice(-5),
  };
}

// ---------------------------------------------------------------- actions

type Data = Record<string, unknown>;

/** No login needed: creates the account and hands the phone its key once. */
export async function register(data: Data) {
  const name = cleanName(data.name, 2, 24, "Ism");
  const uid = randomBytes(15).toString("base64url").replace(/[-_]/g, "x").slice(0, 20);
  const secret = randomBytes(32).toString("base64url");
  const now = Timestamp.now();
  const u: UserDoc = {
    name,
    league: "toshkent",
    secretHash: hash(secret),
    createdAt: now,
    lastActive: now,
    totalKm: 0,
    todayKm: 0,
    todaySteps: 0,
    dayKey: dayKey(),
    lastReportAt: null,
    history: {},
    ownTiles: 0,
    conqueredTiles: 0,
    wins: 0,
    attacksToday: 0,
    castleLevel: 1,
    rankPoints: 100,
    tier: "bronza",
    clanId: null,
    claimedRewards: [],
    flaggedUntil: null,
    flaggedBy: null,
    infantry: 0,
    cavalry: 0,
    troopKm: 0,
    defense: DEFENSE_START,
    bombs: 0,
    accessories: [],
    castleSeed: Math.floor(Math.random() * 1e6),
    inbox: [],
  };
  await userRef(uid).create(u);
  return { uid, secret, profile: publicProfile(uid, u) };
}

/** Everything a screen needs in one call: profile, clan, war. */
export async function state(uid: string) {
  const snap = await userRef(uid).get();
  if (!snap.exists) throw new GameError("Profil topilmadi", 404);
  const u = withArmy(snap.data() as UserDoc);
  let clan = null;
  if (u.clanId) {
    const c = await db().collection("clans").doc(u.clanId).get();
    if (c.exists) {
      const cd = c.data() as ClanDoc;
      const members = await db().collection("users").where("clanId", "==", u.clanId).get();
      let war = null;
      if (cd.warId) {
        const w = await db().collection("clanWars").doc(cd.warId).get();
        if (w.exists) {
          const wd = w.data()!;
          const weA = wd.clanA === u.clanId;
          war = {
            enemyName: weA ? wd.nameB : wd.nameA,
            ourScore: weA ? wd.scoreA : wd.scoreB,
            enemyScore: weA ? wd.scoreB : wd.scoreA,
            endsAt: wd.endsAt.toMillis(),
          };
        }
      }
      const pushed = await db().collection("clans").doc(u.clanId).collection("pushes").doc(`${uid}_${dayKey()}`).get();
      clan = {
        id: c.id,
        name: cd.name,
        tag: cd.tag,
        level: cd.level,
        score: cd.score,
        inviteCode: cd.inviteCode,
        leaderUid: cd.leaderUid,
        pushedToday: pushed.exists,
        war,
        members: members.docs.map((d) => {
          const m = d.data() as UserDoc;
          const week = Object.values(m.history ?? {}).reduce((s, v) => s + v, 0);
          return { uid: d.id, name: m.name, weekKm: Math.round(week * 10) / 10 };
        }),
      };
    }
  }
  return { profile: publicProfile(uid, u), clan };
}

export async function rename(uid: string, data: Data) {
  const name = cleanName(data.name, 2, 24, "Ism");
  await userRef(uid).update({ name, lastActive: Timestamp.now() });
  return { ok: true };
}

export async function reportDistance(uid: string, data: Data) {
  const reported = Number(data.todayKm);
  const steps = Math.max(0, Math.floor(Number(data.todaySteps) || 0));
  return db().runTransaction(async (tx) => {
    const u = await loadUser(tx, uid);
    const now = Timestamp.now();
    const hours = u.lastReportAt ? (now.toMillis() - u.lastReportAt.toMillis()) / 3.6e6 : 24;
    const accepted = acceptDistance({ previousTodayKm: u.todayKm, reportedTodayKm: reported, hoursSinceLastReport: hours });
    const gain = accepted - u.todayKm;
    u.todayKm = accepted;
    u.todaySteps = Math.max(u.todaySteps, steps);
    u.totalKm = Math.round((u.totalKm + gain) * 1000) / 1000;
    const t = troopsEarned(u.troopKm, u.totalKm);
    u.infantry += t.infantry;
    u.cavalry += t.cavalry;
    u.troopKm = u.totalKm;
    u.history = { ...u.history, [u.dayKey]: accepted };
    const keys = Object.keys(u.history).sort();
    for (const k of keys.slice(0, Math.max(0, keys.length - 14))) delete u.history[k];
    tx.set(userRef(uid), { ...u, ...derive(u), lastReportAt: now, lastActive: now });
    return { todayKm: u.todayKm, totalKm: u.totalKm, newInfantry: t.infantry, newCavalry: t.cavalry };
  });
}

export async function placeTiles(uid: string) {
  return db().runTransaction(async (tx) => {
    const u = await loadUser(tx, uid);
    const placed = Math.max(0, Math.floor(u.totalKm * TILES_PER_KM) - u.ownTiles);
    u.ownTiles += placed;
    tx.set(userRef(uid), { ...u, ...derive(u) });
    return { placed };
  });
}

export async function getNeighbors(uid: string) {
  const me = (await userRef(uid).get()).data() as UserDoc | undefined;
  if (!me) throw new GameError("Profil topilmadi", 404);
  const snap = await db().collection("users").where("league", "==", me.league).orderBy("lastActive", "desc").limit(60).get();
  const today = dayKey();
  const players = snap.docs
    .filter((d) => d.id !== uid)
    .map((d) => ({ uid: d.id, u: d.data() as UserDoc }))
    .filter(({ u }) => Math.abs(u.castleLevel - me.castleLevel) <= 3)
    .filter(({ u }) => !u.name.toLowerCase().startsWith("test_") && !u.name.toLowerCase().contains("ping"))
    .slice(0, 12)
    .map(({ uid: id, u }) => withArmy(u) && ({
      uid: id,
      name: u.name,
      infantry: u.infantry,
      cavalry: u.cavalry,
      defense: u.defense,
      defensePower: defenseStrength(u.infantry, u.cavalry, u.defense),
      castleSeed: u.castleSeed,
      accessories: u.accessories,
      power: u.dayKey === today ? u.todayKm : 0,
      ownTiles: u.ownTiles,
      conqueredTiles: u.conqueredTiles,
      castleLevel: u.castleLevel,
      flaggedUntil: u.flaggedUntil?.toMillis() ?? null,
    }));
  return { players };
}

export async function attack(uid: string, data: Data) {
  const defenderUid = String(data.defenderUid ?? "");
  if (!defenderUid || defenderUid === uid) throw new GameError("Raqib noto'g'ri");
  return db().runTransaction(async (tx) => {
    const me = await loadUser(tx, uid);
    const them = await loadUser(tx, defenderUid);
    const now = Timestamp.now();
    if (me.attacksToday >= MAX_ATTACKS_PER_DAY) throw new GameError("Bugungi hujumlar tugadi, ertaga qayting");
    if (me.infantry + me.cavalry <= 0) throw new GameError("Qo'shiningiz yo'q: yuring, har km 10 piyoda va 2 otliq beradi");
    if (them.flaggedUntil && them.flaggedUntil.toMillis() > now.toMillis()) {
      throw new GameError(`${them.name} hozir bayroq ostida, keyinroq urining`);
    }
    if (me.league !== them.league) throw new GameError("Bu o'yinchi boshqa ligada");

    const before = { infantry: me.infantry, cavalry: me.cavalry, bombs: me.bombs };
    const enemy = { infantry: them.infantry, cavalry: them.cavalry, defense: them.defense };
    const b = resolveBattle({ ...before, todayKm: me.todayKm }, enemy);

    me.attacksToday += 1;
    me.bombs -= b.bombsUsed;
    me.infantry -= b.attackerLosses.infantry;
    me.cavalry -= b.attackerLosses.cavalry;
    them.infantry -= b.defenderLosses.infantry;
    them.cavalry -= b.defenderLosses.cavalry;

    let gained = 0;
    let reward: string | null = null;
    let bombsWon = 0;
    let defenseLost = 0;
    if (b.won) {
      gained = bonusTiles(Math.max(1, b.attackPower / 20), Math.max(0, b.defensePower / 20));
      me.conqueredTiles += gained;
      me.wins += 1;
      me.defense = Math.min(100, me.defense + DEFENSE_GAIN_ON_WIN);
      // Beating a stronger castle pays more bombs.
      bombsWon = b.defensePower >= b.attackPower * 0.7 ? 2 : 1;
      me.bombs += bombsWon;
      const missing = ACCESSORIES.filter((x) => !me.accessories.includes(x));
      if (missing.length) {
        reward = missing[Math.floor(Math.random() * missing.length)];
        me.accessories = [...me.accessories, reward];
      }
      // Fair-play rule: the loser keeps their own land and km; they lose
      // bonus land, some soldiers and some defence.
      them.conqueredTiles = Math.max(0, them.conqueredTiles - gained);
      defenseLost = Math.min(them.defense, DEFENSE_LOSS_ON_DEFEAT);
      them.defense -= defenseLost;
      them.flaggedUntil = Timestamp.fromMillis(now.toMillis() + FLAG_HOURS * 3.6e6);
      them.flaggedBy = uid;
    }
    const note: InboxItem = {
      id: `${now.toMillis()}_${uid.slice(0, 4)}`,
      kind: b.won ? "attacked" : "defended",
      by: me.name,
      at: now.toMillis(),
      defenseLost,
      soldiersLost: b.defenderLosses.infantry + b.defenderLosses.cavalry,
      read: false,
    };
    them.inbox = [...(them.inbox ?? []), note].slice(-20);

    tx.set(userRef(uid), { ...me, ...derive(me), lastActive: now });
    tx.set(userRef(defenderUid), { ...them, ...derive(them) });
    tx.create(db().collection("attacks").doc(), {
      attacker: uid,
      defender: defenderUid,
      attackPower: b.attackPower,
      defensePower: b.defensePower,
      won: b.won,
      gained,
      at: now,
    });
    return {
      won: b.won,
      gained,
      myPower: b.attackPower,
      rivalPower: b.defensePower,
      rivalName: them.name,
      rivalOwnTiles: them.ownTiles,
      rivalCastleSeed: them.castleSeed,
      rivalAccessories: them.accessories,
      bombsUsed: b.bombsUsed,
      bombsWon,
      reward,
      defenseLost,
      my: before,
      enemy: { infantry: enemy.infantry, cavalry: enemy.cavalry },
      myLosses: b.attackerLosses,
      enemyLosses: b.defenderLosses,
    };
  });
}

/** Marks "you were attacked" messages as seen. */
export async function readInbox(uid: string) {
  return db().runTransaction(async (tx) => {
    const me = await loadUser(tx, uid);
    me.inbox = (me.inbox ?? []).map((i) => ({ ...i, read: true }));
    tx.update(userRef(uid), { inbox: me.inbox });
    return { ok: true };
  });
}

function inviteCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (const b of randomBytes(6)) s += alphabet[b % alphabet.length];
  return s;
}

export async function createClan(uid: string, data: Data) {
  const name = cleanName(data.name, 3, 24, "Klan nomi").toUpperCase();
  const tag = cleanName(data.tag, 2, 4, "Teg").toUpperCase();
  return db().runTransaction(async (tx) => {
    const me = await loadUser(tx, uid);
    if (me.clanId) throw new GameError("Siz allaqachon klandasiz");
    const ref = db().collection("clans").doc();
    const clan: ClanDoc = {
      name,
      tag,
      leaderUid: uid,
      memberUids: [uid],
      inviteCode: inviteCode(),
      level: 1,
      score: 0,
      warId: null,
      createdAt: Timestamp.now(),
    };
    tx.create(ref, clan);
    tx.update(userRef(uid), { clanId: ref.id });
    return { clanId: ref.id, inviteCode: clan.inviteCode };
  });
}

export async function joinClan(uid: string, data: Data) {
  const code = String(data.inviteCode ?? "").trim().toUpperCase();
  const found = await db().collection("clans").where("inviteCode", "==", code).limit(1).get();
  if (found.empty) throw new GameError("Bunday taklif kodi yo'q");
  const ref = found.docs[0].ref;
  return db().runTransaction(async (tx) => {
    const me = await loadUser(tx, uid);
    if (me.clanId) throw new GameError("Avval hozirgi klandan chiqing");
    const clan = (await tx.get(ref)).data() as ClanDoc;
    if (clan.memberUids.length >= MAX_CLAN_MEMBERS) throw new GameError("Klan to'la");
    tx.update(ref, { memberUids: FieldValue.arrayUnion(uid) });
    tx.update(userRef(uid), { clanId: ref.id });
    return { clanId: ref.id };
  });
}

export async function leaveClan(uid: string) {
  return db().runTransaction(async (tx) => {
    const me = await loadUser(tx, uid);
    if (!me.clanId) return { ok: true };
    const ref = db().collection("clans").doc(me.clanId);
    const clan = (await tx.get(ref)).data() as ClanDoc | undefined;
    tx.update(userRef(uid), { clanId: null });
    if (!clan) return { ok: true };
    const rest = clan.memberUids.filter((m) => m !== uid);
    if (rest.length === 0) tx.delete(ref);
    else tx.update(ref, { memberUids: rest, leaderUid: clan.leaderUid === uid ? rest[0] : clan.leaderUid });
    return { ok: true };
  });
}

export async function searchUsers(uid: string, data: Data) {
  const query = String(data.query ?? "").trim().toLowerCase();
  if (query.length < 1) return { users: [] };
  const snap = await db().collection("users").limit(80).get();
  const users = snap.docs
    .filter((d) => d.id !== uid)
    .map((d) => ({ uid: d.id, ...(d.data() as UserDoc) }))
    .filter((u) => u.name && u.name.toLowerCase().includes(query))
    .slice(0, 10)
    .map((u) => ({
      uid: u.uid,
      name: u.name,
      castleLevel: u.castleLevel ?? 1,
      clanId: u.clanId,
      totalKm: u.totalKm ?? 0,
      ownTiles: u.ownTiles ?? 0,
    }));
  return { users };
}

export async function addMemberToClan(uid: string, data: Data) {
  const targetUid = String(data.targetUid ?? "").trim();
  const targetName = String(data.targetName ?? "").trim();
  return db().runTransaction(async (tx) => {
    const me = await loadUser(tx, uid);
    if (!me.clanId) throw new GameError("Siz klanda emassiz");
    const clanRef = db().collection("clans").doc(me.clanId);
    const clan = (await tx.get(clanRef)).data() as ClanDoc | undefined;
    if (!clan) throw new GameError("Klan topilmadi");
    if (clan.memberUids.length >= MAX_CLAN_MEMBERS) throw new GameError("Klan to'la (maksimum 30 a'zo)");

    let friendUid = targetUid;
    let friendDoc: UserDoc | null = null;
    if (friendUid) {
      const snap = await tx.get(userRef(friendUid));
      if (snap.exists) friendDoc = snap.data() as UserDoc;
    }
    if (!friendDoc && targetName) {
      const q = await db().collection("users").where("name", "==", targetName).limit(1).get();
      if (!q.empty) {
        friendUid = q.docs[0].id;
        friendDoc = q.docs[0].data() as UserDoc;
      }
    }

    if (friendUid && friendDoc) {
      if (friendDoc.clanId) throw new GameError(`${friendDoc.name} allaqachon boshqa klanda`);
      tx.update(clanRef, { memberUids: FieldValue.arrayUnion(friendUid) });
      tx.update(userRef(friendUid), { clanId: me.clanId });
      const note: InboxItem = {
        id: `${Date.now()}_clan`,
        kind: "defended",
        by: clan.name,
        at: Date.now(),
        defenseLost: 0,
        soldiersLost: 0,
        read: false,
      };
      const inbox = [...(friendDoc.inbox ?? []), note].slice(-20);
      tx.update(userRef(friendUid), { inbox });
      return { ok: true, name: friendDoc.name };
    } else {
      throw new GameError("Foydalanuvchi topilmadi");
    }
  });
}

export async function pushClanWar(uid: string) {
  return db().runTransaction(async (tx) => {
    const me = await loadUser(tx, uid);
    if (!me.clanId) throw new GameError("Siz klanda emassiz");
    if (me.todayKm <= 0) throw new GameError("Avval yuring");
    const clanRef = db().collection("clans").doc(me.clanId);
    const pushRef = clanRef.collection("pushes").doc(`${uid}_${me.dayKey}`);
    if ((await tx.get(pushRef)).exists) throw new GameError("Bugun klanga qo'shdingiz");
    const clan = (await tx.get(clanRef)).data() as ClanDoc;
    const warRef = clan.warId ? db().collection("clanWars").doc(clan.warId) : null;
    const war = warRef ? (await tx.get(warRef)).data() : undefined;

    tx.create(pushRef, { uid, km: me.todayKm, at: Timestamp.now() });
    tx.update(clanRef, { score: FieldValue.increment(me.todayKm) });
    if (warRef && war && war.endsAt.toMillis() > Date.now()) {
      tx.update(warRef, { [war.clanA === me.clanId ? "scoreA" : "scoreB"]: FieldValue.increment(me.todayKm) });
    }
    return { added: me.todayKm };
  });
}

export async function claimReward(uid: string, data: Data) {
  const rewardId = String(data.rewardId ?? "");
  const needed = REWARDS[rewardId];
  if (!needed) throw new GameError("Bunday sovg'a yo'q");
  return db().runTransaction(async (tx) => {
    const me = await loadUser(tx, uid);
    if (tierIndex(derive(me).tier) < tierIndex(needed)) throw new GameError("Bu sovg'a hali ochilmagan");
    tx.update(userRef(uid), { claimedRewards: FieldValue.arrayUnion(rewardId) });
    return { ok: true };
  });
}

/** Apple requires in-app account deletion. */
export async function deleteAccount(uid: string) {
  await leaveClan(uid);
  await userRef(uid).delete();
  return { ok: true };
}

/** Weekly: pair clans of similar strength for a 7-day war. */
export async function scheduleClanWars() {
  const clans = await db().collection("clans").orderBy("score", "desc").get();
  const batch = db().batch();
  const endsAt = Timestamp.fromMillis(Date.now() + 7 * 24 * 3.6e6);
  const docs = clans.docs;
  for (let i = 0; i + 1 < docs.length; i += 2) {
    const war = db().collection("clanWars").doc();
    batch.set(war, {
      clanA: docs[i].id,
      clanB: docs[i + 1].id,
      nameA: docs[i].get("name"),
      nameB: docs[i + 1].get("name"),
      scoreA: 0,
      scoreB: 0,
      startedAt: Timestamp.now(),
      endsAt,
    });
    batch.update(docs[i].ref, { warId: war.id });
    batch.update(docs[i + 1].ref, { warId: war.id });
  }
  if (docs.length % 2 === 1) batch.update(docs[docs.length - 1].ref, { warId: null });
  await batch.commit();
  return { clans: docs.length };
}
