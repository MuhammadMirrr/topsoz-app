# Topso'z

**Offline Uzbek–English–Russian dictionary for Android.** Built with Flutter + SQLite FTS5.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-Dart_3.10.7-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://developer.android.com)

> Choose your language: **[English](#english)** · **[Oʻzbekcha](#oʻzbekcha)** · **[Русский](#русский)** · **[العربية](#العربية)**

---

## English

### Overview

Topso'z is a free, offline trilingual dictionary for Android. It aggregates **10 open-source dictionary sources** into a single pre-built SQLite database with full-text search (FTS5), supporting both **Latin and Cyrillic** Uzbek scripts. No internet connection is required.

### Features

- 🔎 Trilingual lookup: **Uzbek ⇄ English ⇄ Russian**
- ⚡ Instant search with 300ms debounce
- 🔤 Latin ↔ Cyrillic transliteration (handles digraphs: `sh`, `ch`, `o'`, `g'`, `ng`…)
- ⭐ Favorites and search history
- 🌓 Light & dark themes, adjustable font scale
- 📶 Fully offline — the dictionary ships inside the APK (~80 MB)
- 📱 Google Mobile Ads (banner, interstitial, rewarded, native) with 24h ad-free reward

### Stack

- **Framework:** Flutter (Dart `^3.10.7`)
- **State:** `flutter_riverpod`
- **Routing:** `go_router`
- **DB:** `sqflite` + `sqflite_common_ffi` + `sqlite3_flutter_libs` (for FTS5)
- **Ads:** `google_mobile_ads`
- **Data pipeline:** Python 3 (`tools/`)

### Getting started

```bash
flutter pub get
flutter analyze          # lint (must stay clean)
flutter run              # debug on a connected device
flutter build apk        # release APK
flutter build appbundle  # release AAB for Google Play
```

### Rebuilding the dictionary

```bash
pip install -r tools/requirements.txt
python tools/download_sources.py   # fetch 10 source dictionaries → raw_data/
python tools/build_database.py     # parse + dedupe + build FTS5 → saved_database/topsoz.db
cp saved_database/topsoz.db assets/db/topsoz.db
```

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md).
Report security issues privately per [SECURITY.md](SECURITY.md).

### License

MIT © 2026 Muhammad Mirqobilov — see [LICENSE](LICENSE).

---

## Oʻzbekcha

### Haqida

Topsoʻz — Android uchun bepul, oflayn uch tilli lugʻat. U **10 ta ochiq manbali lugʻatni** yagona SQLite bazaga birlashtirib, FTS5 toʻliq matnli qidiruvni qoʻllab-quvvatlaydi. Lotin va kirill yozuvlari ikkalasi ham ishlaydi. Internet talab qilinmaydi.

### Xususiyatlar

- 🔎 Uch tilli qidiruv: **Oʻzbek ⇄ Ingliz ⇄ Rus**
- ⚡ 300ms debouncing bilan tez qidiruv
- 🔤 Lotin ↔ Kirill transliteratsiya (`sh`, `ch`, `oʻ`, `gʻ`, `ng` digraflar toʻgʻri ishlaydi)
- ⭐ Sevimlilar va qidiruv tarixi
- 🌓 Yorugʻ va qorongʻi mavzular, shrift oʻlchamini sozlash
- 📶 Toʻliq oflayn — lugʻat APK ichida (~80 MB)
- 📱 AdMob reklamalari (banner, interstitsial, rewarded, native). 24 soat ichida 3 ta rewarded video = 24 soat reklamasiz

### Texnologiyalar

- **Framework:** Flutter (Dart `^3.10.7`)
- **Holat:** `flutter_riverpod`
- **Routing:** `go_router`
- **Baza:** `sqflite` + `sqlite3_flutter_libs`
- **Reklama:** `google_mobile_ads`
- **Baza yigʻuvchi:** Python 3 (`tools/`)

### Ishga tushirish

```bash
flutter pub get
flutter analyze          # linter (xatosiz oʻtishi shart)
flutter run              # debug rejim
flutter build apk        # relizli APK
flutter build appbundle  # Google Play uchun AAB
```

### Lugʻat bazasini qayta qurish

```bash
pip install -r tools/requirements.txt
python tools/download_sources.py   # 10 ta manbani yuklab olish
python tools/build_database.py     # parse + dedupe + FTS5 indeks
cp saved_database/topsoz.db assets/db/topsoz.db
```

### Hissa qoʻshish

Qarang: [CONTRIBUTING.md](CONTRIBUTING.md) va [Code of Conduct](CODE_OF_CONDUCT.md).
Xavfsizlik muammolarini [SECURITY.md](SECURITY.md) orqali maxfiy xabar qiling.

### Litsenziya

MIT © 2026 Muhammad Mirqobilov — [LICENSE](LICENSE)ga qarang.

---

## Русский

### Обзор

