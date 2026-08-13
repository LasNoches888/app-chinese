import 'package:flutter/material.dart';

class HeartsRow extends StatelessWidget {
  final int hearts;
  final int max;

  const HeartsRow({super.key, required this.hearts, this.max = 5});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        max,
        (i) => Icon(
          i < hearts ? Icons.favorite : Icons.favorite_border,
          color: Colors.red,
          size: 20,
        ),
      ),
    );
  }
}
