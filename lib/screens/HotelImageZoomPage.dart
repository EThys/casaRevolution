import 'dart:io';

import 'package:casa/utils/cache/HotelImageCache.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// Galerie plein écran : glisser d'une photo à l'autre et pincer pour zoomer.
class HotelImageZoomPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String? title;

  const HotelImageZoomPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.title,
  });

  static Future<void> open(
    BuildContext context,
    List<String> images, {
    int initialIndex = 0,
    String? title,
  }) async {
    if (images.isEmpty) return;
    var index = initialIndex;
    if (index < 0) index = 0;
    if (index >= images.length) index = images.length - 1;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => HotelImageZoomPage(
          images: images,
          initialIndex: index,
          title: title,
        ),
      ),
    );
  }

  @override
  State<HotelImageZoomPage> createState() => _HotelImageZoomPageState();
}

class _HotelImageZoomPageState extends State<HotelImageZoomPage> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    HotelImageCache.instance.prefetchUrls(widget.images);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ImageProvider<Object> _provider(String url) {
    final resolved = HotelImageCache.resolve(url);
    final local = HotelImageCache.instance.syncPath(resolved);
    if (local != null) return FileImage(File(local));
    return NetworkImage(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _controller,
            itemCount: widget.images.length,
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            onPageChanged: (i) => setState(() => _index = i),
            loadingBuilder: (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: _provider(widget.images[index]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 4,
                initialScale: PhotoViewComputedScale.contained,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white70,
                  size: 56,
                ),
              );
            },
          ),
          Positioned(
            top: top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.images.length > 1
                        ? '${widget.title ?? 'Photos'}  ${_index + 1}/${widget.images.length}'
                        : (widget.title ?? 'Photo'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