Topso'z — бесплатный офлайн-словарь для Android с поддержкой **узбекского, английского и русского** языков. Он объединяет **10 открытых словарных источников** в единую предварительно собранную базу SQLite с полнотекстовым поиском (FTS5). Поддерживаются обе узбекские письменности — **латиница и кириллица**. Интернет не требуется.

### Возможности

- 🔎 Трёхъязычный поиск: **узбекский ⇄ английский ⇄ русский**
- ⚡ Мгновенный поиск с задержкой 300 мс (debounce)
- 🔤 Транслитерация латиница ↔ кириллица (корректно обрабатывает диграфы)
- ⭐ Избранное и история поиска
- 🌓 Светлая и тёмная темы, регулируемый размер шрифта
- 📶 Полностью офлайн — словарь встроен в APK (~80 МБ)
- 📱 Google Mobile Ads (баннеры, межстраничные, с вознаграждением, нативные). 3 просмотренных rewarded-видео за сутки = 24 часа без рекламы

### Технологии

- **Фреймворк:** Flutter (Dart `^3.10.7`)
- **Стейт-менеджмент:** `flutter_riverpod`
- **Навигация:** `go_router`
- **БД:** `sqflite` + `sqlite3_flutter_libs` (FTS5)
- **Реклама:** `google_mobile_ads`
- **Сборка данных:** Python 3 (`tools/`)

### Запуск

```bash
flutter pub get
flutter analyze          # линтер (должен проходить без ошибок)
flutter run              # debug
flutter build apk        # релизный APK
flutter build appbundle  # AAB для Google Play
```

### Пересборка словарной базы

```bash
pip install -r tools/requirements.txt
python tools/download_sources.py   # скачать 10 источников
python tools/build_database.py     # парсинг + дедуп + FTS5
cp saved_database/topsoz.db assets/db/topsoz.db
```

### Вклад

См. [CONTRIBUTING.md](CONTRIBUTING.md) и [Code of Conduct](CODE_OF_CONDUCT.md).
Сообщайте о проблемах безопасности приватно согласно [SECURITY.md](SECURITY.md).

### Лицензия

MIT © 2026 Muhammad Mirqobilov — см. [LICENSE](LICENSE).

---

## العربية

<div dir="rtl">

### نظرة عامة

**Topso'z** قاموس مجاني غير متصل بالإنترنت لأجهزة Android يدعم ثلاث لغات: **الأوزبكية والإنجليزية والروسية**. يَجمع **10 مصادر قواميس مفتوحة المصدر** في قاعدة بيانات SQLite مُسبقة البناء مع بحث كامل النص عبر FTS5، ويدعم الكتابة الأوزبكية بالحرفين **اللاتيني والسيريلي**. لا يحتاج إلى اتصال بالإنترنت.

### المزايا

- 🔎 بحث ثلاثي اللغات: **أوزبكية ⇄ إنجليزية ⇄ روسية**
- ⚡ بحث فوري مع تأخير 300 مللي ثانية (debounce)
- 🔤 نقل حرفي بين اللاتيني والسيريلي (يعالج الحروف المركّبة بشكل صحيح)
- ⭐ المفضلة وسجل البحث
- 🌓 وضعان فاتح وداكن، حجم خط قابل للتعديل
- 📶 يعمل دون إنترنت بالكامل — القاموس مضمَّن داخل ملف APK (~80 ميجابايت)
- 📱 إعلانات Google Mobile Ads (بانر، بيني، تحفيزي، أصلي). 3 إعلانات تحفيزية خلال 24 ساعة = 24 ساعة بدون إعلانات

### التقنيات المستخدمة

- **الإطار:** Flutter (Dart `^3.10.7`)
- **إدارة الحالة:** `flutter_riverpod`
- **التوجيه:** `go_router`
- **قاعدة البيانات:** `sqflite` + `sqlite3_flutter_libs` (FTS5)
- **الإعلانات:** `google_mobile_ads`
- **خطّ بناء البيانات:** Python 3 (`tools/`)

### التشغيل

```bash
flutter pub get
flutter analyze          # فحص اللينتر (يجب أن يمرّ دون أخطاء)
flutter run              # وضع التطوير
flutter build apk        # بناء APK للإصدار
flutter build appbundle  # بناء AAB لمتجر Google Play
```

### إعادة بناء قاعدة القاموس

```bash
pip install -r tools/requirements.txt
python tools/download_sources.py   # جلب المصادر العشرة
python tools/build_database.py     # تحليل + إزالة التكرار + فهرس FTS5
cp saved_database/topsoz.db assets/db/topsoz.db
```

### المساهمة

راجع [CONTRIBUTING.md](CONTRIBUTING.md) و[مدونة السلوك](CODE_OF_CONDUCT.md).
أبلِغ عن الثغرات الأمنية بشكل خاص وفق [SECURITY.md](SECURITY.md).

### الترخيص

MIT © 2026 Muhammad Mirqobilov — راجع [LICENSE](LICENSE).

</div>

---

## Author

**Muhammad Mirqobilov** — [@MuhammadMirrr](https://github.com/MuhammadMirrr) · muhammadmirqobilov@gmail.com
