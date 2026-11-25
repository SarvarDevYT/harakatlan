# 🤖 Harakatlan — Android Loyihasini Ishga Tushirish va Build Qilish Yo'riqnomasi

Ushbu loyiha Flutter (Dart) frameworkida yozilgan bo'lib, Android qurilmalarida (telefon, planshet, emulyator) to'liq qo'llab-quvvatlanadi.

---

## 🛠️ 1. Kerakli Talablar
Guruhdoshingiz kompyuterida quyidagilar o'rnatilgan bo'lishi kerak:
- **Flutter SDK** (3.19+ yoki undan yuqori)
- **Android Studio** (Android SDK, Command-line Tools)
- **Java / JDK 17** (Android build uchun standart)
- Ulangan **Android telefon** (USB Debugging yoqilgan) yoki **Android Emulator**

---

## 🚀 2. Tezkor Ishga Tushirish (3 Qadamda)

Loyihaning asosiy papkasiga terminalda kiring va quyidagi buyruqlarni bajaring:

### 1-qadam: Kutubxonalarni yuklash
```bash
flutter clean
flutter pub get
```

### 2-qadam: Qurilmada sinab ko'rish / Ishga tushirish
```bash
flutter run
```
*Ilova avtomatik tarzda ulangan Android telefonda yoki emulyatorda ochiladi.*

---

## 📦 3. Tayyor Android APK Faylini Chiqarish

Agar sizga telefonga to'g'ridan-to'g'ri o'rnatiladigan **APK fayli** kerak bo'lsa:

```bash
flutter build apk --release
```

Build tugagach, tayyor APK fayl shu yerda bo'ladi:
📍 `build/app/outputs/flutter-apk/app-release.apk`
*(Ushbu faylni xohlagan Android telefonga Telegram yoki kabel orqali tashlab o'rnatish mumkin).*

---

## 🌐 4. Google Play Store uchun (AAB Bundle)

Agar ilovani Google Play Console ga yuklamoqchi bo'lsangiz:

```bash
flutter build appbundle --release
```

Tayyor bundle shu yerda bo'ladi:
📍 `build/app/outputs/bundle/release/app-release.aab`

---

## ⚙️ Muhim Android Sozlamalari (Loyiha ichida to'g'irlangan):
- **Package Name (ApplicationId):** `uz.qadamqala.qadam_qala`
- **Minimum SDK:** `26` (Android 8.0 Oreo va undan yuqori - Health Connect va qadam hisoblagich datchiklari uchun)
- **Target / Compile SDK:** `34` (Android 14)
- **Kerakli Ruxsatlar:** Qadam hisoblash (`ACTIVITY_RECOGNITION`), Internet, Kamera va Health Connect ruxsatnomalari `AndroidManifest.xml` ga to'liq kiritilgan.
- **Java/Kotlin versiyasi:** JVM 17, Kotlin Gradle Plugin.
