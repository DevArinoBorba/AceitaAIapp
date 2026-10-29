/// Combustível que o carro usa. Muda a unidade de preço e o consumo esperado.
enum FuelType { gasolina, etanol, gnv, eletrico }

extension FuelTypeInfo on FuelType {
  String get label => switch (this) {
        FuelType.gasolina => 'Gasolina',
        FuelType.etanol => 'Etanol',
        FuelType.gnv => 'GNV',
        FuelType.eletrico => 'Elétrico',
      };

  /// Unidade que o motorista vê no campo de preço.
  String get priceUnit => switch (this) {
        FuelType.gasolina || FuelType.etanol => 'R\$/L',
        FuelType.gnv => 'R\$/m³',
        FuelType.eletrico => 'R\$/kWh',
      };

  /// Unidade do consumo médio.
  String get consumptionUnit => switch (this) {
        FuelType.gasolina || FuelType.etanol => 'km/l',
        FuelType.gnv => 'km/m³',
        FuelType.eletrico => 'km/kWh',
      };

  /// Preço médio de partida (referência Brasil 2026).
  double get defaultPrice => switch (this) {
        FuelType.gasolina => 6.09,
        FuelType.etanol => 4.29,
        FuelType.gnv => 4.49,
        FuelType.eletrico => 0.90,
      };

  /// Consumo de partida de um popular rodando de app.
  double get defaultConsumption => switch (this) {
        FuelType.gasolina => 11.5,
        FuelType.etanol => 8.0,
        FuelType.gnv => 13.0,
        FuelType.eletrico => 6.0,
      };
}

/// Perfil de custos do veículo.
///
/// O card calcula lucro com um único número: R$ por km. O padrão do app
/// (R$ 0,75) serve para começar, mas cada carro tem um custo diferente —
/// combustível, desgaste, depreciação e contas fixas. Este perfil transforma
/// o que o motorista realmente paga nesse número.
///
/// A conta é a mesma que as calculadoras do setor usam:
///
///     custo/km = combustível + desgaste + depreciação + fixos + alimentação
///
/// - combustível: preço do litro ÷ consumo
/// - desgaste: cada peça (valor ÷ intervalo em km) + reserva de imprevisto
/// - depreciação: valor do carro × % ao ano ÷ 12 ÷ km do mês
/// - fixos: soma mensal (parcela, seguro, IPVA, MEI…) ÷ km do mês
/// - alimentação: valor do dia × dias trabalhados ÷ km do mês
class CostProfile {
  const CostProfile({
    this.fuelType = FuelType.gasolina,
    this.fuelPrice = 6.09,
    this.fuelConsumption = 11.5,
    this.oilCost = 320,
    this.oilEveryKm = 10000,
    this.tiresCost = 1800,
    this.tiresEveryKm = 45000,
    this.brakesCost = 400,
    this.brakesEveryKm = 35000,
    this.serviceCost = 600,
    this.serviceEveryKm = 30000,
    this.reservePerKm = 0.05,
    this.vehicleValue = 60000,
    this.vehicleAgeYears = 2,
    this.depreciationPct = 10,
    this.installment = 0,
    this.insuranceYearly = 2400,
    this.taxesYearly = 1500,
    this.meiMonthly = 76,
    this.internetMonthly = 60,
    this.washMonthly = 120,
    this.otherMonthly = 0,
    this.foodPerDay = 25,
    this.kmPerDay = 150,
    this.daysPerMonth = 22,
    this.hoursPerDay = 8,
  });

  // ---------------------------------------------------------------- entrada

  final FuelType fuelType;

  /// Preço pago no litro (ou m³ / kWh).
  final double fuelPrice;

  /// Consumo médio (km/l, km/m³ ou km/kWh).
  final double fuelConsumption;

  /// Troca de óleo e filtros.
  final double oilCost;
  final double oilEveryKm;

  /// Jogo de pneus.
  final double tiresCost;
  final double tiresEveryKm;

  /// Pastilhas/discos de freio.
  final double brakesCost;
  final double brakesEveryKm;

  /// Revisão geral (filtros, correia, suspensão, alinhamento).
  final double serviceCost;
  final double serviceEveryKm;

  /// Reserva por km para o que quebrar sem avisar.
  final double reservePerKm;

  /// Valor atual do carro (tabela FIPE ou o que pagou).
  final double vehicleValue;

  /// Idade do carro em anos — define o % de depreciação sugerido.
  final double vehicleAgeYears;

  /// Quanto o carro perde de valor por ano, em %.
  final double depreciationPct;

  // Fixos mensais (seguro e impostos entram por ano e são divididos por 12).
  final double installment;
  final double insuranceYearly;
  final double taxesYearly;
  final double meiMonthly;
  final double internetMonthly;
  final double washMonthly;
  final double otherMonthly;

  /// Alimentação de um dia de trabalho (almoço/lanche na rua).
  /// Quem leva de casa deixa em 0.
  final double foodPerDay;

