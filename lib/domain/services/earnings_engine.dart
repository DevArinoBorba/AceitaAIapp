import '../entities/goals.dart';
import '../entities/offer.dart';
import '../entities/verdict.dart';

/// Motor de decisão: transforma uma oferta bruta + metas do motorista
/// em um veredito com semáforo por métrica.
///
/// Fórmulas (todas determinísticas, zero dependência de plataforma):
///   R$/km   = valor / distância
///   R$/h    = valor / (minutos / 60)
///   R$/min  = valor / minutos
///   lucro   = valor - (distância * custo/km)
///   % lucro = lucro / valor * 100
class EarningsEngine {
  const EarningsEngine(this.goals);

  final Goals goals;

  OfferVerdict evaluate(Offer offer) {
    final km = offer.distanceKm > 0 ? offer.distanceKm : 0.0;
    final minutes = offer.timeMin > 0 ? offer.timeMin : 0;

    final valuePerKm = km > 0 ? offer.value / km : 0.0;
    final valuePerHour = minutes > 0 ? offer.value / (minutes / 60.0) : 0.0;
    final valuePerMin = minutes > 0 ? offer.value / minutes : 0.0;

    final profit = offer.value - (km * goals.costPerKm);
    final profitPct =
        offer.value > 0 ? (profit / offer.value) * 100 : 0.0;

    final perKm = MetricResult(
      label: 'R\$/km',
      value: valuePerKm,
      grade: gradeOf(
        valuePerKm,
        min: goals.minPerKm,
        good: goals.goodPerKm,
      ),
      unit: MetricUnit.perKm,
    );

    final perHour = MetricResult(
      label: 'R\$/hora',
      value: valuePerHour,
      grade: gradeOf(
        valuePerHour,
        min: goals.minPerHour,
        good: goals.goodPerHour,
      ),
      unit: MetricUnit.perHour,
    );

    final perMin = MetricResult(
      label: 'R\$/min',
      value: valuePerMin,
      grade: gradeOf(
        valuePerMin,
        min: goals.minPerHour / 60.0,
        good: goals.goodPerHour / 60.0,
      ),
      unit: MetricUnit.perMin,
    );

    final profitMetric = MetricResult(
      label: 'Lucro',
      value: profit,
      grade: profit <= 0
          ? Grade.bad
          : gradeOf(
              profitPct,
              min: goals.minProfitPct,
              good: goals.goodProfitPct,
            ),
      unit: MetricUnit.currency,
    );

    final profitPctMetric = MetricResult(
      label: 'Margem',
      value: profitPct,
      grade: profit <= 0
          ? Grade.bad
          : gradeOf(
              profitPct,
              min: goals.minProfitPct,
              good: goals.goodProfitPct,
            ),
      unit: MetricUnit.percent,
    );

    final overall = _overallGrade(
      profit: profit,
      grades: <Grade>[perKm.grade, perHour.grade, profitPctMetric.grade],
    );

    final rating = offer.passengerRating;

    return OfferVerdict(
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
      ratingGrade: rating == null
          ? null
          : gradeOf(rating, min: goals.minRating, good: goals.goodRating),
      evaluatedAt: DateTime.now(),
    );
  }

  /// Regra do semáforo: acima de [good] = boa, acima de [min] = média,
  /// abaixo de [min] = ruim.
  static Grade gradeOf(double value, {required double min, required double good}) {
    if (value >= good) return Grade.good;
    if (value >= min) return Grade.average;
    return Grade.bad;
  }

  static Grade _overallGrade({
    required double profit,
    required List<Grade> grades,
  }) {
    if (profit <= 0) return Grade.bad;
    if (grades.contains(Grade.bad)) return Grade.bad;
    if (grades.every((grade) => grade == Grade.good)) return Grade.good;
    return Grade.average;
  }
}
