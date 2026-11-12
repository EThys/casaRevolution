import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/casanayo_share_copy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr/qr.dart';
import 'package:share_plus/share_plus.dart';

/// Affiche l’invitation et enregistre l’image (Play Store sur Android, App Store sur iOS).
Future<void> showCasanayoInviteSheet(
  BuildContext context, {
  required String name,
  String? localImagePath,
  String? imageUrl,
}) {
  final storeUrl = Platform.isIOS ? CasanayoShareCopy.appStore : CasanayoShareCopy.playStore;
  final storeLabel = Platform.isIOS ? 'App Store' : 'Google Play';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _InviteSheet(
      name: name.trim().isEmpty ? 'CasaNayo' : name.trim(),
      localImagePath: localImagePath,
      imageUrl: imageUrl,
      storeUrl: storeUrl,
      storeLabel: storeLabel,
    ),
  );
}

class _InviteSheet extends StatefulWidget {
  final String name;
  final String? localImagePath;
  final String? imageUrl;
  final String storeUrl;
  final String storeLabel;

  const _InviteSheet({
    required this.name,
    required this.localImagePath,
    required this.imageUrl,
    required this.storeUrl,
    required this.storeLabel,
  });

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  static const _inviteChannel = MethodChannel('casa/invite_image');
  static const double _posterWidth = 360;
  static const double _posterHeight = 560;

  final GlobalKey _boundaryKey = GlobalKey();
  String? _busyKind;
  bool _ready = false;

