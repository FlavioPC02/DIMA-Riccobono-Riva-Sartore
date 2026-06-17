import 'package:flutter/material.dart';

class ScrollIndicator extends StatelessWidget {
  const ScrollIndicator({
    super.key,
    required this.pageCount,
    required this.currentPage,
    required this.isRound,
  });

  final int pageCount;
  final int currentPage;
  final bool isRound;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(pageCount, (i) {
        final isActive = i == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 2.5),
          width: 3,
          height: isActive ? 16 : 6,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}