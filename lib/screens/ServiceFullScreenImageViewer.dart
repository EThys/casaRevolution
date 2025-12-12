import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ServiceFullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ServiceFullScreenImageViewer({
    Key? key,
    required this.imageUrls,
    required this.initialIndex,
  }) : super(key: key);

  @override
  _ServiceFullScreenImageViewerState createState() => _ServiceFullScreenImageViewerState();
}

class _ServiceFullScreenImageViewerState extends State<ServiceFullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Center(
                  child: Hero(
                    tag: 'service_image_$index',
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrls[index],
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Compteur d'images
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${_currentIndex + 1} / ${widget.imageUrls.length}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Bouton de fermeture
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 24),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}







