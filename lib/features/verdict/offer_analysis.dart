import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui_kit.dart';
import '../../domain/entities/verdict.dart';

class OfferAnalysis extends StatelessWidget {
  const OfferAnalysis({super.key, required this.verdict});
  final OfferVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final offer = verdict.offer;
    final cost = offer.distanceKm * verdict.goals.costPerKm;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.location_on_outlined, size: 22),
          const SizedBox(width: 8),
          Expanded(
              child: Text('Oferta ${offer.app.label}',
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          const Icon(Icons.directions_car_outlined),
        ]),
        const SizedBox(height: 12),
        Text(
            offer.label?.isNotEmpty == true
                ? offer.label!
                : 'Oferta avaliada no app',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const Divider(height: 28, color: AppColors.border),
        Row(children: [
          Expanded(
              child: _Value(label: 'Valor da viagem', value: brl(offer.value))),
          Expanded(
              child: _Value(
                  label: 'Distância total', value: kmLabel(offer.distanceKm))),
          Expanded(
              child: _Value(
                  label: 'Tempo estimado', value: timeLabel(offer.timeMin))),
        ]),
      ])),
      const SizedBox(height: 14),
      SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_awesome_outlined, size: 21),
          SizedBox(width: 8),
          Expanded(
              child: Text('Análise da oferta',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)))
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              gradient: AppColors.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Icon(
                verdict.overall == Grade.good
                    ? Icons.check_circle_outline
                    : verdict.overall == Grade.bad
                        ? Icons.cancel_outlined
                        : Icons.info_outline,
                color: gradeColor(verdict.overall),
                size: 30),
            const SizedBox(width: 12),
            Expanded(
                child: Text(verdict.headline,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800))),
          ]),
        ),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _Value(
                  label: 'Custo estimado',
                  value: brl(cost),
                  detail: '${brl(verdict.goals.costPerKm)}/km')),
          Container(width: 1, height: 55, color: AppColors.border),
          const SizedBox(width: 16),
          Expanded(
              child:
                  _Value(label: 'Lucro estimado', value: brl(verdict.profit))),
        ]),
        const Divider(height: 32, color: AppColors.border),
        Row(children: [
          Expanded(
              child: _Value(label: 'R\$/km', value: brl(verdict.valuePerKm))),
          Expanded(
              child:
                  _Value(label: 'R\$/hora', value: brl(verdict.valuePerHour))),
          Expanded(
              child:
                  _Value(label: 'Margem', value: pctLabel(verdict.profitPct))),
        ]),
      ])),
      const SizedBox(height: 14),
      SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.lightbulb_outline, size: 21),
          SizedBox(width: 8),
          Expanded(
              child: Text('Por que esse resultado?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))
        ]),
        const SizedBox(height: 12),
        Text(
            'Valor por km: ${verdict.perKm.grade.label.toLowerCase()}. '
            'Valor por hora: ${verdict.perHour.grade.label.toLowerCase()}. '
            'Margem: ${verdict.profitPctMetric.grade.label.toLowerCase()}. '
            'A avaliação compara os números da oferta com as suas metas.',
            style: const TextStyle(
                color: AppColors.muted, height: 1.5, fontSize: 13)),
      ])),
    ]);
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value, this.detail});
  final String label;
  final String value;
  final String? detail;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 10)),
          const SizedBox(height: 5),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800))),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!,
                style: const TextStyle(color: AppColors.muted, fontSize: 11))
          ],
        ]),
      );
}
