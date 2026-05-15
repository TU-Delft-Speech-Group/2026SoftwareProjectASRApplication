import 'package:flutter/widgets.dart';

class FixedWidthContainer extends StatelessWidget {
  const FixedWidthContainer({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
