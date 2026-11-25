import type { VercelRequest, VercelResponse } from "@vercel/node";

import * as game from "../lib/game";
import { analyzeFoodImageWithGemini, NutritionError } from "../lib/nutrition";

type Handler = (uid: string, data: Record<string, unknown>) => Promise<unknown>;

/** Actions that need a logged-in player. POST /api/<action> with a JSON body. */
const actions: Record<string, Handler> = {
  state: (uid) => game.state(uid),
  rename: game.rename,
  reportDistance: game.reportDistance,
  placeTiles: (uid) => game.placeTiles(uid),
  getNeighbors: (uid) => game.getNeighbors(uid),
  attack: game.attack,
  createClan: game.createClan,
  joinClan: game.joinClan,
  leaveClan: (uid) => game.leaveClan(uid),
  pushClanWar: (uid) => game.pushClanWar(uid),
  searchUsers: game.searchUsers,
  addMemberToClan: game.addMemberToClan,
  claimReward: game.claimReward,
  deleteAccount: (uid) => game.deleteAccount(uid),
  readInbox: (uid) => game.readInbox(uid),
};

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ error: "POST kerak" });

  const action = String(req.query.action ?? "");
  const data = (typeof req.body === "object" && req.body) || {};
  try {
    if (action === "register") return res.status(200).json(await game.register(data));
    if (action === "analyzeNutrition") {
      const base64Data = String(data.image || data.base64 || "").trim();
      const mimeType = String(data.mimeType || data.contentType || "image/jpeg").trim();
      return res.status(200).json(await analyzeFoodImageWithGemini(base64Data, mimeType));
    }
    const fn = actions[action];
    if (!fn) return res.status(404).json({ error: "Bunday amal yo'q" });
    const uid = await game.authenticate(req.headers.authorization);
    return res.status(200).json(await fn(uid, data));
  } catch (e) {
    if (e instanceof NutritionError) return res.status(e.statusCode).json({ error: e.message });
    if (e instanceof game.GameError) return res.status(e.status).json({ error: e.message });
    console.error(action, e);
    return res.status(500).json({ error: "Serverda xatolik, birozdan keyin urining" });
  }
}
