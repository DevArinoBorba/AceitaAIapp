import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/goals_repository.dart';
import '../../data/history_repository.dart';
import '../subscription/subscription_provider.dart';
import '../verdict/offer_form_sheet.dart';
import 'widgets/quick_action_tile.dart';
import 'widgets/reader_status_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final history = ref.watch(historyProvider);
    final isPro = ref.watch(subscriptionProvider).isPro;

    final now = DateTime.now();
    final todayVerdicts = history
        .where((verdict) => _sameDay(verdict.offer.createdAt, now))
        .toList();
    final todayProfit =
        todayVerdicts.fold<double>(0, (sum, v) => sum + v.profit);
    final progress = goals.dailyTarget > 0
        ? (todayProfit / goals.dailyTarget).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Copiloto',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPro ? 'Turbo ativo' : 'Versão gratuita',
                        style: TextStyle(
                          color: isPro ? AppColors.primary : AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                      const Text(
                        'Lucro analisado hoje',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${todayVerdicts.length} ofertas',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    brl(todayProfit),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.05,
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
                      Text(
                        'Meta diária ${brl(goals.dailyTarget)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                      const Spacer(),
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
            const SectionHeader(title: 'Ferramentas'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: <Widget>[
                QuickActionTile(
                  icon: Icons.track_changes_rounded,
                  label: 'Metas',
                  hint: '${brl(goals.minPerKm)}/km',
                  onTap: () => context.push('/metas'),
                ),
                QuickActionTile(
                  icon: Icons.insights_rounded,
                  label: 'Simulador',
                  hint: isPro ? 'projeção' : 'Turbo',
                  locked: !isPro,
                  onTap: () => context.push('/simulador'),
                ),
                QuickActionTile(
                  icon: Icons.history_rounded,
                  label: 'Histórico',
                  hint: '${history.length} itens',
                  onTap: () => context.push('/historico'),
                ),
                QuickActionTile(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Planos',
                  hint: isPro ? 'ativo' : 'ver',
                  onTap: () => context.push('/planos'),
                ),
              ],
            ),
            const SectionHeader(title: 'Leitura de tela'),
            const ReaderStatusCard(),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'Copiloto 0.1.0 · protótipo local',
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
    final verdict = await showOfferFormSheet(context, ref);
    if (verdict == null) return;
    if (!context.mounted) return;
    context.push('/avaliar', extra: verdict);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
