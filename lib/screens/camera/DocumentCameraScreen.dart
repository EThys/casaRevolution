import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class DocumentCameraScreen extends StatefulWidget {
  final Function(String) onImageCaptured;
  final String label; // "Recto" or "Verso", etc.

  const DocumentCameraScreen({
    Key? key, 
    required this.onImageCaptured,
    required this.label,
  }) : super(key: key);

  @override
  _DocumentCameraScreenState createState() => _DocumentCameraScreenState();
}

class _DocumentCameraScreenState extends State<DocumentCameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCameraInitialized = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    // Prioritize back camera
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.veryHigh, // Needs good quality for text reading
      enableAudio: false,
    );

    _initializeControllerFuture = _controller!.initialize();
    
    if (mounted) {
      try {
        await _initializeControllerFuture;
        setState(() {
          _isCameraInitialized = true;
        });
      } catch (e) {
        print("Camera init error: $e");
      }
    }
  }

  Future<void> _toggleTorch() async {
    if (_controller == null || !_isCameraInitialized) return;
    
    try {
      if (_isTorchOn) {
        await _controller!.setFlashMode(FlashMode.off);
        setState(() {
          _isTorchOn = false;
        });
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
        setState(() {
          _isTorchOn = true;
        });
      }
    } catch (e) {
      print("Error toggling torch: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'activer le flash sur cet appareil')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        return;
      }

      await _initializeControllerFuture;
      
      // Optional: Set flash mode if needed, or leave auto
      // await _controller!.setFlashMode(FlashMode.off);

      final image = await _controller!.takePicture();

      // Close camera screen first and pass the image path back
      if (mounted) {
        Navigator.pop(context, image.path);
        // Call the callback after navigation to avoid setState on unmounted widget
        widget.onImageCaptured(image.path);
      }
    } catch (e) {
      print('Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la capture: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: CameraPreview(_controller!)),
          
          // Overlay
          CustomPaint(
            size: Size.infinite,
            painter: IDCardOverlayPainter(),
          ),

          // Instructions & Header
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  "Photo ${widget.label}",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Placez le document dans le cadre",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ],
            ),
          ),

          // Capture Button
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _takePicture,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey, width: 4),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Back button
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Torch Button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: Icon(
                _isTorchOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
                size: 30,
              ),
              onPressed: _toggleTorch,
            ),
          ),
        ],
      ),
    );
  }
}

class IDCardOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Create a path for the entire screen
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create the rectangular cutout (credit card ratio is ~1.586)
    // We'll give it some padding
    final padding = 20.0;
    final cardWidth = size.width - (padding * 2);
    final cardHeight = cardWidth / 1.586; // Standard ID card ratio

    final center = Offset(size.width / 2, size.height / 2);
    final cardRect = Rect.fromCenter(
      center: center,
      width: cardWidth,
      height: cardHeight,
    );
    
    final cutoutPath = Path()..addRRect(RRect.fromRectAndRadius(cardRect, Radius.circular(16)));

    // Combine paths to create the hole
    final finalPath = Path.combine(
      PathOperation.difference,
      path,
      cutoutPath,
    );

    canvas.drawPath(finalPath, paint);

    // Draw border for the rectangle
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    canvas.drawRRect(RRect.fromRectAndRadius(cardRect, Radius.circular(16)), borderPaint);
    
    // Draw corners (optional visual cues)
    // ... could add corner brackets if needed
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
