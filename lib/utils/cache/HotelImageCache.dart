import 'dart:io';

import 'package:casa/models/PropertyModel.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
  final Map<String, Future<File?>> _pending = {};

  /// Une adresse relative devient une URL absolue affichable.
  static String resolve(String raw) {
    final url = raw.trim();
    if (url.isEmpty || url.toLowerCase() == 'null') return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    final origin = Constantes.URL_BASE.endsWith('/')
        ? Constantes.URL_BASE.substring(0, Constantes.URL_BASE.length - 1)
        : Constantes.URL_BASE;
    if (url.startsWith('/')) return '$origin$url';
    return '${Constantes.URL_IMAGES}$url';
  }

  static List<String> urlsOf(PropertyModel hotel) {
    final urls = <String>[];
    void add(String? raw) {
      final url = resolve(raw ?? '');
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
    final stored = _indexMap()[_key(resolve(url))];
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

  Future<File?> fileFor(String url) => ensure(url);

  /// Fichier local, puis copie du cache déjà téléchargé, puis réseau.
  Future<File?> ensure(String raw) {
    final trimmed = resolve(raw);
    if (!trimmed.startsWith('http')) return Future.value(null);
    final existing = syncPath(trimmed);
    if (existing != null) return Future.value(File(existing));
    final pending = _pending[trimmed];
    if (pending != null) return pending;
    final future = _ensure(trimmed, raw.trim());
    _pending[trimmed] = future;
    return future.whenComplete(() => _pending.remove(trimmed));
  }

  Future<File?> _ensure(String url, String raw) async {
    final adopted = await _adopt(url, url) ??
        (raw == url ? null : await _adopt(url, raw));
    if (adopted != null) return adopted;
    return _download(url);
  }

  Future<File?> _adopt(String url, String cacheKey) async {
    if (cacheKey.isEmpty) return null;
    try {
      final info = await DefaultCacheManager().getFileFromCache(cacheKey);
      if (info == null || !await info.file.exists()) return null;
      return _writeBytes(url, await info.file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  Future<File?> _writeBytes(String url, List<int> bytes) async {
    if (!_looksLikeImage(bytes)) return null;
    final dir = await _directory();
    final file = File(p.join(dir.path, _fileName(url)));
    await file.writeAsBytes(bytes, flush: true);
    _remember(url, file.path);
    return file;
  }

  Future<File?> _download(String url) async {
    try {
      final dir = await _directory();
      final file = File(p.join(dir.path, _fileName(url)));
      if (await file.exists() && await _isImageFile(file)) {
        _remember(url, file.path);
        return file;
      }
      if (await file.exists()) {
        await file.delete();
      }

      final response = await http.get(
        Uri.parse(url),
        headers: const {'Accept': 'image/*,*/*'},
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      return _writeBytes(url, response.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  void forget(String url) {
    final key = _key(resolve(url));
    final path = _indexMap().remove(key);
    GetStorage().write(_indexKey, _indexMap());
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  bool _looksLikeImage(List<int> bytes) {
    if (bytes.length < 12) return false;
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    if (bytes[0] == 0x89 && bytes[1] == 0x50) return true;
    if (bytes[0] == 0x47 && bytes[1] == 0x49) return true;
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes.length > 12) return true;
    return false;
  }

  Future<bool> _isImageFile(File file) async {
    try {
      if (await file.length() < 32) return false;
      final head = await file.openRead(0, 16).fold<List<int>>(
            <int>[],
            (previous, chunk) => previous..addAll(chunk),
          );
      return _looksLikeImage(head);
    } catch (_) {
      return false;
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
  final Widget? loading;
  final Widget? error;

  const HotelCachedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholderColor = const Color(0xFFE5E7EB),
    this.loading,
    this.error,
  });

  @override
  State<HotelCachedImage> createState() => _HotelCachedImageState();
}

class _HotelCachedImageState extends State<HotelCachedImage> {
  File? _file;
  late String _url;
  bool _preferNetwork = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bind(widget.url);
  }

  @override
  void didUpdateWidget(HotelCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    _bind(widget.url);
  }

  void _bind(String raw) {
    _url = HotelImageCache.resolve(raw);
    _preferNetwork = false;
    final local = HotelImageCache.instance.syncPath(_url);
    _file = local == null ? null : File(local);
    _ready = _file != null || !_url.startsWith('http');
    if (!_ready) _warm(_url);
  }

  Future<void> _warm(String url) async {
    final file = await HotelImageCache.instance.ensure(url);
    if (!mounted || _url != url) return;
    setState(() {
      if (file != null) {
        _file = file;
        _preferNetwork = false;
      }
      _ready = true;
    });
  }

  Widget _loadingBox() {
    return widget.loading ??
        ColoredBox(
          color: widget.placeholderColor,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
  }

  Widget _missingBox() {
    return widget.error ??
        ColoredBox(
          color: widget.placeholderColor,
          child: const Icon(Icons.image_not_supported_rounded),
        );
  }

  void _dropBrokenFile() {
    HotelImageCache.instance.forget(_url);
    if (!mounted) return;
    setState(() {
      _file = null;
      _preferNetwork = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_file != null && !_preferNetwork) {
      child = Image.file(
        _file!,
        fit: widget.fit,
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _dropBrokenFile());
          return _networkOrError();
        },
      );
    } else {
      child = _networkOrError();
    }

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      child: child,
    );
  }

  Widget _networkOrError() {
    if (!_url.startsWith('http')) return _missingBox();
    return Image.network(
      _url,
      fit: widget.fit,
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      gaplessPlayback: true,
      loadingBuilder: (context, image, progress) {
        if (progress == null) return image;
        return _loadingBox();
      },
      errorBuilder: (_, __, ___) {
        final local = HotelImageCache.instance.syncPath(_url);
        if (local != null) {
          return Image.file(
            File(local),
            fit: widget.fit,
            width: widget.width ?? double.infinity,
            height: widget.height ?? double.infinity,
            gaplessPlayback: true,
          );
        }
        return _ready ? _missingBox() : _loadingBox();
      },
    );
  }
}