  ImageProvider? get _avatar {
    final path = widget.localImagePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) return FileImage(file);
    }
    final url = widget.imageUrl?.trim() ?? '';
    if (url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _precache();
  }

  Future<void> _precache() async {
    final avatar = _avatar;
    if (avatar != null) {
      try {
        await precacheImage(avatar, context);
      } catch (_) {}
    }
    try {
      await precacheImage(const AssetImage('assets/images/logoCasa.png'), context);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<Uint8List?> _captureBytes() async {
    debugPrint('[CasaInvite] capture: debut');
    final captured = await _captureBoundary();
    if (_isPng(captured)) {
      debugPrint('[CasaInvite] capture: carte affichee ${captured!.length} octets');
      return captured;
    }
    debugPrint('[CasaInvite] capture: carte affichee indisponible, image de secours');
    try {
      final bytes = await renderCasaInviteCardPng(name: widget.name, storeUrl: widget.storeUrl);
      debugPrint('[CasaInvite] capture: secours ${bytes.length} octets');
      return bytes;
    } catch (error, stack) {
      debugPrint('[CasaInvite] capture: echec $error\n$stack');
      return null;
    }
  }

  bool _isPng(Uint8List? bytes) {
    if (bytes == null || bytes.length < 8) return false;
    return bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
  }

  Future<Uint8List?> _captureBoundary() async {
    for (var attempt = 0; attempt < 4; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
      final object = _boundaryKey.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary || !object.hasSize || object.size.isEmpty || object.debugNeedsPaint) {
        continue;
      }
      try {
        final image = await object.toImage(pixelRatio: 2);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null || data.lengthInBytes == 0) continue;
          return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        } finally {
          image.dispose();
        }
      } catch (error) {
        debugPrint('[CasaInvite] capture: tentative $attempt echouee $error');
      }
    }
    debugPrint('[CasaInvite] capture: aucune image de la carte affichee');
    return null;
  }

  Future<File?> _preparePng() async {
    final bytes = await _captureBytes();
    if (bytes == null) return null;
    final file = await _writeTempPng(bytes);
    if (!file.existsSync() || file.lengthSync() < 8) return null;
    return file;
  }

  Future<void> _share() async {
    debugPrint('[CasaInvite] partage: clic');
    if (_busyKind != null) {
      debugPrint('[CasaInvite] partage: ignore, action en cours $_busyKind');
      return;
    }
    setState(() => _busyKind = 'share');
    final host = Navigator.of(context, rootNavigator: true).context;
    try {
      final file = await _preparePng();
      if (file == null) {
        debugPrint('[CasaInvite] partage: fichier absent mounted=$mounted');
        _notify(host, 'Le partage n’a pas abouti. Réessayez.', error: true);
        return;
      }
      debugPrint('[CasaInvite] partage: fichier ${file.path} ${file.lengthSync()} octets');
      final route = ModalRoute.of(context);
      if (mounted) Navigator.of(context).pop();
      await route?.popped;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final image = XFile(file.path, mimeType: 'image/png', name: 'Invitation_CasaNayo.png');
      try {
        await Share.shareXFiles([image]);
        debugPrint('[CasaInvite] partage: menu ouvert');
      } catch (error, stack) {
        debugPrint('[CasaInvite] partage: share_plus echoue $error\n$stack');
        if (!Platform.isAndroid) rethrow;
        await _inviteChannel.invokeMethod<void>('sharePng', {'path': file.path});
        debugPrint('[CasaInvite] partage: menu Android ouvert');
      }
    } catch (error, stack) {
      debugPrint('[CasaInvite] partage: echec $error\n$stack');
      _notify(host, 'Le partage n’a pas abouti. Réessayez.', error: true);
    } finally {
      if (mounted) setState(() => _busyKind = null);
    }
  }

  Future<File> _writeTempPng(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Invitation_CasaNayo_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _notify(BuildContext host, String message, {bool error = false}) {
    if (!host.mounted) return;
    FancyNotification.show(
      host,
      message,
      isError: error,
      type: error ? NotificationType.error : NotificationType.success,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    _notify(context, message, error: true);
  }

  Future<void> _download() async {
    debugPrint('[CasaInvite] telechargement: clic');
    if (_busyKind != null) {
      debugPrint('[CasaInvite] telechargement: ignore, action en cours $_busyKind');
      return;
    }
    setState(() => _busyKind = 'download');
    try {
      final file = await _preparePng();
      if (!mounted || file == null) {
        debugPrint('[CasaInvite] telechargement: fichier absent mounted=$mounted');
        _showError('L’image n’a pas pu être enregistrée. Réessayez.');
        return;
      }
      debugPrint('[CasaInvite] telechargement: fichier ${file.path} ${file.lengthSync()} octets');
      if (Platform.isAndroid) {
        final saved = await _inviteChannel.invokeMethod<String>('saveToDownloads', {'path': file.path});
        debugPrint('[CasaInvite] telechargement: reponse Android $saved');
        if (!mounted) return;
        FancyNotification.show(
          context,
          saved == 'downloads'
              ? 'Invitation enregistrée dans Téléchargements, dossier CasaNayo.'
              : 'Invitation enregistrée dans la galerie, dossier CasaNayo.',
          isError: false,
        );
        return;
      }
      final docs = await getApplicationDocumentsDirectory();
      final folder = Directory('${docs.path}/CasaNayo');
      if (!await folder.exists()) await folder.create(recursive: true);
      await file.copy('${folder.path}/Invitation_CasaNayo.png');
      if (!mounted) return;
      FancyNotification.show(context, 'Invitation enregistrée.', isError: false);
    } catch (error, stack) {
      debugPrint('[CasaInvite] telechargement: echec $error\n$stack');
      _showError('L’image n’a pas pu être enregistrée. Réessayez.');
    } finally {
      if (mounted) setState(() => _busyKind = null);
    }
  }

  Widget _actionLabel(String label, String kind, {required bool onBlue}) {
    if (_busyKind != kind) {
      return Text(label, style: const TextStyle(fontWeight: FontWeight.w700));
    }
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: onBlue ? Colors.white : const Color(0xFF1976D2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DAE1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Votre invitation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1D26)),
              ),
              const SizedBox(height: 4),
              Text(
                'Le QR code ouvre ${widget.storeLabel}.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.58,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scaleW = constraints.maxWidth / _posterWidth;
                    final scaleH = constraints.maxHeight / _posterHeight;
                    final scale = scaleW < scaleH ? scaleW : scaleH;
                    return ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: _posterWidth * scale,
                          height: _posterHeight * scale,
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minWidth: _posterWidth,
                            maxWidth: _posterWidth,
                            minHeight: _posterHeight,
                            maxHeight: _posterHeight,
                            child: Transform.scale(
                              scale: scale,
                              alignment: Alignment.topCenter,
                              filterQuality: FilterQuality.medium,
                              child: RepaintBoundary(
                                key: _boundaryKey,
                                child: CasanayoInvitePoster(
                                  name: widget.name,
                                  avatar: _avatar,
                                  storeUrl: widget.storeUrl,
                                  storeLabel: widget.storeLabel,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busyKind != null ? null : _share,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1976D2),
                        side: const BorderSide(color: Color(0xFF1976D2)),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _actionLabel('Partager', 'share', onBlue: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busyKind != null ? null : _download,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _actionLabel('Télécharger', 'download', onBlue: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CasanayoInvitePoster extends StatelessWidget {
  final String name;
  final ImageProvider? avatar;
  final String storeUrl;
  final String storeLabel;

  const CasanayoInvitePoster({
    super.key,
    required this.name,
    required this.avatar,
    required this.storeUrl,
    required this.storeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 560,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B3A82), Color(0xFF1976D2), Color(0xFF4FC3F7)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -30,
              child: _bubble(160, Colors.white.withOpacity(0.08)),
            ),
            Positioned(
              bottom: 120,
              left: -50,
              child: _bubble(140, Colors.white.withOpacity(0.07)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Image.asset('assets/images/logoCasa.png', fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'CasaNayo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 72,
                      backgroundColor: const Color(0xFFE8EEF5),
                      backgroundImage: avatar,
                      child: avatar == null
                          ? const Icon(Icons.person_rounded, size: 68, color: Color(0xFF1976D2))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Je vous invite sur CasaNayo.\nMaisons, hôtels et services, au même endroit.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14, height: 1.35, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F7FB),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: CustomPaint(
                            size: const Size(108, 108),
                            painter: _QrPainter(storeUrl),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Téléchargez CasaNayo',
                                style: TextStyle(
                                  color: Color(0xFF1A1D26),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Scannez le QR code.\nDisponible sur $storeLabel.',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12.5,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _QrPainter extends CustomPainter {
  final String data;
  _QrPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final code = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M);
    final image = QrImage(code);
    final count = image.moduleCount;
    final cell = size.shortestSide / count;
    final paint = Paint()..color = const Color(0xFF0B3A82);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(Rect.fromLTWH(col * cell, row * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => oldDelegate.data != data;
}

/// Image d’invitation autonome, utilisée si la capture de l’écran échoue.
Future<Uint8List> renderCasaInviteCardPng({
  required String name,
  required String storeUrl,
}) async {
  const width = 1080.0;
  const height = 1680.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width, height),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(width, height),
        const [Color(0xFF0B3A82), Color(0xFF1976D2), Color(0xFF4FC3F7)],
        const <double>[0, 0.5, 1],
      ),
  );
  final title = TextPainter(
    text: const TextSpan(
      text: 'CasaNayo',
      style: TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.w800),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  title.paint(canvas, Offset((width - title.width) / 2, 220));
  final namePainter = TextPainter(
    text: TextSpan(
      text: name.trim().isEmpty ? 'CasaNayo' : name.trim(),
      style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w800),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: width - 160);
  namePainter.paint(canvas, Offset((width - namePainter.width) / 2, 560));
  final invite = TextPainter(
    text: const TextSpan(
      text: 'Je vous invite sur CasaNayo',
      style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w600),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  invite.paint(canvas, Offset((width - invite.width) / 2, 760));
  canvas.save();
  canvas.translate((width - 420) / 2, 900);
  canvas.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 420, 420), const Radius.circular(36)),
    Paint()..color = Colors.white,
  );
  canvas.translate(40, 40);
  _QrPainter(storeUrl).paint(canvas, const Size(340, 340));
  canvas.restore();
  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null || data.lengthInBytes < 8) {
      throw StateError('png');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}

/// Écran isolé, lancé seulement avec --dart-define=INVITE_DEBUG=true.
class InviteDebugApp extends StatelessWidget {
  const InviteDebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _InviteDebugHome(),
    );
  }
}

class _InviteDebugHome extends StatefulWidget {
  const _InviteDebugHome();

  @override
  State<_InviteDebugHome> createState() => _InviteDebugHomeState();
}

class _InviteDebugHomeState extends State<_InviteDebugHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showCasanayoInviteSheet(context, name: 'CasaNayo');
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}
