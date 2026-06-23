import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

///   Expect comparisons   ///

/// Piecewise close comparison of a 1D list.
void expectListClose(
  List<double> actual,
  List<double> expected,
  double epsilon,
) {
  expect(
    actual.length,
    expected.length,
    reason: "Shape [${actual.length}] doesn't match [${expected.length}]",
  );

  for (var i = 0; i < actual.length; i++) {
    expect(actual[i], closeTo(expected[i], epsilon));
  }
}

/// Piecewise close comparison of a 2D list.
void expectMatrixClose(
  List<List<double>> actual,
  List<List<double>> expected,
  double epsilon,
) {
  expect(
    actual.length,
    expected.length,
    reason:
        "Shape [${actual.length}, ${actual.first.length}] doesn't match [${expected.length}, ${expected.first.length}]",
  );

  for (var i = 0; i < expected.length; i++) {
    expectListClose(actual[i], expected[i], epsilon);
  }
}

///   Importing external files   ///

/// Import a json file with structure `[[...], [...], ...]` and import it as a 2D List of doubles.
Future<List<List<double>>> jsonToMatrix(String filePath) async {
  final file = File(filePath);
  final raw = await file.readAsString();
  final data = jsonDecode(raw) as List<dynamic>;
  return data
      .map(
        (row) =>
            (row as List<dynamic>).map((v) => (v as num).toDouble()).toList(),
      )
      .toList();
}

/// Import a WAV file and return only its PCM data, skipping all RIFF chunks
/// that precede `data` (fmt, LIST/INFO, etc.).
Future<Uint8List> wavToPcm16(String wavPath) async {
  final wavBytes = await File(wavPath).readAsBytes();
  final view = ByteData.sublistView(wavBytes);

  if (wavBytes.length < 12 ||
      String.fromCharCodes(wavBytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(wavBytes.sublist(8, 12)) != 'WAVE') {
    throw Exception('Not a valid WAV file');
  }

  var offset = 12;
  while (offset + 8 <= wavBytes.length) {
    final tag = String.fromCharCodes(wavBytes.sublist(offset, offset + 4));
    final size = view.getUint32(offset + 4, Endian.little);
    if (tag == 'data') {
      return Uint8List.sublistView(wavBytes, offset + 8, offset + 8 + size);
    }
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }

  throw Exception('WAV `data` chunk not found');
}

String markdownData(WidgetTester tester) {
  return tester.widget<Markdown>(find.byType(Markdown)).data;
}
