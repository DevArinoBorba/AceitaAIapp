class Goals {
  const Goals({
    this.minPerKm = 1.20,
    this.goodPerKm = 2.00,
    this.minPerHour = 18.0,
    this.goodPerHour = 30.0,
    this.minProfitPct = 15.0,
    this.goodProfitPct = 30.0,
    this.costPerKm = 0.75,
    this.dailyTarget = 250.0,
    this.weeklyTarget = 1500.0,
    this.minRating = 4.6,
    this.goodRating = 4.8,
  });

  /// Abaixo disso a corrida é "ruim".
  final double minPerKm;

  /// Acima disso a corrida é "boa".
  final double goodPerKm;

  final double minPerHour;
  final double goodPerHour;

  /// Margem de lucro (sobre o valor bruto) considerada mínima.
  final double minProfitPct;

  /// Margem de lucro considerada boa.
  final double goodProfitPct;

  /// Custo por km (combustível + manutenção + depreciação).
  final double costPerKm;

  final double dailyTarget;
  final double weeklyTarget;

  /// Nota mínima aceitável do passageiro.
  final double minRating;

  /// Nota considerada boa.
  final double goodRating;

  Goals copyWith({
    double? minPerKm,
    double? goodPerKm,
    double? minPerHour,
    double? goodPerHour,
    double? minProfitPct,
    double? goodProfitPct,
    double? costPerKm,
    double? dailyTarget,
    double? weeklyTarget,
    double? minRating,
    double? goodRating,
  }) {
    return Goals(
      minPerKm: minPerKm ?? this.minPerKm,
      goodPerKm: goodPerKm ?? this.goodPerKm,
      minPerHour: minPerHour ?? this.minPerHour,
      goodPerHour: goodPerHour ?? this.goodPerHour,
      minProfitPct: minProfitPct ?? this.minProfitPct,
      goodProfitPct: goodProfitPct ?? this.goodProfitPct,
      costPerKm: costPerKm ?? this.costPerKm,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      weeklyTarget: weeklyTarget ?? this.weeklyTarget,
      minRating: minRating ?? this.minRating,
      goodRating: goodRating ?? this.goodRating,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'minPerKm': minPerKm,
        'goodPerKm': goodPerKm,
        'minPerHour': minPerHour,
        'goodPerHour': goodPerHour,
        'minProfitPct': minProfitPct,
        'goodProfitPct': goodProfitPct,
        'costPerKm': costPerKm,
        'dailyTarget': dailyTarget,
        'weeklyTarget': weeklyTarget,
        'minRating': minRating,
        'goodRating': goodRating,
      };

  factory Goals.fromJson(Map<String, dynamic> json) {
    double read(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : fallback;
    }

    const fallback = Goals();
    return Goals(
      minPerKm: read('minPerKm', fallback.minPerKm),
      goodPerKm: read('goodPerKm', fallback.goodPerKm),
      minPerHour: read('minPerHour', fallback.minPerHour),
      goodPerHour: read('goodPerHour', fallback.goodPerHour),
      minProfitPct: read('minProfitPct', fallback.minProfitPct),
      goodProfitPct: read('goodProfitPct', fallback.goodProfitPct),
      costPerKm: read('costPerKm', fallback.costPerKm),
      dailyTarget: read('dailyTarget', fallback.dailyTarget),
      weeklyTarget: read('weeklyTarget', fallback.weeklyTarget),
      minRating: read('minRating', fallback.minRating),
      goodRating: read('goodRating', fallback.goodRating),
    );
  }
}
