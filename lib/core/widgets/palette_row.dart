import 'package:flutter/material.dart';

import '../utils/color_utils.dart';

class PaletteRow extends StatelessWidget {
  const PaletteRow({required this.paletteHex, this.size = 14, super.key});

  final List<String> paletteHex;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final hex in paletteHex)
          Container(
            width: size,
            height: size,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              color: colorFromHex(hex),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.4),
            ),
          ),
      ],
    );
  }
}
