# ASR Application by DISC

Main:
![pipeline_main](https://gitlab.ewi.tudelft.nl/cse2000-software-project/2025-2026/cluster-i/09b/asr-application/badges/main/pipeline.svg)
![test_coverage_main](https://gitlab.ewi.tudelft.nl/cse2000-software-project/2025-2026/cluster-i/09b/asr-application/badges/main/coverage.svg) \
Development:
![pipeline_dev](https://gitlab.ewi.tudelft.nl/cse2000-software-project/2025-2026/cluster-i/09b/asr-application/badges/dev/pipeline.svg)
![test_coverage_dev](https://gitlab.ewi.tudelft.nl/cse2000-software-project/2025-2026/cluster-i/09b/asr-application/badges/dev/coverage.svg)

## Introduction

ASR Application by [DISC] is a speech-to-text application designed for people with dysarthria. It builds upon personalised Automatic Speech Recognition (ASR) models created by the the Delft Inclusive Speech Communications (DISC) lab at the Delft University of Technology. This application aims to be the bridge between research models and the people who want to use them.

## Table of contents

[TOC]

## Contributing

Community contributions of many kinds aid in the development of this application. Listed below are possible ways in which you can contribute.

##### Contributing through code

During this initial state of the application, it is not possible to contribute through code. This section will be updated once the project has been made public.

##### Financial contribution

Through the Delft University of Technology a crowdfunding campaign has begun for the development of this app. Please visit [the campaign website][TUD-crowdfund] or use the Donate Now button.

##### Contributing in other ways

If you are looking to contribute in a way not listed above, for example by providing a dataset of dysarthric speech, then please contact the team at [DISC] directly.

## 1. How to use the application
This section contains information on how to download the app for currently supported devices. If your device is not listed, then it might still be possible to build the application from the source code by following the instructions in the [development](#2-development) section.

### Android
Currently, the app is not available on the Play Store. However, it is possible to download an APK for Android through [artifacts][gitlab-artifacts]. For a development release; look for a job named `build_android_development`. For a production release; look for a job named `build_android_production`. Click on the arrow next to file count and download the `android-build-apk.zip` file. Unzip the file and click on each directory within until you see a file with the `.apk` extension. Please only install the application this way if you know what you are doing or have someone around that does.

## 2. Development
This section outlines how to develop and build the application locally. This can be used to get started with development or try to build the application for an unsupported device.

### Requirements
In order to develop the application the following system requirements must be met:
- [Flutter][Flutter-installation] must be installed. Use `flutter doctor` to verify whether everything works for your target device.

#### Recording audio

Recording audio is implemented through the [Record](https://pub.dev/packages/record) flutter package. For it to work, the following requirements must be met:

- Android: minimal SDK: 23, `android.permission.RECORD_AUDIO` is required.
- iOS: minimal SDK: 12, `NSMicrophoneUsageDescription` is required.
- macOS: minimal SDK: 10.15, `NSMicrophoneUsageDescription` is required.
- Windows: No additional requirements.
- Linux: dependent of `parecord`, `pactl` and `ffmpeg`.

### Getting started
Once the requirements above have been met, you are ready to clone this repository and get started on developing/building the application. When you start our with a fresh repository, you must first run the commands below in order to generate necessary files. Some of these are explained in further detail sections below, see: [localisations](#localisations), [mocking](#mocking).
```sh
flutter pub get --enforce-lockfile # retrieve dependencies through pub. 
dart run build_runner build # generate mocks used in tests
```

### Running the application
The easiest way to run the application is by following [Flutter's instructions for VS Code][Flutter-installation]. Otherwise, run the following command:
```sh
flutter build
```
This will show a list of available subcommands, each corresponding to a device type you are able to build the application for. Run the command again with the desired device to build the application and read the terminal output for the location of the build files.

### Localisations

Based on the official [Flutter.dev documentation _(accessed 8 May 2026)_](https://docs.flutter.dev/ui/internationalization)

- The `lib/l10n/arb` directory holds all translation files, where `app_en.arb` is used as the default and the fallback.
- When building the application (`flutter run`) or when running `flutter pub get` all language dart files will be generated inside `lib/l10n/generated`. While these files can be called inside the application to resolve a translation, it's not the preferred way.
- Inside a widget, you can import the `lib/l10n/l10n.dart` file and get a translated value by calling `context.l10n.<translation handle>` (e.g. `context.l10n.helloWorld`).

## 3. Testing

The application is tested in a variety of ways in order to ensure it works as expected and meets accessibility requirements. The sections below first outline the tools we use in our testing and then goes over the different test suites.

### Mocking

Mocking objects happens through [Mockito](https://pub.dev/packages/mockito).
At the top of the test file, you can add annotation as follows:
```dart
@GenerateNiceMocks([MockSpec<ClassToBeMocked>()])
```
Then run:
```sh
dart run build_runner build
```
This will create a neighboring file, which has the same name as the test file,
only with the extension of `.mocks.dart` instead of `.dart`. This file needs to be imported to make use of the mocks.
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

## 4. Docker

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

## 5. CI/CD

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
  This stage is for code and commit quality analysis.
  - `linting` :: runs `flutter analyze` to check code against the rules in [analysis_options.yaml](./analysis_options.yaml).
1. **Test**\
  The test stage runs a multitude of tests to ensure the code works as intended. Where applicable, coverage and other test data is reported back to GitLab.
  - `test_widgets` :: this is the main type of test and currently also includes unit tests. See [Flutter testing overview](https://docs.flutter.dev/testing/overview) for more information.
  - `test_accessibility` :: runs tests tagged as accessibility. On failure these tests will display a warning and the pipeline may still succeed. See also [Flutter accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing).
1. **Build**\
  The build stage is responsible for building the application and provides the application for supported platforms through [artifacts][gitlab-artifacts].
  - `build_development` :: runs the build pipelines for a debug versions on the supported platforms on a commit on the `dev` branch and merge requests that alter the build process.
  - `build_versioning` :: calculates the next version on a commit to the `main` branch.
  - `build_production` :: runs the build pipelines for release versions on the supported platforms on a commit to the `main` branch.
2. **Release**\
  The release creates a release tag on a commit to main and creates a commit to update version files.


[DISC]: https://disc.tudelft.nl/
[docker-repo]: https://hub.docker.com/repository/docker/mitchell3514/flutter/general
[gitlab-container-registry]: https://gitlab.ewi.tudelft.nl/cse2000-software-project/2025-2026/cluster-i/09b/asr-application/container_registry
[gitlab-artifacts]: https://gitlab.ewi.tudelft.nl/cse2000-software-project/2025-2026/cluster-i/09b/asr-application/-/artifacts
[Flutter-installation]: https://docs.flutter.dev/install
[Flutter accessibility testing]: https://docs.flutter.dev/ui/accessibility/accessibility-testing
[gitlab-artifacts]: https://gitlab.ewi.tudelft.nl/cse2000-software-project/2025-2026/cluster-i/09b/asr-application/-/artifacts
[TUD-crowdfund]: https://www.supporttudelft.nl/project/veelbelovend-spraakherkenningsmodel-voor-live-ondertiteling-van-mensen
