import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

@isTestGroup
void Function(void Function(T param) test) each<T>(
  String description,
  List<T> params,
) =>
    (Function(T) test) => group(description, () => params.forEach(test));
