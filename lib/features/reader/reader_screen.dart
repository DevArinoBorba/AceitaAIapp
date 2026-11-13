import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/history_repository.dart';
import '../../domain/entities/card_layout.dart';
import '../../platform/reader_channel.dart';
import '../subscription/subscription_provider.dart';
import 'reader_provider.dart';

/// Nomes amigáveis para os pacotes que o app já conhece.
const _knownApps = <String, String>{
  'com.ubercab.driver': 'Uber Driver',
  'com.app99.driver': '99 Motorista',
  'sinet.startup.inDriver': 'inDrive',
  'sinet.startup.inDrive': 'inDrive',
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

  /// Grava uma oferta de exemplo no histórico, pelo caminho nativo — assim a
  /// integração pode ser conferida sem esperar uma oferta real na tela.
  Future<void> _recordSample() async {
    final saved = await ref.read(readerProvider.notifier).recordSampleOffer();
    await ref.read(historyProvider.notifier).reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Oferta de exemplo registrada no histórico.'
              : 'Essa oferta já está no histórico.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reader = ref.watch(readerProvider);
    final status = reader.status;
    final dump = reader.dump;
    // Ferramenta de teste: só aparece no modo dev, como o "gerar exemplo".
    final isDev = ref.watch(subscriptionProvider).isPro;

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
          const SectionHeader(title: 'Controles'),
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
            child: Column(
              children: <Widget>[
                _ToggleRow(
                  title: 'Leitura de ofertas',
                  hint: 'O mesmo interruptor do balão. Pausar não desliga o '
                      'serviço — só para de interpretar a tela.',
                  value: status.readingEnabled,
                  onChanged: (value) => ref
                      .read(readerProvider.notifier)
                      .setReadingEnabled(value),
                ),
                const Divider(color: AppColors.border, height: 1),
                _ToggleRow(
                  title: 'Balão flutuante',
                  hint: 'Fica por cima dos outros apps. Um toque pausa ou '
                      'retoma a leitura; arraste para mudar de lugar.',
                  value: status.bubbleEnabled,
                  onChanged: (value) =>
                      ref.read(readerProvider.notifier).setBubbleEnabled(value),
                ),
                const Divider(color: AppColors.border, height: 1),
                _ToggleRow(
                  title: 'Capturar qualquer app',
                  hint: 'Só para descobrir o pacote de um app novo. '
                      'Deixe desligado no uso normal.',
                  value: status.captureAll,
                  onChanged: (value) =>
                      ref.read(readerProvider.notifier).setCaptureAll(value),
                ),
              ],
            ),
          ),
          if (status.available &&
              status.bubbleEnabled &&
              !status.canDrawOverlays)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: _OverlayPermissionCard(),
            ),
          const SectionHeader(title: 'Turno inteiro'),
          _ShiftCard(status: status),
          const SectionHeader(title: 'Apps lidos'),
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Wrap(
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
          if (dump == null) const _EmptyDump() else _DumpCard(dump: dump),
          const SectionHeader(title: 'Card da oferta'),
          _CardLayoutCard(
            fields: status.cardFields.isEmpty
                ? cardDetailedPreset
                : status.cardFields,
            durationSeconds: status.cardDurationSeconds,
            onChanged: (fields) =>
                ref.read(readerProvider.notifier).setCardFields(fields),
            onDurationChanged: (seconds) =>
                ref.read(readerProvider.notifier).setCardDuration(seconds),
            onPreview: () =>
                ref.read(readerProvider.notifier).previewOfferCard(),
            onRecordSample: isDev ? _recordSample : null,
          ),
          const SectionHeader(title: 'Conferir a leitura'),
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Lê a tela neste instante pelo OCR e devolve as linhas que '
                  'ele reconheceu. Serve para saber se o aparelho está lendo '
                  'antes de culpar a oferta.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Testar leitura por imagem',
                  icon: Icons.text_snippet_outlined,
                  tonal: true,
                  onPressed: () async {
                    final lines =
                        await ref.read(readerProvider.notifier).testOcr();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          lines.isEmpty
                              ? 'O OCR não leu nada nesta tela.'
                              : 'OCR: ${lines.length} linhas · ${lines.first}',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
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
        'Toque abaixo e ative o Aceita AI na lista de acessibilidade.',
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
              'Aceita AI — leitura de ofertas.',
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

/// Aviso quando o balão aparece mas não recebe toque.
class _OverlayPermissionCard extends ConsumerWidget {
  const _OverlayPermissionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.average.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.touch_app_outlined,
                color: AppColors.average,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'O balão aparece, mas não responde ao toque',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'No MIUI o balão só recebe toque com a permissão de exibir sobre '
            'outros apps. É uma tela só, e o Android lembra.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Permitir exibir sobre outros apps',
            icon: Icons.open_in_new_rounded,
            tonal: true,
            onPressed: () =>
                ref.read(readerProvider.notifier).openOverlaySettings(),
          ),
        ],
      ),
    );
  }
}

/// O que precisa estar de pé para o card aparecer o dia inteiro.
///
/// São três coisas independentes e cada uma falha calada: a acessibilidade é o
/// serviço em si, a bateria é o que o MIUI usa para matá-lo no meio do turno e
/// a notificação é o único canal para avisar que ele caiu. Faltando uma, o
/// motorista roda às cegas e só descobre no fim do dia.
class _ShiftCard extends ConsumerWidget {
  const _ShiftCard({required this.status});

  final ReaderStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reader = ref.read(readerProvider.notifier);

