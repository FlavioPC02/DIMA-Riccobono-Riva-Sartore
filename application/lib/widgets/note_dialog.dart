import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:application/core/models/activity_note.dart';

class NoteDialog extends StatefulWidget {
  final ActivityNote? existingNote;
  const NoteDialog({super.key, this.existingNote});

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late final TextEditingController _controller;
  List<String> _imageUrls = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existingNote?.text ?? '');
    _imageUrls = List.from(widget.existingNote?.imageUrls ?? []);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _imageUrls.addAll(images.map((e) => e.path));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      title: Text(widget.existingNote == null ? 'New Note' : 'Edit Note'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('note_text_field'),
                controller: _controller,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Write your note here...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              
              if (_imageUrls.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final url = _imageUrls[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: url.startsWith('http') 
                                ? Image.network(url, height: 120, width: 120, fit: BoxFit.cover)
                                : Image.file(File(url), height: 120, width: 120, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () => setState(() => _imageUrls.removeAt(index)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text('Attach Photos', style: TextStyle(color: Theme.of(context).colorScheme.secondary,)),
                  style: OutlinedButton.styleFrom(
                    iconColor: Theme.of(context).colorScheme.secondary,
                    minimumSize: const Size(200, 48),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        ),
        FilledButton(
          key: const ValueKey('save_note_button'),
          onPressed: () {
            if (_controller.text.trim().isNotEmpty || _imageUrls.isNotEmpty) {
              Navigator.pop(context, {
                'text': _controller.text.trim(),
                'imageUrls': _imageUrls,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}