  // Sua operação — distribui os fixos por km e por hora.
  final double kmPerDay;
  final int daysPerMonth;
  final double hoursPerDay;

  // --------------------------------------------------------------- derivados

  /// Combustível por km.
  double get fuelPerKm =>
      fuelConsumption > 0 ? fuelPrice / fuelConsumption : 0;

  double get oilPerKm => _perKm(oilCost, oilEveryKm);
  double get tiresPerKm => _perKm(tiresCost, tiresEveryKm);
  double get brakesPerKm => _perKm(brakesCost, brakesEveryKm);
  double get servicePerKm => _perKm(serviceCost, serviceEveryKm);

  /// Desgaste por km: peças itemizadas + reserva.
  double get maintenancePerKm =>
      oilPerKm + tiresPerKm + brakesPerKm + servicePerKm + reservePerKm;

  double get kmPerMonth => kmPerDay * daysPerMonth;

  double get kmPerYear => kmPerMonth * 12;

  /// Quanto o carro perde de valor por mês.
  double get depreciationMonthly => vehicleValue * depreciationPct / 100 / 12;

  /// Depreciação por km: mensal ÷ km do mês (igual a anual ÷ km do ano).
  double get depreciationPerKm =>
      kmPerMonth > 0 ? depreciationMonthly / kmPerMonth : 0;

  /// Soma das contas que chegam todo mês.
  double get monthlyFixed => installment +
      (insuranceYearly + taxesYearly) / 12 +
      meiMonthly +
      internetMonthly +
      washMonthly +
      otherMonthly;

  /// Contas fixas por km.
  double get fixedPerKm => kmPerMonth > 0 ? monthlyFixed / kmPerMonth : 0;

  /// Alimentação no mês: dias trabalhados × valor do dia.
  double get foodMonthly => foodPerDay * daysPerMonth;

  /// Alimentação por km.
  double get foodPerKm => kmPerMonth > 0 ? foodMonthly / kmPerMonth : 0;

  /// Tudo que sai por mês: contas do carro + alimentação.
  double get monthlyTotal => monthlyFixed + foodMonthly;

  /// O número que o card usa: R$ de custo por km rodado.
  double get totalPerKm =>
      fuelPerKm +
      maintenancePerKm +
      depreciationPerKm +
      fixedPerKm +
      foodPerKm;

  /// Quanto sai do bolso por mês rodando essa quilometragem.
  double get monthlyCost => totalPerKm * kmPerMonth;

  /// Faturamento mínimo do dia só para empatar.
  double get breakEvenPerDay => totalPerKm * kmPerDay;

  /// Custo por hora trabalhada.
  double get costPerHour =>
      hoursPerDay > 0 ? totalPerKm * kmPerDay / hoursPerDay : 0;

  /// Lucro por hora se o dia bater o ponto de equilíbrio + margem? Não:
  /// quanto sobra por hora numa corrida que paga [perKm].
  double profitPerHourAt(double perKm) =>
      hoursPerDay > 0 ? (perKm - totalPerKm) * kmPerDay / hoursPerDay : 0;

  /// Só vale usar o perfil no card quando há km e combustível informados.
  bool get isComplete => kmPerMonth > 0 && fuelConsumption > 0 && totalPerKm > 0;

  /// Percentual de depreciação sugerido pela idade do carro.
  ///
  /// Referências (2025/2026): 15–25% no 1º ano, 8–12% no 2º/3º, 6–10% no
  /// 4º/5º e 3–5% depois disso. As calculadoras do setor usam 10% ao ano
  /// como média de mercado — é o padrão para um carro de 1 a 3 anos.
  static double depreciationPctForAge(double years) {
    if (years < 1) return 15;
    if (years < 3) return 10;
    if (years < 5) return 7;
    return 4;
  }

