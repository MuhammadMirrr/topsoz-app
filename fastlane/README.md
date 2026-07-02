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

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Faqat matn metadata'ni yuklash (tavsif, kalit so'z, copyright va h.k.) — binary/screenshotga tegmaydi

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
