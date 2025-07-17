import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/models/PropertyImageModel.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatefulWidget {
  final List<PropertyImageModel> images;
  final int initialIndex;

  const FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
    Key? key,
  }) : super(key: key);

  @override
  _FullScreenImageViewerState createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              final image = widget.images[index];
              final imagePath = image.path ?? '';
              final correctedPath = imagePath.startsWith('/')
                  ? imagePath.substring(1)
                  : imagePath;
              final imageUrl = '${Constantes.URL_IMAGES}$correctedPath';

              return GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Center(
                  child: Hero(
                    tag: 'property_image_${widget.images[index].PropertyId}_$index',
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => Icon(Icons.error),
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}