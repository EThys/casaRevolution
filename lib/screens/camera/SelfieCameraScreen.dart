import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class SelfieCameraScreen extends StatefulWidget {
  final Function(String) onImageCaptured;

  const SelfieCameraScreen({Key? key, required this.onImageCaptured}) : super(key: key);

  @override
  _SelfieCameraScreenState createState() => _SelfieCameraScreenState();
}

class _SelfieCameraScreenState extends State<SelfieCameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCameraInitialized = false;
  bool _isTorchOn = false;
  bool _isTakingPicture = false; // Flag to prevent multiple captures

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    // Filter for front camera
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller!.initialize();
    
    if (mounted) {
      await _initializeControllerFuture;
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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

  Future<void> _takePicture() async {
    if (_isTakingPicture || _controller == null || !_isCameraInitialized) {
      return;
    }

    try {
      setState(() => _isTakingPicture = true);

      // Verify initialization state
      if (!_controller!.value.isInitialized) {
        throw CameraException("NotInitialized", "La caméra n'est pas encore prête.");
      }

      final image = await _controller!.takePicture();

      if (mounted) {
        Navigator.pop(context, image.path);
        widget.onImageCaptured(image.path);
      }
    } catch (e) {
      print('❌ [SelfieCamera] Error taking picture: $e');
      if (mounted) {
        setState(() => _isTakingPicture = false);
        String errorMsg = "Erreur lors de la capture";
        if (e is CameraException && e.code == 'cameraInitializationRequired') {
          errorMsg = "La caméra redémarre, réessayez dans un instant";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _isCameraInitialized
              ? Center(child: CameraPreview(_controller!))
              : const Center(child: CircularProgressIndicator()),
          
          // Overlay
          if (_isCameraInitialized)
            CustomPaint(
              size: Size.infinite,
              painter: OverlayPainter(),
            ),

          // Instructions
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  "Selfie uniquement",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Placez votre visage dans l'ovale",
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
              child: Opacity(
                opacity: (_isCameraInitialized && !_isTakingPicture) ? 1.0 : 0.5,
                child: GestureDetector(
                  onTap: (_isCameraInitialized && !_isTakingPicture) ? _takePicture : null,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 4),
                    ),
                    child: Center(
                      child: _isTakingPicture 
                        ? const CircularProgressIndicator(color: Colors.red, strokeWidth: 3)
                        : Container(
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

class OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Create a path for the entire screen
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create the oval cutout
    final ovalWidth = size.width * 0.7;
    final ovalHeight = size.height * 0.5;
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: ovalWidth,
      height: ovalHeight,
    );
    
    final cutoutPath = Path()..addOval(ovalRect);

    // Combine paths to create the hole
    final finalPath = Path.combine(
      PathOperation.difference,
      path,
      cutoutPath,
    );

    canvas.drawPath(finalPath, paint);

    // Draw border for the oval
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
