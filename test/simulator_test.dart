import 'package:copiloto/domain/entities/goals.dart';
import 'package:copiloto/domain/entities/offer.dart';
import 'package:copiloto/domain/services/simulator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const simulator = Simulator(Goals());
  final base = DateTime(2026, 1, 1, 8);

  Offer offer(double value, {int minutes = 60, int hourOffset = 0}) {
    return Offer.create(
      appId: DriverApp.uber.id,
      value: value,
      distanceKm: 1,
      timeMin: minutes,
      createdAt: base.add(Duration(hours: hourOffset)),
    );
  }

  test('filtra pela meta de R\$/km', () {
    final result = simulator.run(
      offers: <Offer>[offer(1), offer(2), offer(3), offer(4)],
      thresholdPerKm: 2.5,
    );

    expect(result.offers, 4);
    expect(result.accepted, 2);
    expect(result.acceptanceRate, closeTo(0.5, 1e-9));
  });

  test('lucro por hora sobe ao filtrar, mantendo as horas', () {
    final result = simulator.run(
      offers: <Offer>[offer(1), offer(2), offer(3), offer(4)],
      thresholdPerKm: 2.5,
    );

    expect(result.hoursAnalysed, closeTo(4, 1e-9));
    expect(result.netPerHourBefore, closeTo(1.75, 1e-9));
    expect(result.netPerHourAfter, closeTo(2.75, 1e-9));
    expect(result.netPerWeekBefore, closeTo(49, 1e-9));
    expect(result.netPerWeekAfter, closeTo(77, 1e-9));
    expect(result.upliftPct, closeTo(57.142, 0.01));
  });

  test('filtro impossível zera o resultado e a aceitação', () {
    final result = simulator.run(
      offers: <Offer>[offer(1), offer(2)],
      thresholdPerKm: 10,
    );

    expect(result.accepted, 0);
    expect(result.acceptanceRate, 0);
    expect(result.netPerHourAfter, 0);
    expect(result.upliftPct, lessThan(0));
  });

  test('sem ofertas devolve resultado vazio sem exceção', () {
    final result = simulator.run(
      offers: const <Offer>[],
      thresholdPerKm: 2,
    );

    expect(result.hasData, isFalse);
    expect(result.netPerWeekAfter, 0);
    expect(result.acceptanceRate, 0);
  });

  test('oferta sem distância é ignorada (não vira R\$/km infinito)', () {
    final result = simulator.run(
      offers: <Offer>[
        Offer.create(
          appId: DriverApp.uber.id,
          value: 10,
          distanceKm: 0,
          timeMin: 20,
          createdAt: base,
        ),
      ],
      thresholdPerKm: 1,
    );

    expect(result.accepted, 0);
    expect(result.netPerHourAfter, 0);
  });

  test('período de 3 dias usa média diária para projetar a semana', () {
    final offers = <Offer>[
      offer(10, hourOffset: 0),
      offer(10, hourOffset: 24),
      offer(10, hourOffset: 72),
    ];
    final result = simulator.run(offers: offers, thresholdPerKm: 1);

    expect(result.days, 3);
    expect(result.acceptanceRate, 1);
    // 3 ofertas de 1h em 3 dias => 1h/dia => 7h/semana.
    expect(result.netPerWeekAfter,
        closeTo(result.netPerHourAfter * 7, 1e-9));
  });
}
