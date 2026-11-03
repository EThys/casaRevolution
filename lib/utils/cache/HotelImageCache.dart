import 'dart:io';

import 'package:casa/models/PropertyModel.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Photos d'hôtel enregistrées dans les documents de l'app.
/// Au retour sur la fiche, le fichier local s'affiche sans nouveau téléchargement.
class HotelImageCache {
  HotelImageCache._();
  static final HotelImageCache instance = HotelImageCache._();

  static const _indexKey = 'hotel_image_files';

  Map<String, String>? _index;
  Directory? _dir;

  static List<String> urlsOf(PropertyModel hotel) {
    final urls = <String>[];
    void add(String? raw) {
      final url = (raw ?? '').trim();
      if (url.startsWith('http')) urls.add(url);
    }

    add(hotel.image);
    final cover = hotel.propertyImage;
    if (cover != null) {
      for (final image in cover) {
        add(image.path);
      }
    }
    final rooms = hotel.hotelStructure;
    if (rooms != null) {
      for (final room in rooms) {
        final photos = room.images;
        if (photos == null) continue;
        for (final image in photos) {
          add(image.path);
        }
      }
    }
    return urls;
  }

  /// Chemin local déjà connu. Lecture synchrone pour afficher la photo tout de suite.
  String? syncPath(String url) {
    final stored = _indexMap()[_key(url)];
    if (stored == null || stored.isEmpty) return null;
    if (File(stored).existsSync()) return stored;
    return null;
  }

  Future<void> prefetchUrls(Iterable<String> urls) async {
    for (final url in urls) {
      final trimmed = url.trim();
      if (trimmed.isEmpty || syncPath(trimmed) != null) continue;
      await fileFor(trimmed);
    }
  }

  Future<File?> fileFor(String url) async {
    final trimmed = url.trim();
    if (!trimmed.startsWith('http')) return null;
    final existing = syncPath(trimmed);
    if (existing != null) return File(existing);

    try {
      final dir = await _directory();
      final file = File(p.join(dir.path, _fileName(trimmed)));
      if (await file.exists() && await file.length() > 32) {
        _remember(trimmed, file.path);
        return file;
      }

      final response = await http
          .get(Uri.parse(trimmed))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      await file.writeAsBytes(response.bodyBytes, flush: true);
      _remember(trimmed, file.path);
      return file;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _indexMap() {
    final cached = _index;
    if (cached != null) return cached;
    final raw = GetStorage().read(_indexKey);
    final map = <String, String>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value != null) map['$key'] = '$value';
      });
    }
    _index = map;
    return map;
  }

  void _remember(String url, String path) {
    final index = _indexMap();
    final key = _key(url);
    if (index[key] == path) return;
    index[key] = path;
    GetStorage().write(_indexKey, index);
  }

  Future<Directory> _directory() async {
    final existing = _dir;
    if (existing != null) return existing;
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'hotel_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  String _key(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return uri.replace(query: '', fragment: '').toString();
  }

  String _fileName(String url) {
    final key = _key(url);
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final ext = p.extension(Uri.tryParse(key)?.path ?? '');
    final safeExt = ext.length >= 2 && ext.length <= 5 ? ext : '.jpg';
    return 'h$hash$safeExt';
  }
}

class HotelCachedImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color placeholderColor;
  final Widget? error;

  const HotelCachedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholderColor = const Color(0xFFE5E7EB),
    this.error,
  });

  @override
  State<HotelCachedImage> createState() => _HotelCachedImageState();
}

class _HotelCachedImageState extends State<HotelCachedImage> {
  File? _file;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final local = HotelImageCache.instance.syncPath(widget.url);
    if (local != null) {
      _file = File(local);
    } else {
      _load();
    }
  }

  @override
  void didUpdateWidget(HotelCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    final local = HotelImageCache.instance.syncPath(widget.url);
    _failed = false;
    if (local != null) {
      _file = File(local);
    } else {
      _file = null;
      _load();
    }
  }

  Future<void> _load() async {
    final file = await HotelImageCache.instance.fileFor(widget.url);
    if (!mounted) return;
    setState(() {
      _file = file;
      _failed = file == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_file != null) {
      child = Image.file(
        _file!,
        fit: widget.fit,
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        gaplessPlayback: true,
      );
    } else if (_failed) {
      child = widget.error ??
          ColoredBox(
            color: widget.placeholderColor,
            child: const Icon(Icons.image_not_supported_rounded),
          );
    } else {
      child = ColoredBox(color: widget.placeholderColor);
    }

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      child: child,
    );
  }
}
