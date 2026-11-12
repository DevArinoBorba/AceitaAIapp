import 'package:aceita_ai/data/cost_repository.dart';
import 'package:aceita_ai/data/goals_repository.dart';
import 'package:aceita_ai/data/prefs.dart';
import 'package:aceita_ai/domain/entities/cost_profile.dart';
import 'package:aceita_ai/domain/entities/goals.dart';
import 'package:aceita_ai/domain/entities/offer.dart';
import 'package:aceita_ai/domain/entities/verdict.dart';
import 'package:aceita_ai/domain/services/earnings_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const rental = CostProfile(
  ownership: VehicleOwnership.rented,
  fuelPrice: 6,
  fuelConsumption: 10,
  rentWeekly: 600,
  rentalKmWeekly: 1000,
  foodWeekly: 150,
  washWeekly: 30,
  otherWeekly: 20,
);

void main() {
  test('alugado soma só combustível, aluguel e três extras semanais', () {
    // 0,60 combustível + (600 + 150 + 30 + 20) / 1000 = 1,40/km.
    expect(rental.totalPerKm, closeTo(1.4, 1e-12));
    expect(rental.maintenancePerKm, 0);
    expect(rental.depreciationPerKm, 0);
    expect(rental.rentalWeeklyCost, closeTo(1400, 1e-9));
    expect(rental.isComplete, isTrue);
    final changedOwnedValues = rental.copyWith(
      oilCost: 99999,
      tiresCost: 99999,
      installment: 99999,
      insuranceYearly: 99999,
      taxesYearly: 99999,
      meiMonthly: 99999,
      internetMonthly: 99999,
      foodPerDay: 99999,
      kmPerDay: 1,
      daysPerMonth: 1,
      washMonthly: 99999,
      otherMonthly: 99999,
    );
    expect(changedOwnedValues.totalPerKm, closeTo(1.4, 1e-12));
  });

  test('franquia semanal é o denominador; não é mensal', () {
    expect(
        rental.copyWith(rentalKmWeekly: 500).totalPerKm, closeTo(2.2, 1e-12));
    expect(rental.monthlyCost, closeTo(1400 * 52 / 12, 1e-8));
  });

  test('zero franquia ou aluguel impede usar custo incompleto', () {
    final zeroKm = rental.copyWith(rentalKmWeekly: 0);
    expect(zeroKm.totalPerKm.isFinite, isTrue);
    expect(zeroKm.isComplete, isFalse);
    expect(rental.copyWith(rentWeekly: 0).isComplete, isFalse);
    expect(rental.copyWith(fuelConsumption: 0).isComplete, isFalse);
  });

  test('trocar de modo preserva os valores do carro próprio e alugado', () {
    const owned = CostProfile(installment: 1500, oilCost: 450);
    final rented = owned.copyWith(
        ownership: VehicleOwnership.rented,
        rentWeekly: 600,
        rentalKmWeekly: 1000);
    final restored = rented.copyWith(ownership: VehicleOwnership.owned);
    expect(restored.totalPerKm, owned.totalPerKm);
    expect(restored.oilCost, 450);
    expect(restored.rentWeekly, 600);
  });

  test('JSON antigo segue como próprio e novo preserva campos semanais', () {
    expect(CostProfile.fromJson({'installment': 700}).isRented, isFalse);
    final restored = CostProfile.fromJson(rental.toJson());
    expect(restored.toJson(), rental.toJson());
    expect(restored.totalPerKm, rental.totalPerKm);
  });

  test('salvar/reabrir mantém aluguel e atualiza custo usado pelo card',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    await container.read(costProfileProvider.notifier).update(rental);
    expect(container.read(goalsProvider).costPerKm, closeTo(1.4, 1e-12));
    expect(CostRepository(prefs).load().toJson(), rental.toJson());
    await container
        .read(costProfileProvider.notifier)
        .update(rental.copyWith(rentalKmWeekly: 0));
    expect(container.read(goalsProvider).costPerKm, closeTo(1.4, 1e-12));
    expect(container.read(hasCostProfileProvider), isFalse);
  });

  test('paridade aluguel: oferta 20, 10 km, 20 min resulta em lucro 6', () {
    final v =
        EarningsEngine(const Goals().copyWith(costPerKm: rental.totalPerKm))
            .evaluate(Offer.create(
                appId: 'uber', value: 20, distanceKm: 10, timeMin: 20));
    expect(v.profit, closeTo(6, 1e-12));
    expect(v.profitPct, closeTo(30, 1e-12));
    expect(v.overall, Grade.good);
  });
}
