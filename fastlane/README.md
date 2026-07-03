fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios create_app

```sh
[bundle exec] fastlane ios create_app
```

App Store Connect da Lug'atchi app yozuvini yaratish (FASTLANE_PASSWORD kerak) — odatda kerak emas, app allaqachon mavjud

### ios upload

```sh
[bundle exec] fastlane ios upload
```

Lug'atchi IPA ni App Store Connect ga yuklash

### ios release

```sh
[bundle exec] fastlane ios release
```

App mavjud bo'lsa IPA yuklash; yo'q bo'lsa create_app + upload

### ios list_apps

```sh
[bundle exec] fastlane ios list_apps
```

Diagnostika: shu hisobdagi barcha app yozuvlarini ko'rsatish (o'qish uchun, hech narsa o'zgartirmaydi)

### ios check_screenshots

```sh
[bundle exec] fastlane ios check_screenshots
```

Diagnostika: joriy versiyada screenshot bor-yo'qligini tekshirish (o'qish uchun)

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Faqat matn metadata'ni yuklash (tavsif, kalit so'z, copyright va h.k.) — binary/screenshotga tegmaydi

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Faqat screenshotlarni yuklash — binary/matn metadata'ga tegmaydi

### ios submit

```sh
[bundle exec] fastlane ios submit
```

Tayyor versiyani Apple review'ga yuborish (binary/metadata/screenshotga tegmaydi, faqat submit qiladi)

### ios fix_review_requirements

```sh
[bundle exec] fastlane ios fix_review_requirements
```

Review uchun qolgan majburiy deklaratsiyalarni to'ldirish: yosh reytingi, kontent huquqi, narx (Free), data usage (ma'lumot yig'ilmaydi)

### ios check_build

```sh
[bundle exec] fastlane ios check_build
```

Diagnostika: versiyaga biriktirilgan build va device family holatini ko'rsatish

### ios dump_relationships

```sh
[bundle exec] fastlane ios dump_relationships
```

Diagnostika: app resource'ining xom relationships ro'yxatini chop etish (token hech qayerga yozilmaydi)

### ios set_free_pricing

```sh
[bundle exec] fastlane ios set_free_pricing
```

Narxni Free (0.00 USD, barcha hududlarda) qilib belgilash — appPriceSchedule orqali

### ios probe_privacy

```sh
[bundle exec] fastlane ios probe_privacy
```

Diagnostika: data usage / app privacy uchun mumkin bo'lgan yo'llarni sinab ko'rish

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
