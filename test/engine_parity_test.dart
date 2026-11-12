import 'package:aceita_ai/domain/entities/goals.dart';
import 'package:aceita_ai/domain/entities/offer.dart';
import 'package:aceita_ai/domain/entities/verdict.dart';
import 'package:aceita_ai/domain/services/earnings_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paridade entre os dois motores de cálculo do Aceita AI.
///
/// * Dart:  `lib/domain/services/earnings_engine.dart` (tela de veredito).
/// * Kotlin: `android/app/src/main/kotlin/br/com/aceitaai/app/reader/EarningsEngine.kt`
///   (card flutuante com o app fechado).
///
/// A referência de cada caso são os **valores do Kotlin**, calculados a partir
/// do código nativo, que é o que o motorista vê na rua quando o app está
/// fechado. Um `expect` que falha aqui é divergência entre os dois motores,
/// não erro de conta: as fórmulas são idênticas, o que muda é o arredondamento
/// das metas (Float no SharedPreferences) e a regra do veredito geral.
///
/// Severidades das divergências conhecidas: ver `aceita-qa.md`.
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

  group('fórmulas — Dart e Kotlin iguais', () {
    test('centavos: R\$ 7,15 · 2,1 km · 9 min', () {
      final v = engine.evaluate(offer(value: 7.15, km: 2.1, min: 9));

      // Kotlin: mesma conta, sem arredondamento intermediário.
      expect(v.valuePerKm, closeTo(3.4047619047619047, 1e-12));
      expect(v.valuePerHour, closeTo(47.666666666666664, 1e-12));
      expect(v.valuePerMin, closeTo(0.7944444444444444, 1e-12));
      expect(v.profit, closeTo(5.575, 1e-12));
      expect(v.profitPct, closeTo(77.97202797202797, 1e-12));

      expect(v.perKm.grade, Grade.good);
      expect(v.perHour.grade, Grade.good);
      expect(v.profitPctMetric.grade, Grade.good);
      expect(v.overall, Grade.good);
    });

    test('distância 0: não divide por zero e o veredito é ruim', () {
      final v = engine.evaluate(offer(value: 10, km: 0, min: 10));

      expect(v.valuePerKm, 0);
      expect(v.valuePerHour, closeTo(60, 1e-12));
      expect(v.profit, closeTo(10, 1e-12));
      expect(v.profitPct, closeTo(100, 1e-12));

      // Kotlin: perKm = 0 → BAD; profit > 0 mas perKm BAD → overall BAD.
      expect(v.perKm.grade, Grade.bad);
      expect(v.overall, Grade.bad);
    });

    test('minutos 0: não divide por zero e o veredito é ruim', () {
      final v = engine.evaluate(offer(value: 12, km: 5, min: 0));

      expect(v.valuePerHour, 0);
      expect(v.valuePerMin, 0);
      expect(v.valuePerKm, closeTo(2.4, 1e-12));

      // Kotlin: perHour = 0 → BAD → overall BAD.
      expect(v.perHour.grade, Grade.bad);
      expect(v.overall, Grade.bad);
    });

    test('valor 0: margem 0 (sem NaN) e veredito ruim', () {
      final v = engine.evaluate(offer(value: 0, km: 5, min: 10));

      expect(v.profitPct, 0);
      expect(v.profit, closeTo(-3.75, 1e-12));
      expect(v.overall, Grade.bad);
    });

    test('custo/km 0: lucro é o valor cheio', () {
      const free = EarningsEngine(Goals(costPerKm: 0));
      final v = free.evaluate(offer(value: 10, km: 10, min: 10));

      expect(v.profit, closeTo(10, 1e-12));
      expect(v.profitPct, closeTo(100, 1e-12));
      expect(v.perKm.grade, Grade.bad); // 1,00 < 1,20 mínima
      expect(v.overall, Grade.bad);
    });

    test('margem negativa: prejuízo é sempre vermelho', () {
      final v = engine.evaluate(offer(value: 3, km: 10, min: 10));

      expect(v.profit, closeTo(-4.5, 1e-12));
      expect(v.profitPct, closeTo(-150, 1e-12));
      expect(v.perKm.grade, Grade.bad);
      expect(v.profitMetric.grade, Grade.bad);
      expect(v.overall, Grade.bad);
    });
  });

  group('semáforo — limites exatos', () {
    test('R\$/h = 18,00 exato é média nos dois motores', () {
      // 18.0 é exato em Float, então o SharedPreferences não muda o limiar.
      final v = engine.evaluate(offer(value: 3, km: 10, min: 10));

      expect(v.valuePerHour, closeTo(18, 1e-12));
      expect(v.perHour.grade, Grade.average);
    });

    test('R\$/km = 2,00 exato (limite bom) é verde nos dois motores', () {
      final v = engine.evaluate(offer(value: 20, km: 10, min: 30));

      expect(v.valuePerKm, closeTo(2.0, 1e-12));
      expect(v.perKm.grade, Grade.good);
      expect(v.overall, Grade.good);
    });

    test('nota 4,60 exato é média nos dois motores', () {
      final v = engine.evaluate(offer(rating: 4.6));

      // Kotlin: 4.6f = 4.599999904632568; 4.6 >= isso → AVERAGE.
      expect(v.ratingGrade, Grade.average);
    });
  });

  group('contrato unificado (D1–D4 corrigidos, D5 pendente)', () {
    test('D1 R\$/km = 1,20 exato é média nos dois motores', () {
      // Bug antigo: o Kotlin lia a meta como Float (1.2000000476…) e
      // classificava o limiar exato como ruim. Agora as metas são gravadas
      // como texto (ReaderBridge.readGoal), então o limiar exato é média.
      // O mesmo caso está em EarningsEngineTest.kt (Kotlin).
      final v = engine.evaluate(offer(value: 12, km: 10, min: 10));

      expect(v.valuePerKm, closeTo(1.2, 1e-12));
      expect(v.perKm.grade, Grade.average,
          reason: 'Limiar exato de R\$/km é média, não ruim.');
    });

    test('D2 nota 4,80 exato é boa nos dois motores', () {
      // Bug antigo: goodRating 4.8f = 4.8000001907… e 4,80 caía para média.
      final v = engine.evaluate(offer(rating: 4.8));

      expect(v.ratingGrade, Grade.good,
          reason: 'Nota 4,80 exata é a faixa boa.');
    });

    test('D3 metas de margem editadas chegam ao motor nativo', () {
      // Metas: margem mínima 30%, boa 50% (Ajustes → Metas).
      // O `pushGoals` envia minProfitPct/goodProfitPct e o Kotlin lê as duas:
      // 25% de margem é ruim nos dois motores.
      const custom = EarningsEngine(
        Goals(minProfitPct: 30, goodProfitPct: 50),
      );
      final v = custom.evaluate(offer(value: 10, km: 10, min: 30));

      expect(v.profitPct, closeTo(25, 1e-12));
      expect(v.profitPctMetric.grade, Grade.bad,
          reason: 'Com meta de 30%, 25% de margem é ruim — no card também.');
      expect(v.overall, Grade.bad);
    });

    test('D4 o veredito geral considera a margem nos dois motores', () {
      // Custo 1,60/km: perKm 2,00 (bom), perHour 60 (bom) e margem 20% (média).
      const costly = EarningsEngine(Goals(costPerKm: 1.6));
      final v = costly.evaluate(offer(value: 10, km: 5, min: 10));

      expect(v.profitPct, closeTo(20, 1e-12));
      expect(v.perKm.grade, Grade.good);
      expect(v.perHour.grade, Grade.good);
      expect(v.overall, Grade.average,
          reason: 'Margem média puxa o veredito geral para média.');
    });

    test('D5 R\$/min: o motor nativo já calcula, o card ainda não mostra', () {
      // Pendência de produto (não de cálculo): o `Verdict` do Kotlin passou a
      // expor `perMin`, mas o `CardField` ainda não tem a chave `rmin`, então
      // o motorista não consegue escolher esse número para o card. Ver
      // aceita-qa.md (D5, S4).
      final v = engine.evaluate(offer(value: 20, km: 8, min: 20));

      expect(v.valuePerMin, closeTo(1.0, 1e-12));
      expect(v.perMin.grade, Grade.good);
    });
  });
}
