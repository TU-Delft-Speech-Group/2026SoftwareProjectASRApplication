# asr_application

A new Flutter project.

## Recording Audio

Recording audio is implemented through the [Record](https://pub.dev/packages/record) flutter package.

- Android: minimal SDK: 23, `android.permission.RECORD_AUDIO` is required.
- iOS: minimal SDK: 12, `NSMicrophoneUsageDescription` is required.
- macOS: minimal SDK: 10.15, `NSMicrophoneUsageDescription` is required.
- Windows: No additional requirements.
- Linux: dependent of `parecord`, `pactl` and `ffmpeg`.

## Localisations

Based on the official [Flutter.dev documentation _(accessed 8 May 2026)_](https://docs.flutter.dev/ui/internationalization)

- The `lib/l10n/arb` directory holds all translation files, where `app_en.arb` is used as the default and the fallback.
- When building the application (`flutter run`) or when running `flutter pub get` all language dart files will be generated inside `lib/l10n/generated`. While these files can be called inside the application to resolve a translation, it's not the preferred way.
- Inside a widget, you can import the `lib/l10n/l10n.dart` file and get a translated value by calling `context.l10n.<translation handle>` (e.g. `context.l10n.helloWorld`).

## Testing

### Mocking

Mocking objects happens through [Mockito](https://pub.dev/packages/mockito).
At the top of the test file, you can add annotation like `@GenerateNiceMocks([MockSpec<ClassToBeMocked>()])`.
When Running `dart run build_runner build`, a neighboring file will be created, which has the same name as the test file,
but with the extension of `.mocks.dart` instead of `.dart`. This file needs to be imported to make use of the mocks.
The mocked classes are renamed to `MockClassToBeMocked`.

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

An overview and use-cases of the Dockerfile's contained in this repository is listed below. Pre-built versions of images that are used in CI can also be found [here][docker-repo]. Images that are automatically built during CI are available [here][gitlab-container-registry]. For more information visit the [Docker documentation](https://docs.docker.com/).

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

The pre-built pipeline images are hosted on [docker hub][docker-repo]. Images created within the pipeline are available through [GitLab container registry][gitlab-container-registry]. The images in both repositories are based on the Dockerfiles found in this repository.

### Stages

Below is an overview of the jobs per stage in the pipeline.

1. **Setup**\
   The setup stage is responsible for setting up the repository for the next stages.
   - `setup_image` :: builds the correct Docker image version for CI if it is not yet available.
   - `setup_mocks` :: generates [Mockito](https://pub.dev/packages/mockito) mocks.
   - `setup_translations` :: generates translations (see [localisation section](#localisations)).
1. **Analyze**\
   This stage is for code and commit quality analysis.\
   - `linting` :: runs `flutter analyze` to check code against the rules in [analysis_options.yaml](./analysis_options.yaml).
1. **Test**\
   The test stage runs a multitude of tests to ensure the code works as intended. Where applicable, coverage and other test data is reported back to GitLab.
   - `test_widgets` :: this is the main type of test and currently also includes unit tests. See [Flutter testing overview](https://docs.flutter.dev/testing/overview) for more information.
   - `test_accessibility` :: runs tests tagged as accessibility. On failure these tests will display a warning and the pipeline may still succeed. See also [Flutter accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing).
1. **Build** \
   The build stage is responsible for building the application and provides the application for supported platforms through [artifacts][gitlab-artifacts].
   - `build_development` :: runs the build pipelines for a debug versions on the supported platforms on a commit on the `dev` branch and merge requests that alter the build process.
   - `build_production` :: runs the build pipelines for release versions on the supported platforms on a commit to the `main` branch.

[docker-repo]: https://hub.docker.com/repository/docker/mitchell3514/flutter/general
[gitlab-container-registry]: https://gitlab.ewi.tudelft.nl/cse2000-software-project/2025-2026/cluster-i/09b/asr-application/container_registry
[gitlab-artifacts]: https://gitlab.ewi.tudelft.nl/cse2000-software-project/2025-2026/cluster-i/09b/asr-application/-/artifacts
[Flutter accessibility testing]: https://docs.flutter.dev/ui/accessibility/accessibility-testing
