import 'package:smartpay/model/county.dart';

class CountyConfig {
  static final Map<String, County> counties = {
    '001': County(
      code: '001',
      name: 'Nairobi',
      paymentGateway: 'nairobi_county_gateway',
      paybillNumber: '123456',
      tillNumber: '1234567',
      customerCare: '0709 123 456',
      waterRate: 1.0,
      waterProvider: 'Nairobi City Water and Sewerage Company',
      countyLogo: 'assets/images/Nairobi.png',
      theme: {
        'primaryColor': '#006EE6',
        'secondaryColor': '#00C2FF',
      },
      paymentMethods: {
        'mpesa': {
          'enabled': true,
          'name': 'M-Pesa Nairobi',
          'logo': 'assets/images/mpesa.png',
          'service': 'NairobiMpesaService',
          'paybill': '123456',
        },
      },
    ),
    '002': County(
      code: '002',
      name: 'Mombasa',
      paymentGateway: 'mombasa_county_gateway',
      paybillNumber: '234567',
      tillNumber: '2345678',
      customerCare: '0709 234 567',
      waterRate: 1.2,
      waterProvider: 'Mombasa Water Supply and Sanitation Company',
      countyLogo: 'assets/images/Mombasa.png',
      theme: {
        'primaryColor': '#00A859',
        'secondaryColor': '#FFD700',
      },
      paymentMethods: {
        'mpesa': {
          'enabled': true,
          'name': 'M-Pesa Mombasa',
          'logo': 'assets/images/mpesa.png',
          'service': 'MombasaMpesaService',
          'paybill': '234567',
        },
      },
    ),
    // Add more counties as needed
  };

  static County getCounty(String code) {
    return counties[code] ?? counties['001']!;
  }

  static List<County> getAllCounties() {
    return counties.values.toList();
  }

  static List<Map<String, dynamic>> getCountiesList() {
    return counties.values
        .map((county) => {
              'code': county.code,
              'name': county.name,
              'waterRate': county.waterRate,
              'waterProvider': county.waterProvider,
            })
        .toList();
  }
}
