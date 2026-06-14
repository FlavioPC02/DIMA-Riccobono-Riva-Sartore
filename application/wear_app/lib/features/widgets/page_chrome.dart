import 'package:flutter/material.dart';

import 'package:wear_app/features/models/page_descriptor.dart';

class PageChrome extends StatelessWidget {
  const PageChrome({
    super.key,
    required this.descriptor,
    required this.pageIndex,
  });

  final PageDescriptor descriptor;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF16211D),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            ),
            child: Icon(
              descriptor.icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descriptor.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  descriptor.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white60,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}