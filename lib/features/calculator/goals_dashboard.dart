import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/goals_repository.dart';
import '../../data/history_repository.dart';

/// Resumo real do histórico. Aceite não comprova conclusão ou recebimento.
class GoalsDashboard extends ConsumerStatefulWidget {
  const GoalsDashboard({super.key});
  @override
  ConsumerState<GoalsDashboard> createState() => _GoalsDashboardState();
}

class _GoalsDashboardState extends ConsumerState<GoalsDashboard> {
  int _period = 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = _period == 0
        ? today
        : _period == 1
            ? today.subtract(Duration(days: today.weekday - 1))
            : DateTime(now.year, now.month);
    final goals = ref.watch(goalsProvider);
    final history = ref.watch(historyProvider);
    final accepted = history
        .where((v) =>
            v.accepted == true &&
            !v.offer.createdAt.isBefore(start) &&
            !v.offer.createdAt.isAfter(now))
        .toList();
    final profit = accepted.fold<double>(0, (sum, v) => sum + v.profit);
    final km = accepted.fold<double>(0, (sum, v) => sum + v.offer.distanceKm);
    final min = accepted.fold<double>(0, (sum, v) => sum + v.offer.timeMin);
    final gross = accepted.fold<double>(0, (sum, v) => sum + v.offer.value);
    final target = _period == 0
        ? goals.dailyTarget
        : _period == 1
            ? goals.weeklyTarget
            : 0.0;
    final progress =
        target > 0 ? (profit / target).clamp(0.0, 1.0).toDouble() : 0.0;
    final weekStart = today.subtract(const Duration(days: 6));
    final daily = List<double>.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      return history
          .where((v) =>
              v.accepted == true &&
              v.offer.createdAt.year == day.year &&
              v.offer.createdAt.month == day.month &&
              v.offer.createdAt.day == day.day)
          .fold<double>(0, (sum, v) => sum + v.profit);
    });
    final maxValue =
        daily.fold<double>(1, (value, day) => math.max(value, day.abs()));
    const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Hoje')),
          ButtonSegment(value: 1, label: Text('Semana')),
          ButtonSegment(value: 2, label: Text('Mês')),
        ],
        selected: {_period},
        showSelectedIcon: false,
        onSelectionChanged: (value) => setState(() => _period = value.first),
      ),
      const SizedBox(height: 16),
      SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.track_changes_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_period == 0
                  ? 'Meta diária'
                  : _period == 1
                      ? 'Meta semanal'
                      : 'Resultado do mês')),
          if (target > 0)
            Text(brl(target), style: const TextStyle(color: AppColors.muted)),
        ]),
        const SizedBox(height: 18),
        Text(brl(profit),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Lucro estimado das corridas aceitas',
            style: TextStyle(color: AppColors.muted, fontSize: 11)),
        if (target > 0) ...[
          const SizedBox(height: 16),
          ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.surfaceAlt,
              )),
          const SizedBox(height: 8),
          Text(
              profit >= target
                  ? 'Meta atingida'
                  : 'Faltam ${brl(target - profit)} para a meta',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ])),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _Metric(
                icon: Icons.directions_car_outlined,
                value: '${accepted.length}',
                label: 'aceitas')),
        const SizedBox(width: 8),
        Expanded(
            child: _Metric(
                icon: Icons.speed_outlined,
                value: brl(min > 0 ? profit / min * 60 : 0),
                label: 'lucro/h')),
        const SizedBox(width: 8),
        Expanded(
            child: _Metric(
                icon: Icons.route_outlined,
                value: brl(km > 0 ? gross / km : 0),
                label: 'bruto/km')),
      ]),
      const SizedBox(height: 12),
      SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Evolução de ganhos',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Últimos 7 dias · lucro estimado das aceitas',
            style: TextStyle(color: AppColors.muted, fontSize: 11)),
        const SizedBox(height: 18),
        SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                  7,
                  (i) => Expanded(
                          child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                  height: math.max(
                                      3, daily[i].abs() / maxValue * 98),
                                  decoration: BoxDecoration(
                                    gradient: i == 6 && daily[i] >= 0
                                        ? AppColors.chrome
                                        : null,
                                    color: daily[i] < 0
                                        ? AppColors.bad
                                        : i == 6
                                            ? null
                                            : const Color(0xFF68686D),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4)),
                                  )),
                              const SizedBox(height: 7),
                              FittedBox(
                                  child: Text(
                                      weekdays[weekStart
                                              .add(Duration(days: i))
                                              .weekday -
                                          1],
                                      style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 10))),
                            ]),
                      ))),
            )),
        if (history.isEmpty)
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'As barras aparecem conforme houver corridas aceitas no histórico.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              )),
        if (daily.any((v) => v < 0))
          const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'Há dias com prejuízo; consulte os valores no histórico.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11))),
      ])),
      const SizedBox(height: 12),
      SurfaceCard(
          onTap: () => context.push('/custo'),
          child: Row(children: [
            const Icon(Icons.toll_outlined),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Meu custo operacional',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('${brl(goals.costPerKm)}/km',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ])),
      const SizedBox(height: 10),
      const Text(
          'Aceite não comprova conclusão ou recebimento. Tempo e lucro são estimados pelas ofertas.',
          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4)),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Column(children: [
          Icon(icon, size: 22),
          const SizedBox(height: 8),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800))),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ]),
      );
}
