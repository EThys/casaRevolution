import 'dart:io';

import 'package:image/image.dart' as img;

/// Génère une icône carrée 1024x1024 à partir de `assets/images/icon.png`.
///
/// - Conserve les proportions (contain), centre l'image, fond transparent.
/// - Sortie : `assets/images/icon_1024.png`
void main() {
  final input = File('assets/images/icon.png');
  if (!input.existsSync()) {
    stderr.writeln('Input missing: ${input.path}');
    exitCode = 2;
    return;
  }

  final bytes = input.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    stderr.writeln('Could not decode PNG: ${input.path}');
    exitCode = 3;
    return;
  }

  const size = 1024;
  final outCanvas = img.Image(width: size, height: size);
  img.fill(outCanvas, color: img.ColorRgba8(0, 0, 0, 0));

  final w = decoded.width;
  final h = decoded.height;
  final scale = size / (w > h ? w : h);
  final newW = (w * scale).round();
  final newH = (h * scale).round();

  final resized = img.copyResize(
    decoded,
    width: newW,
    height: newH,
    interpolation: img.Interpolation.average,
  );

  final x = ((size - newW) / 2).round();
  final y = ((size - newH) / 2).round();
  img.compositeImage(outCanvas, resized, dstX: x, dstY: y);

  final outFile = File('assets/images/icon_1024.png');
  outFile.createSync(recursive: true);
  outFile.writeAsBytesSync(img.encodePng(outCanvas, level: 6));

  stdout.writeln('OK: wrote ${outFile.path} (${size}x$size)');
}

