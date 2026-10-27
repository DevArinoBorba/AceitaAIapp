import '../entities/goals.dart';
import '../entities/offer.dart';

/// Simulador: "se eu só aceitasse corridas acima de X R$/km, quanto eu
/// ganharia por hora?"
///
/// A projeção é feita em cima do histórico real do motorista, mantendo as
/// MESMAS horas trabalhadas (a premissa honesta: rejeitar corrida ruim e
/// esperar uma melhor). Também devolvemos a taxa de aceitação para o
/// motorista entender o custo da estratégia.
class SimulationResult {
  const SimulationResult({
    required this.thresholdPerKm,
    required this.offers,
    required this.accepted,
    required this.acceptanceRate,
    required this.hoursAnalysed,
    required this.days,
    required this.netPerHourBefore,
    required this.netPerHourAfter,
    required this.netPerWeekBefore,
    required this.netPerWeekAfter,
    required this.netPerMonthBefore,
    required this.netPerMonthAfter,
    required this.profitBefore,
    required this.profitAfter,
  });

  factory SimulationResult.empty(double thresholdPerKm) => SimulationResult(
        thresholdPerKm: thresholdPerKm,
        offers: 0,
        accepted: 0,
        acceptanceRate: 0,
        hoursAnalysed: 0,
        days: 0,
        netPerHourBefore: 0,
        netPerHourAfter: 0,
        netPerWeekBefore: 0,
        netPerWeekAfter: 0,
        netPerMonthBefore: 0,
        netPerMonthAfter: 0,
        profitBefore: 0,
        profitAfter: 0,
      );

  final double thresholdPerKm;
  final int offers;
  final int accepted;

  /// 0..1
  final double acceptanceRate;
  final double hoursAnalysed;
  final int days;

  final double netPerHourBefore;
  final double netPerHourAfter;
  final double netPerWeekBefore;
  final double netPerWeekAfter;
  final double netPerMonthBefore;
  final double netPerMonthAfter;

  /// Lucro somado no período analisado.
  final double profitBefore;
  final double profitAfter;

  double get upliftPct {
    if (netPerWeekBefore <= 0) return 0;
    return ((netPerWeekAfter - netPerWeekBefore) / netPerWeekBefore) * 100;
  }

  bool get hasData => offers > 0 && hoursAnalysed > 0;
}

class Simulator {
  const Simulator(this.goals);

  final Goals goals;

  SimulationResult run({
    required List<Offer> offers,
    required double thresholdPerKm,
  }) {
    if (offers.isEmpty) return SimulationResult.empty(thresholdPerKm);

    double net(Offer offer) => offer.value - (offer.distanceKm * goals.costPerKm);
    double hours(Offer offer) => offer.timeMin / 60.0;

    final acceptedOffers = offers
        .where((offer) =>
            offer.distanceKm > 0 &&
            hours(offer) > 0 &&
            (offer.value / offer.distanceKm) >= thresholdPerKm)
        .toList();

    final totalHours = offers.fold<double>(0, (sum, o) => sum + hours(o));
    final acceptedHours =
        acceptedOffers.fold<double>(0, (sum, o) => sum + hours(o));

    final profitBefore = offers.fold<double>(0, (sum, o) => sum + net(o));
    final profitAfter =
        acceptedOffers.fold<double>(0, (sum, o) => sum + net(o));

    final netPerHourBefore = totalHours > 0 ? profitBefore / totalHours : 0.0;
    final netPerHourAfter =
        acceptedHours > 0 ? profitAfter / acceptedHours : 0.0;

    final first = offers
        .map((o) => o.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final last =
        offers.map((o) => o.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);

    final days =
        (last.difference(first).inHours / 24.0).ceil().clamp(1, 365).toInt();

    // Projeção mantendo as mesmas horas por semana.
    final hoursPerWeek = (totalHours / days) * 7;
    final netPerWeekBefore = netPerHourBefore * hoursPerWeek;
    final netPerWeekAfter = netPerHourAfter * hoursPerWeek;

    return SimulationResult(
      thresholdPerKm: thresholdPerKm,
      offers: offers.length,
      accepted: acceptedOffers.length,
      acceptanceRate: offers.isEmpty ? 0 : acceptedOffers.length / offers.length,
      hoursAnalysed: totalHours,
      days: days,
      netPerHourBefore: netPerHourBefore,
      netPerHourAfter: netPerHourAfter,
      netPerWeekBefore: netPerWeekBefore,
      netPerWeekAfter: netPerWeekAfter,
      netPerMonthBefore: netPerWeekBefore * 4.345,
      netPerMonthAfter: netPerWeekAfter * 4.345,
      profitBefore: profitBefore,
      profitAfter: profitAfter,
    );
  }
}
