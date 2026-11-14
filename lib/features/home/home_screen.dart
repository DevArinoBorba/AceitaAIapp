import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/app_dock.dart';
import '../../data/goals_repository.dart';
import '../../data/cost_repository.dart';
import '../../data/history_repository.dart';
import '../subscription/subscription_provider.dart';
import '../update/update_dialog.dart';
import 'widgets/reader_status_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      checkAndShowUpdateDialog(context, manual: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    final history = ref.watch(historyProvider);
    final isPro = ref.watch(subscriptionProvider).isPro;

    final now = DateTime.now();
    final todayVerdicts = history
        .where((verdict) => _sameDay(verdict.offer.createdAt, now))
        .toList();
    // Só a corrida aceita é dinheiro: o resto é oferta que passou na tela.
    final todayAccepted =
        todayVerdicts.where((verdict) => verdict.accepted == true).toList();
    final confirmedProfit =
        todayAccepted.fold<double>(0, (sum, v) => sum + v.profit);
    final analysedProfit =
        todayVerdicts.fold<double>(0, (sum, v) => sum + v.profit);
    final progress = goals.dailyTarget > 0
        ? (confirmedProfit / goals.dailyTarget).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Scaffold(
      bottomNavigationBar: const AppDock(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: <Widget>[
            Row(
              children: <Widget>[
                Image.asset('assets/brand/aceita-mark.png',
                    width: 46, height: 48),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Aceita AI',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () => context.push('/planos'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                                child: Text(
                              isPro ? 'Turbo ativo' : 'Versão gratuita',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    isPro ? AppColors.primary : AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            )),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color:
                                  isPro ? AppColors.primary : AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.push('/ajustes'),
                  icon: const Icon(Icons.tune_rounded),
                  color: AppColors.muted,
                  tooltip: 'Ajustes',
                ),
              ],
            ),
            const SizedBox(height: 20),
            SurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Ganho confirmado hoje',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${todayAccepted.length} ${todayAccepted.length == 1 ? 'aceita' : 'aceitas'}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    brl(confirmedProfit),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    todayVerdicts.isEmpty
                        ? 'Nenhuma oferta lida hoje ainda'
                        : 'Analisado: ${brl(analysedProfit)} em '
                            '${todayVerdicts.length} ${todayVerdicts.length == 1 ? 'oferta' : 'ofertas'}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: AppColors.surfaceAlt,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Meta diária ${brl(goals.dailyTarget)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Avaliar uma oferta',
              icon: Icons.bolt_rounded,
              onPressed: () => _evaluate(context, ref),
            ),
            const SectionHeader(title: 'Leitura de tela'),
            const ReaderStatusCard(),
            const SizedBox(height: 14),
            Tooltip(
              message: 'Meu custo',
              child: SurfaceCard(
                onTap: () => context.push('/custo'),
                child: Row(children: [
                  const Icon(Icons.toll_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Meu custo',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                            ref.watch(hasCostProfileProvider)
                                ? '${brl(ref.watch(costProfileProvider).totalPerKm)}/km'
                                : 'Configure carro próprio ou alugado',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 11)),
                      ])),
                  const Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Tooltip(
              message: 'Simulador de ganhos',
              child: SurfaceCard(
                onTap: () => context.push('/simulador'),
                child: const Row(children: [
                  Icon(Icons.auto_graph_rounded),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Simulador de ganhos',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Descubra quanto ganha recusando corridas ruins',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'Decisões mais lucrativas',
                style: TextStyle(
                  color: AppColors.muted.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _evaluate(BuildContext context, WidgetRef ref) async {
    context.push('/avaliar');
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
