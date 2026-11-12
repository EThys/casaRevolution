import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:casa/widgets/casanayo_invite_poster.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la carte d invitation est un vrai fichier PNG', () async {
    final Uint8List bytes = await renderCasaInviteCardPng(
      name: 'CasaNayo',
      storeUrl: 'https://play.google.com/store/apps/details?id=com.casa.casa.casa',
    );

    expect(bytes.length, greaterThan(1000));
    expect(bytes[0], 0x89);
    expect(bytes[1], 0x50);
    expect(bytes[2], 0x4E);
    expect(bytes[3], 0x47);

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 1080);
    expect(frame.image.height, 1680);
    final raw = await frame.image.toByteData();
    expect(raw, isNotNull);
    final pixel = (220 * frame.image.width + 80) * 4;
    expect(raw!.getUint8(pixel + 3), greaterThan(0));
    frame.image.dispose();
    codec.dispose();
  });

  testWidgets('la carte affichee se capture en PNG', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: const CasanayoInvitePoster(
              name: 'CasaNayo',
              avatar: null,
              storeUrl: 'https://play.google.com/store/apps/details?id=com.casa.casa.casa',
              storeLabel: 'Google Play',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    expect(boundary.debugNeedsPaint, isFalse);
    expect(boundary.size, const Size(360, 560));

    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
    expect(image, isNotNull);
    try {
      expect(image!.width, 720);
      expect(image.height, 1120);
      final data = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
      expect(data, isNotNull);
      final bytes = data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      expect(bytes.length, greaterThan(1000));
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x4E);
      expect(bytes[3], 0x47);
    } finally {
      image!.dispose();
    }
  });

  testWidgets('la feuille d invitation propose partager et telecharger', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCasanayoInviteSheet(context, name: 'CasaNayo'),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Partager'), findsOneWidget);
    expect(find.text('Télécharger'), findsOneWidget);
    expect(find.byType(CasanayoInvitePoster), findsOneWidget);

    final poster = find.byType(CasanayoInvitePoster).evaluate().single;
    RenderObject? object = poster.renderObject;
    while (object != null && object is! RenderRepaintBoundary) {
      object = object.parent;
    }
    final boundary = object! as RenderRepaintBoundary;
    expect(boundary.size, const Size(360, 560));
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
    expect(image, isNotNull);
    expect(image!.width, 720);
    expect(image.height, 1120);
    image.dispose();
  });
}
