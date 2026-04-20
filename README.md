# Topso'z

**O'zbek–Ingliz–Rus offline lug'at ilovasi.**

Flutter/Dart asosida yozilgan mobil ilova. SQLite bilan ishlaydigan offline lug'at — internet talab qilmaydi.

## Xususiyatlar

- 3 tilli lug'at: **O'zbek ⇄ Ingliz ⇄ Rus**
- Tez qidiruv (debouncing bilan)
- Lotin ↔ Kirill transliteratsiya
- Sevimlilar va qidiruv tarixi
- Onboarding (tanishuv) oynasi
- Qorong'i rejim (dark theme)
- Offline SQLite baza (~80MB, ilova bilan bundle qilingan)
- Banner va native reklamalar (Google Mobile Ads)

## Stack

- **Framework:** Flutter (Dart SDK ^3.10.7)
- **State:** Riverpod (flutter_riverpod)
- **Routing:** go_router
- **Database:** sqflite + sqlite3_flutter_libs
- **Ads:** google_mobile_ads
- **Ma'lumot qurish (tools/):** Python 3

## Loyiha tuzilmasi

```
lib/
  core/          # theme, services, utils, widgetlar
  data/          # database, modellar, repositoriylar
  features/      # search, favorites, history, settings, onboarding, splash
  routing/       # app router
assets/
  db/            # topsoz.db (offline lug'at bazasi, ~80MB)
  images/        # logo va ikonkalar
android/         # Android platforma sozlamalari
tools/           # Python skriptlari (lug'at bazasini yig'ish)
test/            # Flutter testlari
docs/            # Feature graphic (Play Store uchun)
```

## Ishga tushirish

**Talablar:** Flutter SDK, Android SDK (API 21+)

```bash
# Paketlarni o'rnatish
flutter pub get

# Ulangan qurilmani tekshirish
flutter devices

# Debug rejimda ishga tushirish
flutter run
```

**APK yaratish:**

```bash
flutter build apk --release
```

## Lug'at bazasini qayta qurish

`assets/db/topsoz.db` fayli `tools/` papkasidagi Python skriptlar yordamida yig'iladi. Manba fayllari `raw_data/` papkasida saqlanadi (repoga kiritilmagan — juda katta).

```bash
cd tools
pip install -r requirements.txt
python download_sources.py   # manba lug'atlarni yuklab olish
python build_database.py     # SQLite bazasini yig'ish
python enrich_database.py    # qo'shimcha ma'lumotlar bilan to'ldirish
python search_index.py       # FTS indeks yaratish
```

## Muallif

**Muhammad Mirqobilov** — [@MuhammadMirrr](https://github.com/MuhammadMirrr)

## Litsenziya

Barcha huquqlar himoyalangan. © 2026
