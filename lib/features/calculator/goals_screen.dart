import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/goals_repository.dart';
import '../../domain/entities/goals.dart';
import '../../domain/entities/offer.dart';
import '../../domain/services/earnings_engine.dart';
import '../verdict/verdict_card.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final notifier = ref.read(goalsProvider.notifier);

    void preview(Goals next) => notifier.preview(next);
    void commit() => notifier.commit();

    // Oferta de exemplo para o motorista ver o efeito das metas em tempo real.
    final sample = Offer.create(
      appId: DriverApp.uber.id,
      value: 22,
      distanceKm: 9,
      timeMin: 22,
      passengerRating: 4.9,
      label: 'UberX',
    );
    final sampleVerdict = EarningsEngine(goals).evaluate(sample);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Suas metas',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => notifier.update(const Goals()),
            child: const Text('Restaurar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: <Widget>[
          Text(
            'O semáforo do veredito compara cada oferta com estes números.',
            style: TextStyle(
              color: AppColors.muted.withValues(alpha: 0.95),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          VerdictCard(verdict: sampleVerdict, compact: true),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'exemplo: R\$ 22 · 9 km · 22 min · nota 4,9',
              style: TextStyle(color: AppColors.muted, fontSize: 10.5),
            ),
          ),
          const SectionHeader(title: 'Por quilômetro'),
          SurfaceCard(
            child: Column(
              children: <Widget>[
                _GoalSlider(
                  label: 'Mínimo aceitável',
                  value: goals.minPerKm,
                  min: 0.5,
                  max: 6,
                  divisions: 110,
                  format: (v) => '${brl(v)}/km',
                  onChanged: (v) {
                    var next = goals.copyWith(minPerKm: v);
                    if (next.goodPerKm < v + 0.05) {
                      next = next.copyWith(goodPerKm: v + 0.05);
                    }
                    preview(next);
                  },
                  onChangeEnd: (_) => commit(),
                ),
                const Divider(color: AppColors.border, height: 22),
                _GoalSlider(
                  label: 'Boa oferta',
                  value: goals.goodPerKm,
                  min: 0.5,
                  max: 8,
                  divisions: 150,
                  format: (v) => '${brl(v)}/km',
                  onChanged: (v) {
                    var next = goals.copyWith(goodPerKm: v);
                    if (next.minPerKm > v - 0.05) {
                      next = next.copyWith(minPerKm: (v - 0.05).clamp(0.5, 8).toDouble());
                    }
                    preview(next);
                  },
                  onChangeEnd: (_) => commit(),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Por hora'),
          SurfaceCard(
            child: Column(
              children: <Widget>[
                _GoalSlider(
                  label: 'Mínimo aceitável',
                  value: goals.minPerHour,
                  min: 5,
                  max: 80,
                  divisions: 75,
                  format: (v) => '${brl(v)}/h',
                  onChanged: (v) {
                    var next = goals.copyWith(minPerHour: v);
                    if (next.goodPerHour < v + 1) {
                      next = next.copyWith(goodPerHour: v + 1);
                    }
                    preview(next);
                  },
                  onChangeEnd: (_) => commit(),
                ),
                const Divider(color: AppColors.border, height: 22),
                _GoalSlider(
                  label: 'Boa oferta',
                  value: goals.goodPerHour,
                  min: 5,
                  max: 150,
                  divisions: 145,
                  format: (v) => '${brl(v)}/h',
                  onChanged: (v) {
                    var next = goals.copyWith(goodPerHour: v);
                    if (next.minPerHour > v - 1) {
                      next = next.copyWith(
                        minPerHour: (v - 1).clamp(5, 150).toDouble(),
                      );
                    }
                    preview(next);
                  },
                  onChangeEnd: (_) => commit(),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Custo e margem'),
          SurfaceCard(
            child: Column(
              children: <Widget>[
                _GoalSlider(
                  label: 'Custo por km',
                  value: goals.costPerKm,
                  min: 0,
                  max: 4,
                  divisions: 80,
                  format: (v) => '${brl(v)}/km',
                  onChanged: (v) =>
                      preview(goals.copyWith(costPerKm: v)),
                  onChangeEnd: (_) => commit(),
                ),
                const Divider(color: AppColors.border, height: 22),
                _GoalSlider(
                  label: 'Margem mínima',
                  value: goals.minProfitPct,
                  min: 0,
                  max: 80,
                  divisions: 80,
                  format: (v) => '${v.round()}%',
                  onChanged: (v) {
                    var next = goals.copyWith(minProfitPct: v);
                    if (next.goodProfitPct < v + 1) {
                      next = next.copyWith(goodProfitPct: v + 1);
                    }
                    preview(next);
                  },
                  onChangeEnd: (_) => commit(),
                ),
                const Divider(color: AppColors.border, height: 22),
                _GoalSlider(
                  label: 'Margem boa',
                  value: goals.goodProfitPct,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  format: (v) => '${v.round()}%',
                  onChanged: (v) {
                    var next = goals.copyWith(goodProfitPct: v);
                    if (next.minProfitPct > v - 1) {
                      next = next.copyWith(
                        minProfitPct: (v - 1).clamp(0, 100).toDouble(),
                      );
                    }
                    preview(next);
                  },
                  onChangeEnd: (_) => commit(),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Metas de faturamento'),
          SurfaceCard(
            child: Column(
              children: <Widget>[
                _GoalSlider(
                  label: 'Meta diária',
                  value: goals.dailyTarget,
                  min: 0,
                  max: 1200,
                  divisions: 24,
                  format: brlCompact,
                  onChanged: (v) =>
                      preview(goals.copyWith(dailyTarget: v)),
                  onChangeEnd: (_) => commit(),
                ),
                const Divider(color: AppColors.border, height: 22),
                _GoalSlider(
                  label: 'Meta semanal',
                  value: goals.weeklyTarget,
                  min: 0,
                  max: 8000,
                  divisions: 32,
                  format: brlCompact,
                  onChanged: (v) =>
                      preview(goals.copyWith(weeklyTarget: v)),
                  onChangeEnd: (_) => commit(),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Passageiro'),
          SurfaceCard(
            child: Column(
              children: <Widget>[
                _GoalSlider(
                  label: 'Nota mínima',
                  value: goals.minRating,
                  min: 3,
                  max: 5,
                  divisions: 20,
                  format: (v) => decimal(v, 1),
                  onChanged: (v) {
                    var next = goals.copyWith(minRating: v);
                    if (next.goodRating < v + 0.1) {
                      next = next.copyWith(goodRating: v + 0.1);
                    }
                    preview(next);
                  },
                  onChangeEnd: (_) => commit(),
                ),
                const Divider(color: AppColors.border, height: 22),
                _GoalSlider(
                  label: 'Nota boa',
                  value: goals.goodRating,
                  min: 3,
                  max: 5,
                  divisions: 20,
                  format: (v) => decimal(v, 1),
                  onChanged: (v) {
                    var next = goals.copyWith(goodRating: v);
                    if (next.minRating > v - 0.1) {
                      next = next.copyWith(
                        minRating: (v - 0.1).clamp(3, 5).toDouble(),
                      );
                    }
                    preview(next);
                  },
                  onChangeEnd: (_) => commit(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Dica: o custo por km é o número que mais muda o resultado. '
            'Some combustível, manutenção, pneus e depreciação por km rodado.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalSlider extends StatelessWidget {
  const _GoalSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value) format;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(min, max).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              format(value),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.surfaceAlt,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            valueIndicatorColor: AppColors.surfaceAlt,
            valueIndicatorTextStyle: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Slider(
            value: safeValue,
            min: min,
            max: max,
            divisions: divisions,
            label: format(safeValue),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}
