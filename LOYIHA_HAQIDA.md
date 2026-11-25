# Qadam Qal'a — loyiha papkasi

Yurib hudud egallash o'yini (Flutter + Firebase).

## Nima qayerda

| Papka | Ichida |
|---|---|
| `lib/` | Ilova kodi (Flutter). Ekranlar: `lib/screens`, o'yin qoidalari: `lib/game` |
| `assets/images/` | Xarita va orol rasmlari (Figma AI) |
| `functions/` | Server kodi (Firebase Cloud Functions): hujum, masofa, klan, sovg'alar |
| `firestore.rules` | Ma'lumotlar bazasi himoyasi |
| `design/` | Dizayn ekranlari (8 ta, HTML). Onlayn nusxasi: https://claude.ai/artifact/9Qy4YnJjHN42pxAt7CNYqJ |
| `ios/`, `android/` | Telefon platformalari sozlamalari |

## Ishga tushirish (kompyuterda)

Kerak: Flutter, Xcode.

```bash
flutter pub get
flutter run
```

Sinov rejimi (offline, namunaviy raqiblar bilan) — standart.
Server bilan: `flutter run --dart-define=ONLINE=true`
(avval `flutterfire configure` bilan haqiqiy Firebase loyihasini ulash kerak).

## Server

```bash
cd functions && npm install && npm test
firebase deploy --only functions,firestore
```

## Qadamlar qayerdan olinadi
- **iPhone:** Apple Health (qadam + yurilgan masofa).
- **Android:** Health Connect (Google Fit, Samsung Health va telefonning qadam sensori shu yerga yozadi). Health Connect bo'lmasa, telefonning qadam sensori ishlatiladi.
- Telefon birinchi ochilishda bir marta ruxsat so'raydi. Do'konlar maxfiylik siyosatida buni yozishni talab qiladi.
- Google Play'ga chiqarishda Play Console'da "Health Connect" deklaratsiya formasini to'ldirish kerak.

## App Store'dan oldin qilinadigan ishlar
- `ios/Runner/Info.plist` dagi `FLTEnableImpeller = false` qatorini olib tashlash (faqat Intel Mac simulyatori uchun qo'yilgan).
- `lib/firebase_options.dart` ni `flutterfire configure` bilan haqiqiysiga almashtirish.
- Apple Developer hisobida HealthKit imkoniyatini yoqish, ikonka va maxfiylik siyosati.