  CostProfile copyWith({
    FuelType? fuelType,
    double? fuelPrice,
    double? fuelConsumption,
    double? oilCost,
    double? oilEveryKm,
    double? tiresCost,
    double? tiresEveryKm,
    double? brakesCost,
    double? brakesEveryKm,
    double? serviceCost,
    double? serviceEveryKm,
    double? reservePerKm,
    double? vehicleValue,
    double? vehicleAgeYears,
    double? depreciationPct,
    double? installment,
    double? insuranceYearly,
    double? taxesYearly,
    double? meiMonthly,
    double? internetMonthly,
    double? washMonthly,
    double? otherMonthly,
    double? foodPerDay,
    double? kmPerDay,
    int? daysPerMonth,
    double? hoursPerDay,
  }) {
    return CostProfile(
      fuelType: fuelType ?? this.fuelType,
      fuelPrice: fuelPrice ?? this.fuelPrice,
      fuelConsumption: fuelConsumption ?? this.fuelConsumption,
      oilCost: oilCost ?? this.oilCost,
      oilEveryKm: oilEveryKm ?? this.oilEveryKm,
      tiresCost: tiresCost ?? this.tiresCost,
      tiresEveryKm: tiresEveryKm ?? this.tiresEveryKm,
      brakesCost: brakesCost ?? this.brakesCost,
      brakesEveryKm: brakesEveryKm ?? this.brakesEveryKm,
      serviceCost: serviceCost ?? this.serviceCost,
      serviceEveryKm: serviceEveryKm ?? this.serviceEveryKm,
      reservePerKm: reservePerKm ?? this.reservePerKm,
      vehicleValue: vehicleValue ?? this.vehicleValue,
      vehicleAgeYears: vehicleAgeYears ?? this.vehicleAgeYears,
      depreciationPct: depreciationPct ?? this.depreciationPct,
      installment: installment ?? this.installment,
      insuranceYearly: insuranceYearly ?? this.insuranceYearly,
      taxesYearly: taxesYearly ?? this.taxesYearly,
      meiMonthly: meiMonthly ?? this.meiMonthly,
      internetMonthly: internetMonthly ?? this.internetMonthly,
      washMonthly: washMonthly ?? this.washMonthly,
      otherMonthly: otherMonthly ?? this.otherMonthly,
      foodPerDay: foodPerDay ?? this.foodPerDay,
      kmPerDay: kmPerDay ?? this.kmPerDay,
      daysPerMonth: daysPerMonth ?? this.daysPerMonth,
      hoursPerDay: hoursPerDay ?? this.hoursPerDay,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fuelType': fuelType.name,
        'fuelPrice': fuelPrice,
        'fuelConsumption': fuelConsumption,
        'oilCost': oilCost,
        'oilEveryKm': oilEveryKm,
        'tiresCost': tiresCost,
        'tiresEveryKm': tiresEveryKm,
        'brakesCost': brakesCost,
        'brakesEveryKm': brakesEveryKm,
        'serviceCost': serviceCost,
        'serviceEveryKm': serviceEveryKm,
        'reservePerKm': reservePerKm,
        'vehicleValue': vehicleValue,
        'vehicleAgeYears': vehicleAgeYears,
        'depreciationPct': depreciationPct,
        'installment': installment,
        'insuranceYearly': insuranceYearly,
        'taxesYearly': taxesYearly,
        'meiMonthly': meiMonthly,
        'internetMonthly': internetMonthly,
        'washMonthly': washMonthly,
        'otherMonthly': otherMonthly,
        'foodPerDay': foodPerDay,
        'kmPerDay': kmPerDay,
        'daysPerMonth': daysPerMonth,
        'hoursPerDay': hoursPerDay,
      };

  factory CostProfile.fromJson(Map<String, dynamic> json) {
    double read(String key, double fallback) {
      final value = json[key];
      if (value is num) return value.toDouble();
      return fallback;
    }

    const fallback = CostProfile();
    final fuelName = json['fuelType'];
    final fuel = FuelType.values.firstWhere(
      (item) => item.name == fuelName,
      orElse: () => fallback.fuelType,
    );

    return CostProfile(
      fuelType: fuel,
      fuelPrice: read('fuelPrice', fallback.fuelPrice),
      fuelConsumption: read('fuelConsumption', fallback.fuelConsumption),
      oilCost: read('oilCost', fallback.oilCost),
      oilEveryKm: read('oilEveryKm', fallback.oilEveryKm),
      tiresCost: read('tiresCost', fallback.tiresCost),
      tiresEveryKm: read('tiresEveryKm', fallback.tiresEveryKm),
      brakesCost: read('brakesCost', fallback.brakesCost),
      brakesEveryKm: read('brakesEveryKm', fallback.brakesEveryKm),
      serviceCost: read('serviceCost', fallback.serviceCost),
      serviceEveryKm: read('serviceEveryKm', fallback.serviceEveryKm),
      reservePerKm: read('reservePerKm', fallback.reservePerKm),
      vehicleValue: read('vehicleValue', fallback.vehicleValue),
      vehicleAgeYears: read('vehicleAgeYears', fallback.vehicleAgeYears),
      depreciationPct: read('depreciationPct', fallback.depreciationPct),
      installment: read('installment', fallback.installment),
      insuranceYearly: read('insuranceYearly', fallback.insuranceYearly),
      taxesYearly: read('taxesYearly', fallback.taxesYearly),
      meiMonthly: read('meiMonthly', fallback.meiMonthly),
      internetMonthly: read('internetMonthly', fallback.internetMonthly),
      washMonthly: read('washMonthly', fallback.washMonthly),
      otherMonthly: read('otherMonthly', fallback.otherMonthly),
      foodPerDay: read('foodPerDay', fallback.foodPerDay),
      kmPerDay: read('kmPerDay', fallback.kmPerDay),
      daysPerMonth: read('daysPerMonth', fallback.daysPerMonth.toDouble()).round(),
      hoursPerDay: read('hoursPerDay', fallback.hoursPerDay),
    );
  }

  static double _perKm(double cost, double everyKm) =>
      everyKm > 0 ? cost / everyKm : 0;
}
