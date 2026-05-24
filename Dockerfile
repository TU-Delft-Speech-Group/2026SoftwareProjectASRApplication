ARG BUILDER_IMAGE=ubuntu:24.04
FROM ${BUILDER_IMAGE} AS base
ARG FLUTTER_VERSION=3.41.9

# Add system packages required by Flutter and build tools
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  git \
  unzip \
  xz-utils \
  zip \
  libglu1-mesa \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  libgtk-3-dev \
  mesa-utils \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Install Flutter under /opt for a root-based, CI-friendly location
WORKDIR /opt
ADD https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz /opt/flutter.tar.xz
RUN tar -xf /opt/flutter.tar.xz -C /opt/ \
  && rm /opt/flutter.tar.xz
ENV PATH="$PATH:/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin"

# Verify installation (runs as root in the image)
RUN flutter doctor --no-prompt || true

# Set CI workdir to GitLab Runner checkout path so dependencies are fetched where the runner expects
WORKDIR /builds/cse2000-software-project/2025-2026/cluster-i/09b/asr-application
ENV PUB_CACHE=/opt/.pub-cache
RUN git config --global --add safe.directory /opt/flutter

FROM base AS ci

# Copy pubspec files into the CI workdir and fetch dependencies
COPY pubspec.* ./
RUN flutter pub get --enforce-lockfile
RUN flutter pub global activate junitreport

FROM ci AS dev

COPY . .
RUN flutter gen-l10n
RUN dart run build_runner build