    final items = <_ShiftItem>[
      _ShiftItem(
        label: 'Acessibilidade',
        ok: status.isLive,
        detail: status.isLive
            ? 'Conectada — a tela está sendo lida'
            : status.serviceEnabled
                ? 'Ligada, mas o Android ainda não conectou'
                : 'Desligada — nenhuma oferta é lida',
        action: 'Religar',
        onAction: reader.openSettings,
      ),
      _ShiftItem(
        label: 'Bateria',
        ok: status.batteryUnrestricted,
        detail: status.batteryUnrestricted
            ? 'Sem restrição — o Android não corta a leitura'
            : 'Com economia de bateria o MIUI corta a leitura no meio do turno',
        action: 'Liberar',
        onAction: reader.openBatterySettings,
      ),
      _ShiftItem(
        label: 'Notificação',
        ok: status.notificationsEnabled,
        detail: status.notificationsEnabled
            ? 'Ligada — avisa se a leitura parar'
            : 'Desligada — você não fica sabendo se a leitura parar',
        action: 'Permitir',
        onAction: reader.openNotificationSettings,
      ),
    ];

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final item in items) _ShiftRow(item: item),
          if (!status.batteryUnrestricted)
            TextButton.icon(
              onPressed: reader.openAutoStart,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Abrir autostart do MIUI'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.muted,
                padding: const EdgeInsets.symmetric(horizontal: 0),
                textStyle: const TextStyle(fontSize: 11.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShiftItem {
  const _ShiftItem({
    required this.label,
    required this.ok,
    required this.detail,
    required this.action,
    required this.onAction,
  });

  final String label;
  final bool ok;
  final String detail;
  final String action;
  final VoidCallback onAction;
}

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({required this.item});

  final _ShiftItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.ok ? AppColors.good : AppColors.average;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              item.ok
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.label,
                  style: TextStyle(
                    color: item.ok ? AppColors.text : color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.detail,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (!item.ok)
            TextButton(
              onPressed: item.onAction,
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(item.action),
            ),
        ],
      ),
    );
  }
}

/// Monta o card do jeito do motorista: dois presets e os números soltos.
///
/// O preset não é um estado à parte — é só um conjunto de campos. Se o
/// motorista mexer em qualquer chip, ele deixa de ser "Simples" ou
/// "Detalhada" e vira "Personalizado" sozinho.
class _CardLayoutCard extends StatelessWidget {
  const _CardLayoutCard({
    required this.fields,
    required this.durationSeconds,
    required this.onChanged,
    required this.onDurationChanged,
    required this.onPreview,
    this.onRecordSample,
  });

  final Set<CardField> fields;
  final int durationSeconds;
  final ValueChanged<Set<CardField>> onChanged;
  final ValueChanged<int> onDurationChanged;
  final VoidCallback onPreview;

  /// Só no modo dev: registra uma oferta de exemplo no histórico.
  final VoidCallback? onRecordSample;

  @override
  Widget build(BuildContext context) {
    final mode = cardModeOf(fields);

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Escolha o que aparece no card quando chega a oferta. Quanto menos '
            'número, mais rápido de ler no meio da correria — com até quatro '
            'números e sem rota, o card vira uma faixa fina de uma linha.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _PresetTile(
                    title: 'Simples',
                    hint: 'R\$/km · R\$/h · nota · veredito',
                    selected: mode == CardMode.simple,
                    onTap: () => onChanged(cardSimplePreset),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PresetTile(
                    title: 'Detalhada',
                    hint: 'todos os números',
                    selected: mode == CardMode.detailed,
                    onTap: () => onChanged(cardDetailedPreset),
                  ),
                ),
              ],
            ),
          ),
          if (mode == CardMode.custom)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Personalizado — do seu jeito.',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CardField.values
                .map(
                  (field) => _FieldChip(
                    label: field.label,
                    selected: fields.contains(field),
                    onTap: () => _toggle(context, field),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          const Text(
            'Tempo na tela',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'O card também fecha antes se você aceitar, recusar ou tocar nele.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cardDurationOptions
                .map(
                  (option) => _DurationChip(
                    seconds: option,
                    selected: durationSeconds == option,
                    onTap: () => onDurationChanged(option),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Ver o card de exemplo',
            icon: Icons.visibility_outlined,
            tonal: true,
            onPressed: onPreview,
          ),
          if (onRecordSample != null) ...<Widget>[
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Registrar oferta de exemplo',
              icon: Icons.playlist_add_outlined,
              tonal: true,
              onPressed: onRecordSample!,
            ),
          ],
        ],
      ),
    );
  }

  void _toggle(BuildContext context, CardField field) {
    final next = Set<CardField>.from(fields);
    if (next.contains(field)) {
      // Um card sem número nenhum não responde nada.
      if (next.length == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('O card precisa de pelo menos um número.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      next.remove(field);
    } else {
      next.add(field);
    }
    onChanged(next);
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.65)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 15,
                    color: selected ? AppColors.primary : AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: selected ? AppColors.primary : AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                hint,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.16)
          : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                selected ? Icons.check_rounded : Icons.add_rounded,
                size: 13,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.muted,
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.seconds,
    required this.selected,
    required this.onTap,
  });

  final int seconds;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.16)
          : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.border,
            ),
          ),
          child: Text(
            '${seconds}s',
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.muted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: const TextStyle(
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
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
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
            'Abra o Uber Driver, deixe o Aceita AI em segundo plano e volte '
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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
