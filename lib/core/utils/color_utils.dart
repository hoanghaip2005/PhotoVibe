import 'package:flutter/material.dart';

Color colorFromHex(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

List<Color> colorsFromHex(List<String> values) {
  return values.map(colorFromHex).toList();
}
