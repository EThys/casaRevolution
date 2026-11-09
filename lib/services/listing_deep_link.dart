import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../utils/Routes.dart';
import '../utils/casanayo_share_copy.dart';

/// Ouvre une fiche quand l'application reçoit https://casanayo.com/open/... ou casanayo://open/...
class ListingDeepLink {
  ListingDeepLink._();

  static final AppLinks _links = AppLinks();
  static bool _started = false;
  static DateTime? _attachedAt;
  static String? _last;
  static DateTime? _lastAt;

  static void attach(GlobalKey<NavigatorState> navigatorKey) {
    if (_started) return;
    _started = true;
    _attachedAt = DateTime.now();
    _links.getInitialLink().then((uri) {
      if (uri != null) unawaited(_open(navigatorKey, uri));
    });
    _links.uriLinkStream.listen((uri) {
      unawaited(_open(navigatorKey, uri));
    });
  }

  static Future<void> _open(GlobalKey<NavigatorState> navigatorKey, Uri uri) async {
    final target = _targetOf(uri);
    if (target == null) return;
    final key = uri.toString();
    final now = DateTime.now();
    if (_last == key && _lastAt != null && now.difference(_lastAt!) < const Duration(seconds: 2)) {
      return;
    }
    _last = key;
    _lastAt = now;

    const splash = Duration(milliseconds: 2600);
    final elapsed = DateTime.now().difference(_attachedAt ?? DateTime.now());
    if (elapsed < splash) {
      await Future<void>.delayed(splash - elapsed);
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    if (target.service) {
      navigator.pushNamed(Routes.serviceDetail, arguments: {
        'prestationId': target.id,
      });
      return;
    }
    navigator.pushNamed(Routes.detailPageRoute, arguments: {
      'propertyId': target.id,
      if (target.typeId != null) 'propertyTypeId': target.typeId,
    });
  }

  static _OpenTarget? _targetOf(Uri uri) {
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    final body = (uri.host == 'open')
        ? segments
        : (segments.isNotEmpty && segments.first == 'open' ? segments.sublist(1) : const <String>[]);
    if (body.length < 2) return null;
    final id = CasanayoShareCopy.decodeListingId(body[1]);
    if (id == null) return null;
    if (body.first == 'service') return _OpenTarget.service(id);
    if (body.first == 'property') {
      return _OpenTarget.property(id, _typeId(uri.queryParameters['kind']));
    }
    return null;
  }

  static int? _typeId(String? kind) {
    switch ((kind ?? '').toLowerCase()) {
      case 'hotel':
        return 5;
      case 'bureau':
        return 4;
      case 'funeraire':
        return 7;
      case 'festive':
        return 8;
      case 'terrain':
        return 9;
      case 'vacance':
        return 11;
      default:
        return null;
    }
  }
}

class _OpenTarget {
  final bool service;
  final int id;
  final int? typeId;

  const _OpenTarget._(this.service, this.id, this.typeId);

  factory _OpenTarget.service(int id) => _OpenTarget._(true, id, null);
  factory _OpenTarget.property(int id, int? typeId) => _OpenTarget._(false, id, typeId);
}
