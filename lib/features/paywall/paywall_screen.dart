import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../subscription/subscription_provider.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Planos'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: <Widget>[
          SurfaceCard(
            borderColor: sub.isPro ? AppColors.primary.withValues(alpha: 0.45) : AppColors.bad.withValues(alpha: 0.45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sub.statusBadgeLabel,
                        style: TextStyle(
                          color: sub.isPro ? AppColors.primary : AppColors.bad,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aceita AI Turbo',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sub.isTrialActive
                      ? 'Você está aproveitando os 14 dias de teste grátis com 100% das funções liberadas. Quando o período terminar, a assinatura mantém a leitura automática e o card flutuante funcionando no seu turno.'
                      : sub.isPro
                          ? 'Todos os recursos do Aceita AI estão liberados neste aparelho.'
                          : 'Seu período de 14 dias de teste grátis terminou. Assine o Aceita AI Turbo para reativar a leitura automática de tela, o card flutuante, a calculadora Meu Custo e o Simulador.',
                  style: const TextStyle(color: AppColors.muted, height: 1.45),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'O que está incluído no Turbo (e nos 14 dias grátis)'),
          const ListTile(
            leading: Icon(Icons.check_rounded, color: AppColors.good),
            title: Text('Leitura automática de tela (Uber, 99, inDrive, iFood, Keeta)'),
          ),
          const ListTile(
            leading: Icon(Icons.check_rounded, color: AppColors.good),
            title: Text('Card flutuante com semáforo e lucro líquido em tempo real'),
          ),
          const ListTile(
            leading: Icon(Icons.check_rounded, color: AppColors.good),
            title: Text('Calculadora Meu Custo (carro próprio ou alugado, combustível e peças)'),
          ),
          const ListTile(
            leading: Icon(Icons.check_rounded, color: AppColors.good),
            title: Text('Simulador de ganhos e Histórico com Insights do período'),
          ),
          const SizedBox(height: 20),
          const Text(
            'A contratação automática do Turbo está em preparação. '
            'Enquanto isso, você pode usar os 14 dias de teste grátis ou ativar o Modo PRO (dev) nos Ajustes.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
