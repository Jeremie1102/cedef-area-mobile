import 'dart:io';

import 'package:flutter/material.dart';

/// Aperçu plein écran des photos d'un lot (sélection en cours ou déjà
/// enregistrées), avec zoom et défilement entre les photos. Ne permet aucune
/// modification : uniquement la consultation.
class PhotoViewerScreen extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const PhotoViewerScreen({super.key, required this.paths, this.initialIndex = 0});

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.paths.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.paths.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) {
          final file = File(widget.paths[index]);
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: file.existsSync()
                  ? Image.file(file, fit: BoxFit.contain)
                  : const Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 64),
            ),
          );
        },
      ),
    );
  }
}
