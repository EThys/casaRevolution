import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Sous-dossiers de `CasaNayo/` sous **Téléchargements** ou stockage public (Android).
enum CasaNayoExportKind {
  /// Bons de visite / réservations (BookingHistory, BookingVisit).
  reservation,

  /// Demandes d’intervention / sollicitations (MyServices, RequestIntervention).
  solicitation,
}

/// Libellé court pour les toasts (évite d’afficher un chemin technique `Android/data/...`).
/// Ouvre le sélecteur système de dossier ; `null` si l’utilisateur annule ou en cas d’échec.
Future<Directory?> pickExportDirectoryOrNull() async {
  try {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null || path.trim().isEmpty) return null;
    return Directory(path.trim());
  } catch (_) {
    return null;
  }
}

/// Libellé lisible pour un dossier choisi par l’utilisateur (nom du dossier ou fin de chemin).
String describePickedDirectoryPathForUser(String absolutePath) {
  final normalized = absolutePath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  final segs = normalized.split('/').where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return absolutePath;
  if (segs.length == 1) return segs.first;
  return '…/${segs[segs.length - 2]}/${segs.last}';
}

String describeExportDirectoryForUser(Directory dir) {
  final p = dir.path.replaceAll('\\', '/');
  if (p.contains('/Download/CasaNayo') || p.contains('/download/CasaNayo')) {
    return 'Téléchargements → CasaNayo';
  }
  if (p.endsWith('/CasaNayo') || p.contains('/CasaNayo/')) {
    if (p.contains('Documents')) {
      return 'Documents de l’app → CasaNayo';
    }
    return 'dossier CasaNayo sur le téléphone';
  }
  if (p.contains('/Download') || p.contains('/download')) {
    return 'Téléchargements';
  }
  return 'Fichiers de l’application';
}

String _casaNayoSubPath(CasaNayoExportKind kind) {
  switch (kind) {
    case CasaNayoExportKind.reservation:
      return 'reservations';
    case CasaNayoExportKind.solicitation:
      return 'solicitations';
  }
}

/// Racine type `/storage/emulated/0` à partir du chemin `…/Android/data/.../files`.
Future<Directory?> _androidStorageRoot() async {
  try {
    final ext = await getExternalStorageDirectory();
    if (ext == null) return null;
    final parts = ext.path.split('/');
    final androidIdx = parts.indexOf('Android');
    if (androidIdx > 0) {
      return Directory(parts.sublist(0, androidIdx).join('/'));
    }
  } catch (_) {}
  return null;
}

Future<Directory?> _tryCreate(Directory dir) async {
  try {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  } catch (_) {
    return null;
  }
}

/// Dossier d’export PDF : en priorité **Téléchargements/CasaNayo/…** (visible dans l’app Fichiers),
/// puis `casaNayo/…` à la racine du stockage, puis dossier Téléchargements système, puis documents app.
Future<Directory> getCasaNayoExportDirectory(CasaNayoExportKind kind) async {
  final sub = _casaNayoSubPath(kind);

  if (Platform.isAndroid) {
    final root = await _androidStorageRoot();
    if (root != null) {
      // 1) Priorité : Download/CasaNayo/… (comportement attendu par les utilisateurs)
      final downloadCasa = Directory('${root.path}/Download/CasaNayo/$sub');
      final ok1 = await _tryCreate(downloadCasa);
      if (ok1 != null) return ok1;

      // 2) Variante minuscule « download » (certains appareils)
      final downloadLower = Directory('${root.path}/download/CasaNayo/$sub');
      final ok2 = await _tryCreate(downloadLower);
      if (ok2 != null) return ok2;

      // 3) Ancien chemin racine /casaNayo/…
      final legacy = Directory('${root.path}/casaNayo/$sub');
      final ok3 = await _tryCreate(legacy);
      if (ok3 != null) return ok3;
    }

    // 4) Chemin direct (certains émulateurs / politiques)
    final primary = Directory('/storage/emulated/0/Download/CasaNayo/$sub');
    final ok4 = await _tryCreate(primary);
    if (ok4 != null) return ok4;

    // 5) API path_provider (souvent sous Android/data/.../files/Download — dernier recours avant documents)
    try {
      final dl = await getDownloadsDirectory();
      if (dl != null) {
        final nested = Directory('${dl.path}/CasaNayo/$sub');
        final ok5 = await _tryCreate(nested);
        if (ok5 != null) return ok5;
      }
    } catch (_) {}
  }

  // iOS / fallback : Documents de l’app, sous-dossier explicite
  final root = await getApplicationDocumentsDirectory();
  final d = Directory('${root.path}/CasaNayo/$sub');
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

/// Dossier pour factures / PDF génériques : **Download** public si possible, sinon équivalent.
Future<Directory> getUserDownloadExportDirectory() async {
  if (Platform.isAndroid) {
    final storageRoot = await _androidStorageRoot();
    if (storageRoot != null) {
      for (final name in ['Download', 'download']) {
        final dir = Directory('${storageRoot.path}/$name/CasaNayo');
        final ok = await _tryCreate(dir);
        if (ok != null) return ok;
      }
    }
    for (final path in [
      '/storage/emulated/0/Download/CasaNayo',
      '/storage/emulated/0/download/CasaNayo',
    ]) {
      final ok = await _tryCreate(Directory(path));
      if (ok != null) return ok;
    }
  }

  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      final dir = Directory('${downloads.path}/CasaNayo');
      final ok = await _tryCreate(dir);
      if (ok != null) return ok;
    }
  } catch (_) {}

  if (Platform.isAndroid) {
    final ext = await getExternalStorageDirectory();
    if (ext != null) {
      final parts = ext.path.split('/');
      final androidIdx = parts.indexOf('Android');
      final base = androidIdx > 0
          ? parts.sublist(0, androidIdx).join('/')
          : ext.path;
      if (base.isNotEmpty) {
        for (final name in ['Download', 'download']) {
          final dir = Directory('$base/$name');
          final ok = await _tryCreate(dir);
          if (ok != null) return ok;
        }
      }
    }
  }

  final doc = await getApplicationDocumentsDirectory();
  final fallback = Directory('${doc.path}/CasaNayo');
  if (!await fallback.exists()) await fallback.create(recursive: true);
  return fallback;
}
