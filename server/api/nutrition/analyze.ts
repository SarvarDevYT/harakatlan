import type { VercelRequest, VercelResponse } from "@vercel/node";
import { analyzeFoodImageWithGemini, NutritionError } from "../../lib/nutrition";

export const config = {
  api: {
    bodyParser: {
      sizeLimit: "12mb",
    },
  },
};

export default async function handler(req: VercelRequest, res: VercelResponse) {
  // CORS Preflight
  if (req.method === "OPTIONS") {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    return res.status(204).end();
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Faqat POST so'rovi qabul qilinadi" });
  }

  try {
    const body = typeof req.body === "object" && req.body ? req.body : {};
    const base64Data = String(body.image || body.base64 || "").trim();
    const mimeType = String(body.mimeType || body.contentType || "image/jpeg").trim();

    if (!base64Data) {
      return res.status(400).json({
        error: "Rasm ma'lumotlari yuborilmadi (image yoki base64 maydoni bo'sh)",
      });
    }

    const result = await analyzeFoodImageWithGemini(base64Data, mimeType);
    return res.status(200).json(result);
  } catch (err) {
    if (err instanceof NutritionError) {
      return res.status(err.statusCode).json({ error: err.message });
    }
    console.error("Nutrition analyze unhandled error:", err);
    return res.status(500).json({ error: "Serverda taom tahlili jarayonida xatolik yuz berdi" });
  }
}
