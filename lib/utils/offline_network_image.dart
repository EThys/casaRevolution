import 'dart:ui' as ui;

import 'package:casa/utils/cache/HotelImageCache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

/// Photo réseau qui reste visible hors connexion une fois enregistrée sur l'appareil.
class OfflineNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext context, String url)? placeholder;
  final Widget Function(BuildContext context, String url, Object error)? errorWidget;
  final Duration? fadeInDuration;
  final Duration? fadeOutDuration;

  const OfflineNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration,
    this.fadeOutDuration,
  });

  @override
  Widget build(BuildContext context) {
    final image = HotelCachedImage(
      url: imageUrl,
      fit: fit ?? BoxFit.cover,
      width: width,
      height: height,
      loading: placeholder?.call(context, imageUrl),
      error: errorWidget?.call(context, imageUrl, 'offline'),
    );
    final fade = fadeInDuration;
    if (fade == null) return image;
    return AnimatedSwitcher(
      duration: fade,
      reverseDuration: fadeOutDuration,
      child: image,
    );
  }
}

/// Même source que [OfflineNetworkImage], pour les avatars et les fonds.
class OfflineImageProvider extends ImageProvider<OfflineImageProvider> {
  final String url;

  OfflineImageProvider(String raw) : url = HotelImageCache.resolve(raw);

  @override
  Future<OfflineImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<OfflineImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    OfflineImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1,
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final file = await HotelImageCache.instance.ensure(url);
    if (file == null) {
      throw StateError('Image indisponible hors connexion');
    }
    final bytes = await file.readAsBytes();
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) {
    return other is OfflineImageProvider && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}
