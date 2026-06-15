class CtcLogitsLayout {
  final int time;
  final int vocab;

  const CtcLogitsLayout({required this.time, required this.vocab});

  factory CtcLogitsLayout.fromShape(List<int> shape) {
    if (shape.length == 2) {
      return CtcLogitsLayout(time: shape[0], vocab: shape[1]);
    }
    if (shape.length == 3 && shape[0] == 1) {
      return CtcLogitsLayout(time: shape[1], vocab: shape[2]);
    }
    if (shape.length == 3 && shape[1] == 1) {
      return CtcLogitsLayout(time: shape[0], vocab: shape[2]);
    }
    throw ArgumentError('Unsupported CTC logits shape: $shape');
  }

  void validateLogitsLength(int length) {
    final expected = time * vocab;
    if (length != expected) {
      throw ArgumentError(
        'CTC logits length $length does not match layout '
        'time=$time vocab=$vocab (expected $expected)',
      );
    }
  }
}
