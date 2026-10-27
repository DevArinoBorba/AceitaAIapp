import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui_kit.dart';
import '../../domain/entities/verdict.dart';

/// O card de veredito. É o mesmo desenho que, na fase 2, vai para o overlay
/// nativo (acessibilidade) — por isso ele recebe apenas um [OfferVerdict].
class VerdictCard extends StatelessWidget {
  const VerdictCard({
    super.key,
    required this.verdict,
    this.compact = false,
  });

  final OfferVerdict verdict;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = gradeColor(verdict.overall);
    final offer = verdict.offer;
    final metrics = compact
        ? <MetricResult>[
            verdict.perKm,
            verdict.perHour,
            verdict.profitMetric,
          ]
        : verdict.metrics;

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            color.withValues(alpha: 0.20),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  verdict.headline,
                  style: TextStyle(
                    color: color,
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              GradePill(
                grade: verdict.overall,
                compact: compact,
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: Text(
                  brl(offer.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: compact ? 26 : 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${brl(verdict.valuePerKm)}/km',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  offer.app.label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 16),
          Divider(color: AppColors.border.withValues(alpha: 0.8), height: 1),
          SizedBox(height: compact ? 10 : 14),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: metrics
                .map((metric) => _MetricTile(metric: metric, compact: compact))
                .toList(),
          ),
          if (!compact && verdict.ratingGrade != null) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const Icon(Icons.star_rounded,
                    size: 16, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  'Passageiro ${decimal(verdict.offer.passengerRating ?? 0)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                GradeDot(grade: verdict.ratingGrade!, size: 7),
              ],
            ),
          ],
          SizedBox(height: compact ? 10 : 14),
          Text(
            <String>[
              kmLabel(offer.distanceKm),
              timeLabel(offer.timeMin),
              if (offer.label != null && offer.label!.isNotEmpty) offer.label!,
              shortDate(offer.createdAt),
            ].join('  ·  '),
            style: TextStyle(
              color: AppColors.muted.withValues(alpha: 0.9),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.compact});

  final MetricResult metric;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 74 : 86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              GradeDot(grade: metric.grade, size: 6),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  metric.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            metric.formatted,
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
