# asr_application

A new Flutter project.

## Localisations

Based on the official [Flutter.dev documentation _(accessed 8 May 2026)_](https://docs.flutter.dev/ui/internationalization)

- The `lib/l10n/arb` directory holds all translation files, where `app_en.arb` is used as the default and the fallback.
- When building the application (`flutter run`) or when running `flutter pub get` all language dart files will be generated inside `lib/l10n/generated`. While these files can be called inside the application to resolve a translation, it's not the preferred way.
- Inside a widget, you can import the `lib/l10n/l10n.dart` file and get a translated value by calling `context.l10n.<translation handle>` (e.g. `context.l10n.helloWorld`).

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

## CI/CD

This repository makes use of [GitLab CI/CD](https://docs.gitlab.com/ci/) to perform automated actions. The pipeline specification can be found in the [.gitlab-ci.yml](./.gitlab-ci.yml) file.

### Images

The pipeline images are hosted on [docker hub][docker-repo]. These are based on Dockerfile specifications found in this repository.

### Stages

Below is an overview of the different stages of the pipeline.

- **Setup** \
  The first stage sets up the dependencies for Flutter to be used in future stages. This stage should complete successfully for the pipeline to continue.
- **Tests** \
  The second stage runs the defined tests and reports coverage and test data back to GitLab. All tests should complete successfully for the pipeline to continue.
- **Build** \
  The build stage is responsible for building the application and proving a release bundle for download. This only runs on commits to the `main` and `dev` branches or when the pipeline specification is altered.

[docker-repo]: https://hub.docker.com/repository/docker/mitchell3514/flutter/general
