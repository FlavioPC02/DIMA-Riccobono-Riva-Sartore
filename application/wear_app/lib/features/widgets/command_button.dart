import 'package:flutter/material.dart';

class CommandButton extends StatelessWidget {
  const CommandButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.08,
            vertical: screenWidth * 0.03,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(screenWidth * 0.1),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: screenWidth * 0.07),
            SizedBox(width: screenWidth * 0.02),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.w600,
                ),
            ),
          ],
        ),
      ),
    );
  }
}