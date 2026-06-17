import 'package:flutter/material.dart';
import 'package:wear_plus/wear_plus.dart';

class ScreenShell extends StatelessWidget {
  const ScreenShell({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isRound = WatchShape.of(context) == WearShape.round;

    // Adaptive padding based on screen size and shape
    // Round screens need more padding to avoid the "corners" and top/bottom curves
    final horizontalPadding = isRound ? screenSize.width * 0.12 : screenSize.width * 0.05;
    final verticalPadding = isRound ? screenSize.height * 0.15 : screenSize.height * 0.08;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Header Label
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: isRound ? MainAxisAlignment.center : MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: screenSize.width * 0.045,
                  color: Colors.white38,
                ),
                SizedBox(width: screenSize.width * 0.015),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: screenSize.width * 0.035,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Padding(
            padding: EdgeInsets.only(top: screenSize.height * 0.06),
            child: child,
          ),
        ],
      ),
    );
  }
}