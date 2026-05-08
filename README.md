# asr_application

A new Flutter project.


## Localisations
Based on the official [Flutter.dev documentation _(accessed 8 May 2026)_](https://docs.flutter.dev/ui/internationalization)

- The `lib/l10n/arb` directory holds all translation files, where `app_en.arb` is used as the default and the fallback.
- When building the application (`flutter run`) or when running `flutter pub get` all language dart files will be generated inside `lib/l10n/generated`. While these files can be called inside the application to resolve a translation, it's not the preferred way.
- Inside a widget, you can import the `lib/l10n/l10n.dart` file and get a translated value by calling `context.l10n.<translation handle>` (e.g. `context.l10n.helloWorld`).
