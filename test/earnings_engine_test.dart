import 'package:copiloto/domain/entities/goals.dart';
import 'package:copiloto/domain/entities/offer.dart';
import 'package:copiloto/domain/entities/verdict.dart';
import 'package:copiloto/domain/services/earnings_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = EarningsEngine(Goals());

  Offer offer({
    double value = 20,
    double km = 8,
    int min = 20,
    double? rating,
  }) {
    return Offer.create(
      appId: DriverApp.uber.id,
      value: value,
      distanceKm: km,
      timeMin: min,
      passengerRating: rating,
      createdAt: DateTime(2026, 1, 1, 12),
    );
  }

  group('métricas', () {
    test('calcula R\$/km, R\$/h, R\$/min, lucro e margem', () {
      final verdict = engine.evaluate(offer());

      expect(verdict.valuePerKm, closeTo(2.5, 1e-9));
      expect(verdict.valuePerHour, closeTo(60, 1e-9));
      expect(verdict.valuePerMin, closeTo(1.0, 1e-9));
      expect(verdict.profit, closeTo(14, 1e-9));
      expect(verdict.profitPct, closeTo(70, 1e-9));
    });

    test('distância zero não divide por zero', () {
      final verdict = engine.evaluate(offer(value: 10, km: 0, min: 10));

      expect(verdict.valuePerKm, 0);
      expect(verdict.profit, closeTo(10, 1e-9));
      expect(verdict.profitPct, closeTo(100, 1e-9));
    });

    test('tempo zero não divide por zero', () {
      final verdict = engine.evaluate(offer(min: 0));

      expect(verdict.valuePerHour, 0);
      expect(verdict.valuePerMin, 0);
    });

    test('valor zero não gera NaN na margem', () {
      final verdict = engine.evaluate(offer(value: 0, km: 5, min: 10));

      expect(verdict.profitPct, 0);
      expect(verdict.overall, Grade.bad);
    });
  });

  group('semáforo', () {
    test('limites exatos das faixas', () {
      expect(
        EarningsEngine.gradeOf(2.0, min: 1.2, good: 2.0),
        Grade.good,
      );
      expect(
        EarningsEngine.gradeOf(1.2, min: 1.2, good: 2.0),
        Grade.average,
      );
      expect(
        EarningsEngine.gradeOf(1.19, min: 1.2, good: 2.0),
        Grade.bad,
      );
    });

    test('oferta boa fica verde em todas as métricas', () {
      final verdict = engine.evaluate(offer());

      expect(verdict.perKm.grade, Grade.good);
      expect(verdict.perHour.grade, Grade.good);
      expect(verdict.profitPctMetric.grade, Grade.good);
      expect(verdict.overall, Grade.good);
    });

    test('corrida longa e barata fica vermelha', () {
      final verdict = engine.evaluate(offer(value: 10, km: 12, min: 40));

      expect(verdict.perKm.grade, Grade.bad);
      expect(verdict.overall, Grade.bad);
    });

    test('prejuízo é sempre vermelho, mesmo com boa métrica', () {
      final verdict = engine.evaluate(offer(value: 3, km: 10, min: 20));

      expect(verdict.profit, lessThan(0));
      expect(verdict.profitMetric.grade, Grade.bad);
      expect(verdict.overall, Grade.bad);
    });

    test('uma métrica ruim derruba o veredito (pior manda)', () {
      // R$/km e margem bons, mas R$/hora abaixo do mínimo (18/h).
      final verdict = engine.evaluate(offer(value: 12, km: 4, min: 60));

      expect(verdict.perKm.grade, Grade.good);
      expect(verdict.perHour.grade, Grade.bad);
      expect(verdict.overall, Grade.bad);
    });

    test('nota do passageiro', () {
      expect(engine.evaluate(offer(rating: 4.9)).ratingGrade, Grade.good);
      expect(engine.evaluate(offer(rating: 4.7)).ratingGrade, Grade.average);
      expect(engine.evaluate(offer(rating: 4.2)).ratingGrade, Grade.bad);
      expect(engine.evaluate(offer()).ratingGrade, isNull);
    });

    test('metas invertidas (boa < mínima) não quebram o cálculo', () {
      const inverted = Goals(minPerKm: 3, goodPerKm: 2);
      final verdict = const EarningsEngine(inverted).evaluate(offer());

      expect(verdict.perKm.grade, Grade.good);
    });
  });
}
