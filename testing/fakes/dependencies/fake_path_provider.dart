import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class FakePaths {
  static const String kTemporaryPath = 'temporaryPath';
  static const String kApplicationSupportPath = 'applicationSupportPath';
  static const String kLibraryPath = 'libraryPath';
  static const String kApplicationDocumentsPath = 'applicationDocumentsPath';
  static const String kExternalStoragePath = 'externalStoragePath';
  static const String kExternalCachePath = 'externalCachePath';
  static const String kDownloadsPath = 'downloadsPath';
}

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return FakePaths.kTemporaryPath;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return FakePaths.kApplicationSupportPath;
  }

  @override
  Future<String?> getLibraryPath() async {
    return FakePaths.kLibraryPath;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return FakePaths.kApplicationDocumentsPath;
  }

  @override
  Future<String?> getExternalStoragePath() async {
    return FakePaths.kExternalStoragePath;
  }

  @override
  Future<List<String>?> getExternalCachePaths() async {
    return <String>[FakePaths.kExternalCachePath];
  }

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    return <String>[FakePaths.kExternalStoragePath];
  }

  @override
  Future<String?> getDownloadsPath() async {
    return FakePaths.kDownloadsPath;
  }
}
