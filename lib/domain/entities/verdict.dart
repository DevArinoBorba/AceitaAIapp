import '../../core/utils/formatters.dart';
import 'goals.dart';
import 'offer.dart';

enum Grade { bad, average, good }

extension GradeX on Grade {
  String get label => switch (this) {
        Grade.bad => 'Ruim',
        Grade.average => 'Média',
        Grade.good => 'Boa',
      };

  String get advice => switch (this) {
        Grade.bad => 'Recuse',
        Grade.average => 'Aceite com cautela',
        Grade.good => 'Boa oferta',
      };

  bool get isBad => this == Grade.bad;
}

enum MetricUnit { currency, perKm, perHour, perMin, percent, rating }

class MetricResult {
  const MetricResult({
    required this.label,
    required this.value,
    required this.grade,
    required this.unit,
  });

  final String label;
  final double value;
  final Grade grade;
  final MetricUnit unit;

  String get formatted => switch (unit) {
        MetricUnit.currency => brl(value),
        MetricUnit.perKm => '${brl(value)}/km',
        MetricUnit.perHour => '${brl(value)}/h',
        MetricUnit.perMin => '${brl(value)}/min',
        MetricUnit.percent => pctLabel(value),
        MetricUnit.rating => decimal(value, 1),
      };
}

/// Resultado da avaliação de uma oferta. É o contrato visual do card
/// flutuante que, na fase 2, será desenhado pelo serviço nativo.
class OfferVerdict {
  const OfferVerdict({
    required this.offer,
    required this.goals,
    required this.valuePerKm,
    required this.valuePerHour,
    required this.valuePerMin,
    required this.profit,
    required this.profitPct,
    required this.perKm,
    required this.perHour,
    required this.perMin,
    required this.profitMetric,
    required this.profitPctMetric,
    required this.overall,
    required this.evaluatedAt,
    this.ratingGrade,
    this.accepted,
  });

  final Offer offer;
  final Goals goals;

  final double valuePerKm;
  final double valuePerHour;
  final double valuePerMin;
  final double profit;
  final double profitPct;

  final MetricResult perKm;
  final MetricResult perHour;
  final MetricResult perMin;
  final MetricResult profitMetric;
  final MetricResult profitPctMetric;

  final Grade overall;

  /// Nota do passageiro, quando o app informa.
  final Grade? ratingGrade;

  final DateTime evaluatedAt;

  /// O motorista aceitou a corrida? `true` aceita, `false` recusada,
  /// `null` indefinida (o serviço não viu a tela seguinte, ou a oferta foi
  /// avaliada à mão).
  final bool? accepted;

  List<MetricResult> get metrics => <MetricResult>[
        perKm,
        perHour,
        perMin,
        profitMetric,
        profitPctMetric,
      ];

  String get headline => overall.advice;

  OfferVerdict copyWith({bool? accepted}) => OfferVerdict(
        offer: offer,
        goals: goals,
        valuePerKm: valuePerKm,
        valuePerHour: valuePerHour,
        valuePerMin: valuePerMin,
        profit: profit,
        profitPct: profitPct,
        perKm: perKm,
        perHour: perHour,
        perMin: perMin,
        profitMetric: profitMetric,
        profitPctMetric: profitPctMetric,
        overall: overall,
        evaluatedAt: evaluatedAt,
        ratingGrade: ratingGrade,
        accepted: accepted ?? this.accepted,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'offer': offer.toJson(),
        'goals': goals.toJson(),
        if (accepted != null) 'accepted': accepted,
      };
}
