import type { VercelRequest, VercelResponse } from "@vercel/node";

import { scheduleClanWars } from "../lib/game";

/** Called by Vercel Cron every Monday (see vercel.json). */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: "unauthorized" });
  }
  return res.status(200).json(await scheduleClanWars());
}
