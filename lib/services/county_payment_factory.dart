import 'package:smartpay/config/counties.dart';
import 'package:smartpay/model/county.dart' show County;
import 'package:smartpay/services/kisumu_mpesa_service.dart';
import 'package:smartpay/services/nairobi_mpesa_service.dart';
import 'package:smartpay/services/mombasa_mpesa_service.dart';

abstract class CountyPaymentService {
  Future<Map<String, dynamic>> initiatePayment({
    required String userId,
    required String phone,
    required double amount,
    required String meterNumber,
    required County county,
  });

  Future<bool> testConnection();
  bool isValidPhone(String phone);

  Future checkPaymentStatus(String s) async {}
}

class CountyPaymentFactory {
  static CountyPaymentService getService(
    String countyCode,
    String paymentMethod,
  ) {
    final county = CountyConfig.getCounty(countyCode);

    switch (paymentMethod) {
      case 'mpesa':
        return _getMpesaService(county);
      default:
        return _getMpesaService(county);
    }
  }

  static CountyPaymentService _getMpesaService(County county) {
    switch (county.code) {
      case '001': // Nairobi
        return NairobiMpesaService();
      case '002': // Mombasa
        return MombasaMpesaService();
      case '003': // Kisumu
        return KisumuMpesaService();
      default:
        return NairobiMpesaService();
    }
  }

  static List<Map<String, dynamic>> getEnabledPaymentMethods(
    String countyCode,
  ) {
    final county = CountyConfig.getCounty(countyCode);
    final methods = <Map<String, dynamic>>[];

    county.paymentMethods.forEach((key, value) {
      if (value['enabled'] == true) {
        methods.add({
          'id': key,
          'name': value['name'],
          'logo': value['logo'],
          'paybill': value['paybill'] ?? county.paybillNumber,
        });
      }
    });

    return methods;
  }
}
