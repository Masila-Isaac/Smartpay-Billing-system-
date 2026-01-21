class County {
  final String code;
  final String name;
  final String paymentGateway;
  final String paybillNumber;
  final String tillNumber;
  final String customerCare;
  final Map<String, dynamic> theme;
  final double waterRate;
  final Map<String, dynamic> paymentMethods;
  final String waterProvider;
  final String countyLogo;

  const County({
    required this.code,
    required this.name,
    required this.paymentGateway,
    required this.paybillNumber,
    required this.tillNumber,
    required this.customerCare,
    required this.theme,
    required this.waterRate,
    required this.paymentMethods,
    required this.waterProvider,
    required this.countyLogo,
  });

  factory County.fromJson(Map<String, dynamic> json) {
    return County(
      code: json['code'],
      name: json['name'],
      paymentGateway: json['payment_gateway'],
      paybillNumber: json['paybill_number'] ?? '',
      tillNumber: json['till_number'] ?? '',
      customerCare: json['customer_care'] ?? '',
      theme: json['theme'] ?? {},
      waterRate: (json['water_rate'] ?? 1.0).toDouble(),
      paymentMethods: json['payment_methods'] ?? {},
      waterProvider: json['water_provider'] ?? '',
      countyLogo: json['county_logo'] ?? '',
    );
  }

  String get formattedPaybill =>
      paybillNumber.isNotEmpty ? paybillNumber : 'N/A';
  String get formattedTill => tillNumber.isNotEmpty ? tillNumber : 'N/A';

  double calculateAmount(double litres) => litres * waterRate;
  double calculateLitres(double amount) => amount / waterRate;
}
