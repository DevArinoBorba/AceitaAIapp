import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../reader/reader_provider.dart';

/// Card da home que resume o estado da leitura de tela.
///
/// Mostra três coisas: se o serviço está ligado, qual app foi lido por último
/// e há quanto tempo — o suficiente para o motorista saber se pode confiar.
class ReaderStatusCard extends ConsumerWidget {
  const ReaderStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reader = ref.watch(readerProvider);
    final status = reader.status;
    final live = status.isLive;
    final color = live ? AppColors.good : AppColors.average;

    final String title;
    final String hint;

    if (!status.available) {
      title = 'Indisponível';
      hint = 'A camada nativa só existe no Android.';
    } else if (!status.serviceEnabled) {
      title = 'Desligada';
      hint = 'Toque para ativar a leitura de tela.';
    } else if (!status.serviceConnected) {
      title = 'Conectando…';
      hint = 'Confirme o serviço nos ajustes de acessibilidade.';
    } else if (reader.dump == null) {
      title = 'Ligada';
      hint = 'Esperando a primeira oferta aparecer.';
    } else {
      final dump = reader.dump!;
      title = dump.appLabel;
      hint = 'Última leitura ${shortDate(dump.at)} · ${dump.nodes.length} nós';
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/leitura'),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              live ? Icons.sensors_rounded : Icons.sensors_off_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Flexible(
                      child: Text(
                        'Leitura de tela',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}
