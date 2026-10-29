import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/goals_repository.dart';
import '../../data/history_repository.dart';
import '../subscription/subscription_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Ajustes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: <Widget>[
          const SectionHeader(
            title: 'Assinatura',
            padding: EdgeInsets.only(bottom: 12),
          ),
          SurfaceCard(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Aceita AI Turbo',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subscription.isPro
                                ? 'Ativo neste aparelho'
                                : 'Inativo — recursos premium bloqueados',
                            style: TextStyle(
                              color: subscription.isPro
                                  ? AppColors.primary
                                  : AppColors.muted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/planos'),
                      child: const Text('Planos'),
                    ),
                  ],
                ),
                const Divider(color: AppColors.border, height: 24),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Modo PRO (dev)',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Abre as telas premium sem cobrança. Não vai para '
                            'produção.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: subscription.devUnlock,
                      onChanged: (value) => ref
                          .read(subscriptionProvider.notifier)
                          .setDevUnlock(value),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Dados'),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.muted,
                    size: 20,
                  ),
                  title: const Text(
                    'Gerar ofertas de exemplo',
                    style: TextStyle(color: AppColors.text, fontSize: 13.5),
                  ),
                  subtitle: const Text(
                    '12 ofertas para testar o simulador',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                  onTap: () async {
                    await ref.read(historyProvider.notifier).seedDemo();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ofertas de exemplo adicionadas.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.muted,
                    size: 20,
                  ),
                  title: const Text(
                    'Zerar histórico',
                    style: TextStyle(color: AppColors.text, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    '${history.length} ofertas salvas neste aparelho',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                  onTap: history.isEmpty
                      ? null
                      : () => _confirmClear(context, ref),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Sobre'),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(
                    Icons.calculate_outlined,
                    color: AppColors.muted,
                    size: 20,
                  ),
                  title: const Text(
                    'Como o cálculo funciona',
                    style: TextStyle(color: AppColors.text, fontSize: 13.5),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                  onTap: () => _showFormulas(context, ref),
                ),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.memory_rounded,
                    color: AppColors.muted,
                    size: 20,
                  ),
                  title: const Text(
                    'Próxima fase: serviço nativo',
                    style: TextStyle(color: AppColors.text, fontSize: 13.5),
                  ),
                  subtitle: const Text(
                    'AccessibilityService + overlay + voz',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                  onTap: () => _showNativePlan(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              'Aceita AI 0.1.5 · build local',
              style: TextStyle(
                color: AppColors.muted.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Zerar histórico?',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Todas as ofertas avaliadas serão apagadas.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Apagar',
              style: TextStyle(color: AppColors.bad),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(historyProvider.notifier).clear();
  }

  void _showFormulas(BuildContext context, WidgetRef ref) {
    final goals = ref.read(goalsProvider);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Motor de cálculo',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'R\$/km = valor / distância\n'
          'R\$/hora = valor / (minutos / 60)\n'
          'R\$/min = valor / minutos\n'
          'lucro = valor - (distância x custo/km)\n'
          'margem = lucro / valor\n\n'
          'Semáforo: verde acima da meta boa, amarelo acima da mínima, '
          'vermelho abaixo.\n\n'
          'Hoje: ${goals.minPerKm.toStringAsFixed(2)} R\$/km mínimo, '
          '${goals.goodPerKm.toStringAsFixed(2)} R\$/km bom, '
          'custo ${goals.costPerKm.toStringAsFixed(2)} R\$/km.',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _showNativePlan(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Serviço nativo (fase 2)',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'O app já nasceu separado em duas camadas:\n\n'
          '1. Flutter — telas, metas, motor de cálculo, histórico e '
          'assinatura.\n'
          '2. Kotlin — AccessibilityService, overlay do card, voz (TTS), '
          'câmera e sincronização.\n\n'
          'A ponte será Pigeon (tipada, como no GigU): o nativo publica o '
          'veredito e o Flutter só desenha. Nenhuma regra de negócio duplicada.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
