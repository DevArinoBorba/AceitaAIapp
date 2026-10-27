import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui_kit.dart';
import '../../platform/reader_channel.dart';
import 'reader_provider.dart';

/// Nomes amigáveis para os pacotes que o app já conhece.
const _knownApps = <String, String>{
  'com.ubercab.driver': 'Uber Driver',
  'com.app99.driver': '99 Motorista',
  'sinet.startup.inDriver': 'inDrive',
};

String _appName(String package) => _knownApps[package] ?? package;

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(readerProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(readerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reader = ref.watch(readerProvider);
    final status = reader.status;
    final dump = reader.dump;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Leitura de tela',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.read(readerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            color: AppColors.muted,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
        children: <Widget>[
          _StatusCard(
            status: status,
            appCount: reader.appCount,
            onOpenSettings: () =>
                ref.read(readerProvider.notifier).openSettings(),
          ),
          const SectionHeader(title: 'Apps lidos'),
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: status.targets
                      .map(
                        (package) => _PackageChip(
                          label: _appName(package),
                          package: package,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Capturar qualquer app',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Só para descobrir o pacote de um app novo. '
                            'Deixe desligado no uso normal.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: status.captureAll,
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) => ref
                          .read(readerProvider.notifier)
                          .setCaptureAll(value),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SectionHeader(
            title: 'Última captura',
            trailing: dump == null
                ? null
                : Text(
                    shortDate(dump.at),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
          ),
          if (dump == null)
            const _EmptyDump()
          else
            _DumpCard(dump: dump),
          const SizedBox(height: 22),
          const _HowItWorks(),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.appCount,
    required this.onOpenSettings,
  });

  final ReaderStatus status;
  final int appCount;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final live = status.isLive;
    final color = live ? AppColors.good : AppColors.average;

    final subtitle = switch (status) {
      _ when !status.available =>
        'Este aparelho/plataforma não tem a camada nativa.',
      _ when !status.serviceEnabled =>
        'Toque abaixo e ative o Copiloto na lista de acessibilidade.',
      _ when !status.serviceConnected =>
        'O Android ainda não conectou. Confirme o serviço nos ajustes.',
      _ =>
        '$appCount app(s) enviando tela · ${status.dumpCount} captura(s) em memória',
    };

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      borderColor: live ? color.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  live ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      status.headline,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status.available && !live) ...<Widget>[
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Abrir ajustes de acessibilidade',
              icon: Icons.open_in_new_rounded,
              onPressed: onOpenSettings,
            ),
            const SizedBox(height: 10),
            const Text(
              'Caminho: Configurações → Acessibilidade → Apps instalados → '
              'Copiloto — leitura de ofertas.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10.5,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PackageChip extends StatelessWidget {
  const _PackageChip({required this.label, required this.package});

  final String label;
  final String package;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            package,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDump extends StatelessWidget {
  const _EmptyDump();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.center_focus_weak_rounded,
            color: AppColors.muted,
            size: 28,
          ),
          const SizedBox(height: 10),
          const Text(
            'Nenhuma tela capturada ainda',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Abra o Uber Driver, deixe o Copiloto em segundo plano e volte '
            'aqui. Toda tela lida aparece nesta lista — inclusive a oferta.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted.withValues(alpha: 0.95),
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _DumpCard extends StatelessWidget {
  const _DumpCard({required this.dump});

  final ScreenDump dump;

  static const int _visibleNodes = 40;

  @override
  Widget build(BuildContext context) {
    final nodes = dump.nodes;
    final shown = nodes.take(_visibleNodes).toList();

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      dump.appLabel,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dump.package,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${nodes.length} nós',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),
          ...shown.map((node) => _NodeRow(node: node)),
          if (nodes.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${nodes.length - shown.length} nós não exibidos '
                '(o dump completo vai no "copiar").',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: 'Copiar dump',
                  icon: Icons.copy_all_rounded,
                  tonal: true,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: dump.toReport()),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Dump copiado. Cole no chat para eu escrever o parser.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.node});

  final ReaderNode node;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            node.text,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          if (node.id.isNotEmpty)
            Text(
              node.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 9.5,
                height: 1.3,
              ),
            ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'O que acontece com esses textos',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'O serviço só coleta. Quem interpreta é o parser — um conjunto de '
            'regras por app que procura valor, distância e tempo usando os '
            'viewIds acima. Quando o parser acerta, o veredito aparece no card '
            'flutuante sem você digitar nada.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
