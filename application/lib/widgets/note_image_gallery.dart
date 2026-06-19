import 'dart:io';

import 'package:flutter/material.dart';

class NoteImageGallery extends StatefulWidget {
  final List<String> imageUrls;

  const NoteImageGallery({super.key, required this.imageUrls});

  @override
  State<NoteImageGallery> createState() => _NoteImageGalleryState();
}

class _NoteImageGalleryState extends State<NoteImageGallery> {
  late final ScrollController _scrollController;
  
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scroll(double offset) {
    _scrollController.animateTo(
      _scrollController.offset + offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemWidth = MediaQuery.of(context).size.width - 72 + 8;
    final hasMultipleImages = widget.imageUrls.length > 1;

    return SizedBox(
      height: 500,
      child: Stack(
        alignment: Alignment.center,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              int newIndex = (notification.metrics.pixels / itemWidth).round();
              
              newIndex = newIndex.clamp(0, widget.imageUrls.length - 1);

              if (newIndex != _currentIndex) {
                setState(() {
                  _currentIndex = newIndex;
                });
              }
              return false;
            },
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: hasMultipleImages 
                  ? const PageScrollPhysics() 
                  : const NeverScrollableScrollPhysics(),
              itemCount: widget.imageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, imgIndex) {
                final url = widget.imageUrls[imgIndex];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 72, 
                    child: url.startsWith('http')
                        ? Image.network(
                            url,
                            fit: BoxFit.fitHeight, 
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Theme.of(context).colorScheme.primary,
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                          )
                        : Image.file(
                            File(url),
                            fit: BoxFit.fitHeight,
                          ),
                  ),
                );
              },
            ),
          ),
          
          if (hasMultipleImages && _currentIndex > 0)
            Positioned(
              left: 8,
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                child: IconButton(
                  icon: Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.onSecondary),
                  onPressed: () => _scroll(-itemWidth),
                ),
              ),
            ),
          if (hasMultipleImages && _currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 8,
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                child: IconButton(
                  icon: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSecondary),
                  onPressed: () => _scroll(itemWidth), 
                ),
              ),
            ),
        ],
      ),
    );
  }
}