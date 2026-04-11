import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Sous-dossiers de `casaNayo/` à la racine du stockage partagé Android (`/storage/emulated/0/`).
enum CasaNayoExportKind {
  /// Bons de visite / réservations (BookingHistory, BookingVisit).
  reservation,

  /// Demandes d’intervention / sollicitations (MyServices, RequestIntervention).
  solicitation,
}

String _casaNayoSubPath(CasaNayoExportKind kind) {
  switch (kind) {
    case CasaNayoExportKind.reservation:
      return 'reservations';
    case CasaNayoExportKind.solicitation:
      return 'solicitations';
  }
}

/// Dossier d’export PDF : **`/storage/emulated/0/casaNayo/<reservations|solicitations>/`** sur Android
/// (pas sous `Android/data/...`). Sur iOS : `Documents/casaNayo/...`.
Future<Directory> getCasaNayoExportDirectory(CasaNayoExportKind kind) async {
  final sub = _casaNayoSubPath(kind);

  if (Platform.isAndroid) {
    final primary = Directory('/storage/emulated/0/casaNayo/$sub');
    try {
      if (!await primary.exists()) {
        await primary.create(recursive: true);
      }
      return primary;
    } catch (_) {}

    // Même volume que l’APK : …/storage/emulated/0 sans passer par Android/data
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final parts = ext.path.split('/');
        final androidIdx = parts.indexOf('Android');
        if (androidIdx > 0) {
          final base = parts.sublist(0, androidIdx).join('/');
          final d = Directory('$base/casaNayo/$sub');
          if (!await d.exists()) await d.create(recursive: true);
          return d;
        }
      }
    } catch (_) {}
  }

  final root = await getApplicationDocumentsDirectory();
  final d = Directory('${root.path}/casaNayo/$sub');
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

/// Dossier générique (ex. factures) — préférer [getCasaNayoExportDirectory] pour réservations / sollicitations.
Future<Directory> getUserDownloadExportDirectory() async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      if (!await downloads.exists()) {
        await downloads.create(recursive: true);
      }
      return downloads;
    }
  } catch (_) {}

  if (Platform.isAndroid) {
    for (final path in [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/download',
    ]) {
      final dir = Directory(path);
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      } catch (_) {}
    }
  }

  final ext = await getExternalStorageDirectory();
  if (ext != null) {
    final parts = ext.path.split('/');
    final androidIdx = parts.indexOf('Android');
    final base = androidIdx > 0
        ? parts.sublist(0, androidIdx).join('/')
        : ext.path;
    if (base.isNotEmpty) {
      final dir = Directory('$base/Download');
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      } catch (_) {}
    }
  }

  return await getApplicationDocumentsDirectory();
}
