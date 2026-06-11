import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists the user's currently selected ASR model name to a JSON file in
/// the application's documents directory, so the choice survives app
/// restarts.
class ActiveModelStore {
  ActiveModelStore({Future<Directory> Function()? documentsDir})
      : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDir;

  static const _fileName = 'active_model.json';
  static const _nameKey = 'name';

  Future<String?> get() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final name = json[_nameKey];
      return name is String && name.isNotEmpty ? name : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> set(String? name) async {
    final file = await _file();
    if (name == null || name.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.writeAsString(jsonEncode({_nameKey: name}));
  }

  Future<File> _file() async {
    final dir = await _documentsDir();
    return File(p.join(dir.path, _fileName));
  }
}
