import 'dart:async';

import 'package:snaptest/snaptest.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SnaptestSettings.global = SnaptestSettings(
    devices: [
      Devices.android.bigPhone,
      Devices.android.mediumPhone,
      Devices.android.smallPhone,
    ],
    orientations: {.portrait},
    blockText: false,
    renderImages: true,
    renderShadows: true,
    includeDeviceFrame: true,
    pathPrefix: './.snaptest/',
  );

  await testMain();
}
