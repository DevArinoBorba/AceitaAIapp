/// Catálogo simplificado de apps de corrida/entrega.
///
/// No GigU isso é o `AppTypeEnum` (36 variantes app x país). Aqui começamos
/// com os apps relevantes no Brasil e um "Outro" como escape.
class DriverApp {
  const DriverApp({required this.id, required this.label});

  final String id;
  final String label;

  static const uber = DriverApp(id: 'uber', label: 'Uber');
  static const app99 = DriverApp(id: '99', label: '99');
  static const indrive = DriverApp(id: 'indrive', label: 'InDrive');
  static const ifood = DriverApp(id: 'ifood', label: 'iFood');
  static const keeta = DriverApp(id: 'keeta', label: 'Keeta');
  static const other = DriverApp(id: 'outro', label: 'Outro');

  static const all = <DriverApp>[uber, app99, indrive, ifood, keeta, other];

  static DriverApp byId(String id) =>
      all.firstWhere((app) => app.id == id, orElse: () => other);
}

class Offer {
  const Offer({
    required this.appId,
    required this.value,
    required this.distanceKm,
    required this.timeMin,
    required this.createdAt,
    this.passengerRating,
    this.label,
  });

  factory Offer.create({
    required String appId,
    required double value,
    required double distanceKm,
    required int timeMin,
    double? passengerRating,
    String? label,
    DateTime? createdAt,
  }) {
    return Offer(
      appId: appId,
      value: value,
      distanceKm: distanceKm,
      timeMin: timeMin,
      passengerRating: passengerRating,
      label: label,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  final String appId;
  final double value;
  final double distanceKm;
  final int timeMin;
  final double? passengerRating;
  final String? label;
  final DateTime createdAt;

  DriverApp get app => DriverApp.byId(appId);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'appId': appId,
        'value': value,
        'distanceKm': distanceKm,
        'timeMin': timeMin,
        'passengerRating': passengerRating,
        'label': label,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      appId: json['appId'] as String? ?? DriverApp.other.id,
      value: (json['value'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      timeMin: (json['timeMin'] as num?)?.toInt() ?? 0,
      passengerRating: (json['passengerRating'] as num?)?.toDouble(),
      label: json['label'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
