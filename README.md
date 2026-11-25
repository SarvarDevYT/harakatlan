# Harakatlan — Yurib hudud egallash o'yini

**Harakatlan** — bu piyoda yurish orqali real GPS xaritada shahar hududlarini egallash, qal'a qurish, qo'shin yig'ish, klanlar bilan musobaqalashish va **Gemini AI** yordamida taom kaloriyasini skanerlashga asoslangan mobil o'yin (Flutter + Firebase + Vercel).

## Loyiha tuzilishi

| Papka | Vazifasi |
|---|---|
| `lib/` | Mobil ilova kodi (Flutter: GPS xarita, 14 viloyat ligasi, Health Connect / Pedometer, AI Skaner, Klanlar, Mavsum reytingi) |
| `landing/` | Rasmiy **Landing Page** (mobil ilova dizayni asosida, Vercel'da to'g'ridan-to'g'ri deploy qilish uchun tayyor) |
| `server/` | Backend API (Vercel Serverless Functions + Firestore + Gemini Vision API) |
| `assets/images/` | Ilova logotipi, orol va taktik xarita grafikalari |
| `design/` | Dizayn tizimi va ekran maketlari (`#0B0B0B`, `#D4FF3F`, `Space Grotesk`, `Inter`, `Caveat`) |

---

## Vercel'ga Landing Page'ni joylash (Deploy)

1. Vercel dashboard'da **Add New Project** -> ushbu GitHub repozitoriyni tanlang.
2. Ildiz papkadagi `vercel.json` avtomatik tarzda `landing/` papkasini ko'rsatadi — qo'shimcha sozlash talab qilinmaydi.
3. **Deploy** tugmasini bosing.

*(Backend API uchun alohida loyiha sifatida `server/` papkasini Root Directory qilib ulash mumkin).*

---

## Mobil ilovani ishga tushirish

```bash
flutter pub get
flutter run --dart-define=CARTO_API_KEY=your_carto_key
```

Release APK yig'ish:

```bash
flutter build apk --release --dart-define=CARTO_API_KEY=your_carto_key
```

> `CARTO_API_KEY` berilmasa, xarita avtomatik tarzda bepul OpenStreetMap qora rejimiga o'tadi.
