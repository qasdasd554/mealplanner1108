class WeightLogEntry {
  final String id;
  final DateTime date;
  final double weightKg;

  const WeightLogEntry({
    required this.id,
    required this.date,
    required this.weightKg,
  });

  factory WeightLogEntry.fromJson(Map<String, dynamic> json) {
    return WeightLogEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      weightKg: (json['weight_kg'] as num).toDouble(),
    );
  }
}
