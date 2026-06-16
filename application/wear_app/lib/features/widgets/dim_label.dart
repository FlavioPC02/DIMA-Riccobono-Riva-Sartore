import 'package:flutter/material.dart';

class DimLabel extends StatelessWidget {
  const DimLabel({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.35),
        fontSize: (screenWidth * 0.045).clamp(8.0, 12.0),
        letterSpacing: 0.8,
      ),
    );
  }
}
