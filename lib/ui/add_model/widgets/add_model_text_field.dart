import 'package:flutter/material.dart';

import '../../core/theme.dart';

class AddModelTextField extends StatelessWidget {
  const AddModelTextField({
    super.key,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.colors.black,
            fontSize: context.fontSize.body,
            fontFamily: context.fontFamily.body,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: TextField(
            keyboardType: keyboardType,
            style: TextStyle(
              color: context.colors.black,
              fontSize: 13,
              fontFamily: context.fontFamily.body,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: context.colors.black,
                fontSize: 10,
                fontFamily: context.fontFamily.body,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              enabledBorder: _border(context),
              focusedBorder: _border(context),
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(BuildContext context) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: context.colors.black, width: 2),
    );
  }
}
