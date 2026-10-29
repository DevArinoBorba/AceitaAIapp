import 'package:aceita_ai/domain/entities/cost_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('combustível', () {
    test('preço ÷ consumo', () {
      const profile = CostProfile(fuelPrice: 6.09, fuelConsumption: 11.5);
      expect(profile.fuelPerKm, closeTo(0.5296, 0.0001));
    });

    test('consumo zero não divide por zero', () {
      const profile = CostProfile(fuelConsumption: 0);
      expect(profile.fuelPerKm, 0);
    });
  });

  group('desgaste', () {
    test('cada peça vira custo por km pelo intervalo', () {
      const profile = CostProfile(
        oilCost: 300,
        oilEveryKm: 10000,
        tiresCost: 1800,
        tiresEveryKm: 45000,
        brakesCost: 400,
        brakesEveryKm: 35000,
        serviceCost: 600,
        serviceEveryKm: 30000,
        reservePerKm: 0.05,
      );
      expect(profile.oilPerKm, closeTo(0.03, 0.0001));
      expect(profile.tiresPerKm, closeTo(0.04, 0.0001));
      expect(profile.brakesPerKm, closeTo(0.0114, 0.0001));
      expect(profile.servicePerKm, closeTo(0.02, 0.0001));
      expect(profile.maintenancePerKm, closeTo(0.1514, 0.0001));
    });

    test('intervalo zerado não quebra', () {
      const profile = CostProfile(oilEveryKm: 0);
      expect(profile.oilPerKm, 0);
    });
  });

  group('depreciação', () {
    test('valor × % ÷ 12 ÷ km do mês', () {
      const profile = CostProfile(
        vehicleValue: 65000,
        depreciationPct: 10,
        kmPerDay: 180,
        daysPerMonth: 25,
      );
      // 65000 × 10% = 6500/ano → 541,67/mês → 4500 km/mês
      expect(profile.depreciationMonthly, closeTo(541.6667, 0.001));
      expect(profile.depreciationPerKm, closeTo(0.1204, 0.0001));
    });

    test('% sugerido pela idade do carro', () {
      expect(CostProfile.depreciationPctForAge(0.5), 15);
      expect(CostProfile.depreciationPctForAge(1), 10);
      expect(CostProfile.depreciationPctForAge(2.9), 10);
      expect(CostProfile.depreciationPctForAge(3), 7);
      expect(CostProfile.depreciationPctForAge(4.9), 7);
      expect(CostProfile.depreciationPctForAge(5), 4);
      expect(CostProfile.depreciationPctForAge(12), 4);
    });

    test('sem km no mês não divide por zero', () {
      const profile = CostProfile(kmPerDay: 0);
      expect(profile.depreciationPerKm, 0);
      expect(profile.fixedPerKm, 0);
    });
  });

  group('custos fixos', () {
    test('seguro e impostos entram por ano ÷ 12', () {
      const profile = CostProfile(
        installment: 1200,
        insuranceYearly: 2400,
        taxesYearly: 1200,
        meiMonthly: 76,
        internetMonthly: 60,
        washMonthly: 120,
        otherMonthly: 0,
      );
      expect(profile.monthlyFixed, closeTo(1756, 0.001));
    });

    test('fixos por km usam a km do mês', () {
      const profile = CostProfile(
        installment: 1200,
        insuranceYearly: 0,
        taxesYearly: 0,
        meiMonthly: 0,
        internetMonthly: 0,
        washMonthly: 0,
        kmPerDay: 100,
        daysPerMonth: 20,
      );
      expect(profile.kmPerMonth, 2000);
      expect(profile.fixedPerKm, closeTo(0.6, 0.0001));
    });
  });

  group('alimentação', () {
    test('dia × dias trabalhados ÷ km do mês', () {
      const profile = CostProfile(
        foodPerDay: 30,
        daysPerMonth: 20,
        kmPerDay: 150,
      );
      expect(profile.foodMonthly, 600);
      expect(profile.kmPerMonth, 3000);
      expect(profile.foodPerKm, closeTo(0.2, 1e-9));
    });

    test('quem leva de casa deixa zero', () {
      const profile = CostProfile(foodPerDay: 0);
      expect(profile.foodMonthly, 0);
      expect(profile.foodPerKm, 0);
      expect(profile.totalPerKm, greaterThan(0));
    });

    test('entra no total do mês junto com as contas do carro', () {
      const profile = CostProfile(
        installment: 1200,
        insuranceYearly: 0,
        taxesYearly: 0,
        meiMonthly: 0,
        internetMonthly: 0,
        washMonthly: 0,
        otherMonthly: 0,
        foodPerDay: 25,
        daysPerMonth: 22,
      );
      expect(profile.monthlyFixed, 1200);
      expect(profile.foodMonthly, 550);
      expect(profile.monthlyTotal, 1750);
    });

    test('sem km no mês não divide por zero', () {
      const profile = CostProfile(foodPerDay: 25, kmPerDay: 0);
      expect(profile.foodPerKm, 0);
    });
  });

  group('resultado', () {
    test('custo por km soma todos os blocos', () {
      const profile = CostProfile(
        fuelPrice: 6.09,
        fuelConsumption: 11.5,
        oilCost: 320,
        oilEveryKm: 10000,
        tiresCost: 1800,
        tiresEveryKm: 45000,
        brakesCost: 400,
        brakesEveryKm: 35000,
        serviceCost: 600,
        serviceEveryKm: 30000,
        reservePerKm: 0.05,
        vehicleValue: 60000,
        depreciationPct: 10,
        installment: 0,
        insuranceYearly: 2400,
        taxesYearly: 1500,
        meiMonthly: 76,
        internetMonthly: 60,
        washMonthly: 120,
        otherMonthly: 0,
        foodPerDay: 25,
        kmPerDay: 150,
        daysPerMonth: 22,
        hoursPerDay: 8,
      );

      final expected = profile.fuelPerKm +
          profile.maintenancePerKm +
          profile.depreciationPerKm +
          profile.fixedPerKm +
          profile.foodPerKm;
      expect(profile.totalPerKm, closeTo(expected, 1e-9));
      expect(profile.totalPerKm, greaterThan(0.75));
      expect(profile.isComplete, isTrue);
    });

    test('ponto de equilíbrio e custo por hora', () {
      const profile = CostProfile(
        fuelPrice: 6,
        fuelConsumption: 10,
        oilCost: 0,
        tiresCost: 0,
        brakesCost: 0,
        serviceCost: 0,
        reservePerKm: 0,
        vehicleValue: 0,
        installment: 0,
        insuranceYearly: 0,
        taxesYearly: 0,
        meiMonthly: 0,
        internetMonthly: 0,
        washMonthly: 0,
        foodPerDay: 0,
        kmPerDay: 200,
        daysPerMonth: 20,
        hoursPerDay: 10,
      );
      expect(profile.totalPerKm, closeTo(0.6, 1e-9));
      expect(profile.breakEvenPerDay, closeTo(120, 1e-9));
      expect(profile.costPerHour, closeTo(12, 1e-9));
      expect(profile.profitPerHourAt(1.2), closeTo(12, 1e-9));
    });

    test('perfil com custo zero não é considerado completo', () {
      const profile = CostProfile(
        fuelPrice: 0,
        oilCost: 0,
        tiresCost: 0,
        brakesCost: 0,
        serviceCost: 0,
        reservePerKm: 0,
        vehicleValue: 0,
        installment: 0,
        insuranceYearly: 0,
        taxesYearly: 0,
        meiMonthly: 0,
        internetMonthly: 0,
        washMonthly: 0,
        foodPerDay: 0,
      );
      expect(profile.totalPerKm, 0);
      expect(profile.isComplete, isFalse);
    });
  });

  group('json', () {
    test('ida e volta preserva tudo', () {
      const original = CostProfile(
        fuelType: FuelType.gnv,
        fuelPrice: 4.49,
        fuelConsumption: 13,
        oilCost: 280,
        oilEveryKm: 9000,
        tiresCost: 2100,
        tiresEveryKm: 50000,
        brakesCost: 350,
        brakesEveryKm: 40000,
        serviceCost: 700,
        serviceEveryKm: 25000,
        reservePerKm: 0.07,
        vehicleValue: 72000,
        vehicleAgeYears: 4,
        depreciationPct: 7,
        installment: 1500,
        insuranceYearly: 2600,
        taxesYearly: 1800,
        meiMonthly: 76,
        internetMonthly: 80,
        washMonthly: 150,
        otherMonthly: 40,
        foodPerDay: 30,
        kmPerDay: 180,
        daysPerMonth: 24,
        hoursPerDay: 9,
      );

      final restored = CostProfile.fromJson(original.toJson());

      expect(restored.fuelType, FuelType.gnv);
      expect(restored.fuelPrice, 4.49);
      expect(restored.fuelConsumption, 13);
      expect(restored.oilEveryKm, 9000);
      expect(restored.vehicleValue, 72000);
      expect(restored.depreciationPct, 7);
      expect(restored.installment, 1500);
      expect(restored.foodPerDay, 30);
      expect(restored.daysPerMonth, 24);
      expect(restored.hoursPerDay, 9);
      expect(restored.totalPerKm, closeTo(original.totalPerKm, 1e-9));
    });

    test('json incompleto cai no padrão', () {
      final restored = CostProfile.fromJson(<String, dynamic>{});
      const fallback = CostProfile();
      expect(restored.fuelType, fallback.fuelType);
      expect(restored.fuelPrice, fallback.fuelPrice);
      expect(restored.daysPerMonth, fallback.daysPerMonth);
    });
  });
}
