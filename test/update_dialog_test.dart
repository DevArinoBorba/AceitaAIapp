import 'dart:async';

import 'package:aceita_ai/core/theme/app_theme.dart';
import 'package:aceita_ai/features/update/update_dialog.dart';
import 'package:aceita_ai/platform/reader_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReaderChannel extends ReaderChannel {
  _FakeReaderChannel({
    this.updateInfo,
    this.downloadResult = 'installer_launched',
    this.installPendingResult = 'installer_launched',
  });

  final AppUpdateInfo? updateInfo;
  String downloadResult;
  String installPendingResult;

  int checkCount = 0;
  int downloadCount = 0;
  int installPendingCount = 0;
  String? lastDownloadUrl;
  String? lastSha256;
  String? openedExternalUrl;

  final StreamController<ReaderEvent> events =
      StreamController<ReaderEvent>.broadcast();

  @override
  Future<AppUpdateInfo?> checkForUpdate() async {
    checkCount++;
    return updateInfo;
  }

  @override
  Future<String> downloadAndInstallUpdate({
    required String downloadUrl,
    String? sha256,
  }) async {
    downloadCount++;
    lastDownloadUrl = downloadUrl;
    lastSha256 = sha256;
    return downloadResult;
  }

  @override
  Future<String> installPendingUpdate() async {
    installPendingCount++;
    return installPendingResult;
  }

  @override
  Future<void> openExternalUrl(String url) async {
    openedExternalUrl = url;
  }

  @override
  Stream<ReaderEvent> watch() => events.stream;
}

const _sampleUpdate = AppUpdateInfo(
  installedVersion: '0.1.0',
  latestVersion: '0.2.0',
  tagName: 'v0.2.0',
  title: 'Aceita AI v0.2.0',
  notes: '- Novo popup de atualização\n- Melhorias na leitura de tela',
  downloadUrl: 'https://example.com/aceita-ai-v0.2.0.apk',
  htmlUrl: 'https://github.com/example/releases/tag/v0.2.0',
  assetName: 'aceita-ai-v0.2.0.apk',
  assetSize: 12345678,
  sha256: 'deadbeef',
  hasUpdate: true,
  canInstallPackages: true,
);

Widget _wrapWithLauncher({
  required ReaderChannel channel,
  bool manual = false,
}) {
  return MaterialApp(
    theme: buildDarkTheme(),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => checkAndShowUpdateDialog(
              context,
              channel: channel,
              manual: manual,
            ),
            child: const Text('Check'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    UpdateDialog.resetSessionCheckForTest();
  });

  testWidgets('exibe UpdateDialog quando hasUpdate == true e fecha ao instalar',
      (tester) async {
    final fake = _FakeReaderChannel(
      updateInfo: _sampleUpdate,
      downloadResult: 'installer_launched',
    );

    await tester.pumpWidget(_wrapWithLauncher(channel: fake));
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(find.text('Uma nova versão está disponível'), findsOneWidget);
    expect(find.text('Versão 0.2.0 (atual: 0.1.0)'), findsOneWidget);
    expect(find.textContaining('Novo popup de atualização'), findsOneWidget);
    expect(find.text('Atualizar agora'), findsOneWidget);

    await tester.tap(find.text('Atualizar agora'));
    await tester.pumpAndSettle();

    expect(fake.downloadCount, 1);
    expect(fake.lastDownloadUrl, 'https://example.com/aceita-ai-v0.2.0.apk');
    expect(fake.lastSha256, 'deadbeef');
    expect(find.text('Uma nova versão está disponível'), findsNothing);
  });

  testWidgets(
      'fluxo permission_required muda botão para Instalar agora e chama installPendingUpdate',
      (tester) async {
    final fake = _FakeReaderChannel(
      updateInfo: _sampleUpdate,
      downloadResult: 'permission_required',
      installPendingResult: 'installer_launched',
    );

    await tester.pumpWidget(_wrapWithLauncher(channel: fake));
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atualizar agora'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Autorize a opção "Permitir desta fonte" no Android e toque em Instalar agora.',
      ),
      findsOneWidget,
    );
    expect(find.text('Instalar agora'), findsOneWidget);

    await tester.tap(find.text('Instalar agora'));
    await tester.pumpAndSettle();

    expect(fake.installPendingCount, 1);
    expect(find.text('Uma nova versão está disponível'), findsNothing);
  });

  testWidgets(
      'fluxo error muda botão para Baixar pelo navegador e abre URL externa',
      (tester) async {
    final fake = _FakeReaderChannel(
      updateInfo: _sampleUpdate,
      downloadResult: 'error',
    );

    await tester.pumpWidget(_wrapWithLauncher(channel: fake));
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atualizar agora'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Falha ao baixar dentro do app. Você pode baixar direto pelo navegador.',
      ),
      findsOneWidget,
    );
    expect(find.text('Baixar pelo navegador'), findsOneWidget);

    await tester.tap(find.text('Baixar pelo navegador'));
    await tester.pumpAndSettle();

    expect(
      fake.openedExternalUrl,
      'https://example.com/aceita-ai-v0.2.0.apk',
    );
    expect(find.text('Uma nova versão está disponível'), findsNothing);
  });

  testWidgets('verifica apenas uma vez por sessão no modo automático',
      (tester) async {
    final fake = _FakeReaderChannel(
      updateInfo: const AppUpdateInfo(
        installedVersion: '0.2.0',
        latestVersion: '0.2.0',
        tagName: 'v0.2.0',
        title: 'v0.2.0',
        notes: '',
        downloadUrl: '',
        htmlUrl: '',
        assetName: '',
        assetSize: 0,
        hasUpdate: false,
        canInstallPackages: true,
      ),
    );

    await tester.pumpWidget(_wrapWithLauncher(channel: fake, manual: false));
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(fake.checkCount, 1);
  });
}
