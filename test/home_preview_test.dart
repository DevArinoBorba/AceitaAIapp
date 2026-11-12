import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:aceita_ai/app.dart';
import 'package:aceita_ai/data/prefs.dart';
import 'package:aceita_ai/domain/entities/goals.dart';
import 'package:aceita_ai/domain/entities/offer.dart';
import 'package:aceita_ai/domain/services/earnings_engine.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home tem três ícones no rodapé e não tem atalho do simulador',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final previewPath = Platform.environment['ACEITA_HOME_PREVIEW'];
    if (previewPath != null) {
      await tester.runAsync(() async {
        final textFont = FontLoader('Roboto')
          ..addFont(Future.value(
            ByteData.sublistView(
                await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes()),
          ));
        final icons = FontLoader('MaterialIcons')
          ..addFont(Future.value(
            ByteData.sublistView(await File(
                    'C:/Users/arino/dev/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
                .readAsBytes()),
          ));
        await textFont.load();
        await icons.load();
      });
    }
    // Estado de exemplo para a prévia: nenhuma oferta e leitura desligada.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('br.com.aceitaai.app/reader'),
      (call) async => call.method == 'lastDump' ? null : <String, Object?>{},
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('br.com.aceitaai.app/reader_events'),
      (call) async => null,
    );
    final samples = Platform.environment['ACEITA_BRAND_SAMPLE'] == '1';
    final now = DateTime.now();
    final previewOffer = const EarningsEngine(Goals()).evaluate(Offer.create(
      appId: 'uber',
      value: 28.90,
      distanceKm: 20,
      timeMin: 36,
      createdAt: now,
      label: 'Exemplo de avaliação',
    ));
    SharedPreferences.setMockInitialValues(samples
        ? {
            'dev_unlock_v1': true,
            'history_v1': jsonEncode(List.generate(
                7,
                (i) => const EarningsEngine(Goals())
                    .evaluate(Offer.create(
                      appId: 'uber',
                      value: 28.90 + i,
                      distanceKm: 20,
                      timeMin: 36,
                      createdAt: now.subtract(Duration(days: i)),
                    ))
                    .copyWith(accepted: i != 2)
                    .toJson())),
          }
        : {});
    final prefs = await SharedPreferences.getInstance();
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const AceitaAiApp(),
      ),
    ));
    await tester.pumpAndSettle();
    if (previewPath != null) {
      await tester.runAsync(() => precacheImage(
        const AssetImage('assets/brand/aceita-mark.png'),
        tester.element(find.byType(Scaffold).first),
      ));
      await tester.pumpAndSettle();
    }
    expect(find.text('Simulador'), findsNothing);
    expect(find.byType(GridView), findsNothing);
    expect(find.byTooltip('Metas'), findsOneWidget);
    expect(find.byTooltip('Meu custo'), findsOneWidget);
    expect(find.byTooltip('Histórico'), findsOneWidget);
    expect(tester.getCenter(find.byTooltip('Metas')).dy, greaterThan(760));
    expect(find.text('Avaliar uma oferta'), findsOneWidget);
    expect(find.text('LEITURA DE TELA'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (previewPath != null) {
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(previewPath).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
      if (samples) {
        final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
        for (final route in [
          '/avaliar',
          '/metas',
          '/historico',
          '/custo',
          '/leitura',
          '/ajustes',
          '/planos'
        ]) {
          router.go(route, extra: route == '/avaliar' ? previewOffer : null);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: route);
          final currentBoundary = boundaryKey.currentContext!
              .findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final rendered = await currentBoundary.toImage(pixelRatio: 3);
            final png =
                await rendered.toByteData(format: ui.ImageByteFormat.png);
            await File(previewPath.replaceFirst(
                    '.png', '-${route.substring(1)}.png'))
                .writeAsBytes(png!.buffer.asUint8List());
            rendered.dispose();
          });
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
