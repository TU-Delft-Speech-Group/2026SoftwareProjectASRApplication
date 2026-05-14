ARG BUILDER_IMAGE=ubuntu:24.04
FROM ${BUILDER_IMAGE} AS base
ARG  FLUTTER_VERSION=3.41.9

# Add dependencies 
RUN apt-get update && apt-get install -yqq --no-install-recommends \
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
  && rm -rf /var/lib/apt/lists/*

# Create app user
RUN addgroup app && adduser app --ingroup app
USER app
WORKDIR /home/app

# Download Flutter
ADD --chown=app:app https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz /home/app/flutter.tar.xz
RUN tar -xf /home/app/flutter.tar.xz -C /home/app/ \
  && rm /home/app/flutter.tar.xz
ENV PATH="/home/app/flutter/bin:/home/app/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Verify installation
RUN flutter doctor

FROM base AS dev

COPY --chown=app:app . /home/app/asr
WORKDIR /home/app/asr

RUN flutter pub get --enforce-lockfile
