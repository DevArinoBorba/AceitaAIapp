import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/goals_repository.dart';
import '../../data/history_repository.dart';
import '../../domain/services/simulator.dart';
import '../subscription/subscription_provider.dart';

class SimulatorScreen extends ConsumerStatefulWidget {
  const SimulatorScreen({super.key});

  @override
  ConsumerState<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends ConsumerState<SimulatorScreen> {
  double _threshold = 2.0;

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(subscriptionProvider).isPro;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Simulador',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: isPro ? _buildSimulator(context) : _LockedView(
        onUnlockDev: () =>
            ref.read(subscriptionProvider.notifier).setDevUnlock(true),
      ),
    );
  }

  Widget _buildSimulator(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    final history = ref.watch(historyProvider);
    final offers = history.map((verdict) => verdict.offer).toList();
    final result = Simulator(goals).run(
      offers: offers,
      thresholdPerKm: _threshold,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: <Widget>[
        Text(
          'Descubra o ponto de equilíbrio entre aceitar tudo e esperar a '
          'corrida certa. A projeção usa as ${offers.length} ofertas do seu '
          'histórico e mantém as mesmas horas trabalhadas.',
          style: TextStyle(
            color: AppColors.muted.withValues(alpha: 0.95),
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
        const SectionHeader(title: 'Aceitar somente acima de'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    '${brl(_threshold)}/km',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'mín. ${brl(goals.minPerKm)}/km',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _threshold,
                min: 0.5,
                max: 6,
                divisions: 55,
                label: '${brl(_threshold)}/km',
                activeColor: AppColors.primary,
                inactiveColor: AppColors.surfaceAlt,
                onChanged: (value) => setState(() => _threshold = value),
              ),
            ],
          ),
        ),
        if (offers.length < 5) ...<Widget>[
          const SizedBox(height: 14),
          SurfaceCard(
            color: AppColors.surfaceAlt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Histórico curto',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Com menos de 5 ofertas a projeção fica instável. Gere um '
                  'exemplo para ver o simulador funcionando.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Gerar 12 ofertas de exemplo',
                  icon: Icons.auto_awesome_rounded,
                  tonal: true,
                  expanded: false,
                  onPressed: () =>
                      ref.read(historyProvider.notifier).seedDemo(),
                ),
              ],
            ),
          ),
        ],
        const SectionHeader(title: 'Resultado'),
        if (!result.hasData)
          SurfaceCard(
            child: Text(
              'Sem dados suficientes. Avalie ofertas ou gere o exemplo acima.',
              style: TextStyle(
                color: AppColors.muted.withValues(alpha: 0.9),
                fontSize: 12.5,
              ),
            ),
          )
        else
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _Headline(
                      value: brl(result.netPerWeekBefore),
                      label: 'hoje por semana',
                      color: AppColors.muted,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ),
                    _Headline(
                      value: brl(result.netPerWeekAfter),
                      label: 'com o filtro',
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: (result.upliftPct >= 0
                            ? AppColors.good
                            : AppColors.bad)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    result.upliftPct >= 0
                        ? '+${decimal(result.upliftPct, 0)}% de lucro por hora'
                        : '${decimal(result.upliftPct, 0)}% de lucro por hora',
                    style: TextStyle(
                      color: result.upliftPct >= 0
                          ? AppColors.good
                          : AppColors.bad,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  color: AppColors.border.withValues(alpha: 0.8),
                  height: 1,
                ),
                const SizedBox(height: 14),
                _CompareRow(
                  label: 'Lucro por hora',
                  before: brl(result.netPerHourBefore),
                  after: brl(result.netPerHourAfter),
                ),
                _CompareRow(
                  label: 'Projeção mensal',
                  before: brl(result.netPerMonthBefore),
                  after: brl(result.netPerMonthAfter),
                ),
                _CompareRow(
                  label: 'Aceitação',
                  before: '100%',
                  after: '${(result.acceptanceRate * 100).round()}%',
                ),
                const SizedBox(height: 12),
                Text(
                  'Aceitaria ${result.accepted} de ${result.offers} ofertas '
                  'analisadas (${decimal(result.hoursAnalysed, 1)}h no período).',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'A projeção mantém as mesmas horas trabalhadas: você troca corridas '
          'ruins por tempo de espera. Se o filtro for agressivo demais, a '
          'aceitação cai e o ganho real depende da oferta da região — use o '
          'histórico de uma semana inteira para decidir.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _LockedView extends StatelessWidget {
  const _LockedView({required this.onUnlockDev});

  final VoidCallback onUnlockDev;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Simulador é Turbo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Projete o impacto de recusar corridas ruins e veja quanto isso '
              'vale por mês. Recurso exclusivo da assinatura.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Ver planos',
              icon: Icons.workspace_premium_rounded,
              expanded: false,
              onPressed: () => context.push('/planos'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onUnlockDev,
              child: const Text('Modo PRO (dev)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            before,
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: AppColors.muted,
            ),
          ),
          Text(
            after,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
