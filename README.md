# asr_application

A new Flutter project.

## Localisations

Based on the official [Flutter.dev documentation _(accessed 8 May 2026)_](https://docs.flutter.dev/ui/internationalization)

- The `lib/l10n/arb` directory holds all translation files, where `app_en.arb` is used as the default and the fallback.
- When building the application (`flutter run`) or when running `flutter pub get` all language dart files will be generated inside `lib/l10n/generated`. While these files can be called inside the application to resolve a translation, it's not the preferred way.
- Inside a widget, you can import the `lib/l10n/l10n.dart` file and get a translated value by calling `context.l10n.<translation handle>` (e.g. `context.l10n.helloWorld`).

## Testing

### Accessibility

Tests tagged with `accessibility` use [Flutter accessibility testing] to verify the UI meets four criteria:

- `androidTapTargetGuideline` :: checks that tappable nodes have a minimum size of 48 by 48 pixels on Android
- `iOSTapTargetGuideline` :: checks that tappable nodes have a minimum size of 44 by 44 pixels on iOS
- `labeledTapTargetGuideline` :: checks that touch targets with a tap or long press action are labeled
- `textContrastGuideline` :: checks that elements meet the minimum text contrast levels

```sh
flutter test --tags=accessibility # runs the accessibility test suites
```

## Docker

An overview and use-cases of the Dockerfile's contained in this repository is listed below. Up-to-date versions of images can be found [here][docker-repo]. For more information visit the [Docker documentation](https://docs.docker.com/).

- [Dockerfile](./Dockerfile) \
  This Dockerfile specifies the basic installation of Flutter on an Ubuntu 24.04 based system. The base target sets up Flutter including any system requirements. The dev target builds upon the base image by copying the cwd and installing Flutter dependencies.

  ```sh
  docker build -t <tag> -f Dockerfile --target base .  # builds base image as <tag>
  docker build -t <tag> -f Dockerfile --target dev . # builds dev image as <tag>

  # start from a different image:
  docker [...] --buildarg BUILDER_IMAGE=<image>
  # use custom Flutter SDK version (Linux, stable).
  docker [...] --buildarg FLUTTER_VERSION=<version>
  ```

- [Dockerfile.android](./Dockerfile.android) \
  The android version is based on [circleci's Android](https://github.com/CircleCI-Public/cimg-android) container. Similar to the Linux toolchain there are two targets. The base target sets up Flutter including system requirements to built for Android. The dev targets builds upon the base image by copying the cwd and installing Flutter dependencies.

  ```sh
  docker build -t <tag> -f Dockerfile.android --target base .  # builds base image as <tag>
  docker build -t <tag> -f Dockerfile.android --target dev . # builds dev image as <tag>

  # start from a different image:
  docker [...] --buildarg BUILDER_IMAGE=<image>
  # use custom Flutter SDK version (Linux, stable).
  docker [...] --buildarg FLUTTER_VERSION=<version>
  ```

## CI/CD

This repository makes use of [GitLab CI/CD](https://docs.gitlab.com/ci/) to perform automated actions. The pipeline specification can be found in the [.gitlab-ci.yml](./.gitlab-ci.yml) file.

### Images

The pipeline images are hosted on [docker hub][docker-repo]. These are based on Dockerfile specifications found in this repository.

### Stages

Below is an overview of the jobs per stage in the pipeline.

1. **Setup**\
   The setup stage is responsible for setting up the repository for the next stages.
   - `deps` :: retrieves dependencies and runs dependency scripts.
   - `generate_mocks` :: generates [Mockito](https://pub.dev/packages/mockito) mocks.

1. **Analyze**\
   This stage is for code and commit quality analysis.\
   - `linting` :: runs `flutter analyze` to check code against the rules in [analysis_options.yaml](./analysis_options.yaml).

1. **Test**\
   The test stage runs a multitude of tests to ensure the code works as intended. Where applicable, coverage and other test data is reported back to GitLab.
   - `widget_tests` :: this is the main type of test and currently also includes unit tests. See [Flutter testing overview](https://docs.flutter.dev/testing/overview) for more information.
   - `accessibility_tests` :: runs tests tagged as accessibility. On failure these tests will display a warning and the pipeline may still succeed. See also [Flutter accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing).
1. **Build** \
   The build stage is responsible for building the application and proving a release bundle for download. This only runs on commits to the `main` and `dev` branches or when the pipeline specification is altered.
   - `build_android` :: builds the application and releases an APK for installation on Android.

[docker-repo]: https://hub.docker.com/repository/docker/mitchell3514/flutter/general
[Flutter accessibility testing]: https://docs.flutter.dev/ui/accessibility/accessibility-testing
