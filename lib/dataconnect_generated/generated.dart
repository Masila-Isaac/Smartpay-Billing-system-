library dataconnect_generated;
import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'create_user.dart';

part 'get_my_bills.dart';

part 'pay_bill.dart';

part 'list_all_users.dart';







class ExampleConnector {
  
  
  CreateUserVariablesBuilder createUser () {
    return CreateUserVariablesBuilder(dataConnect, );
  }
  
  
  GetMyBillsVariablesBuilder getMyBills () {
    return GetMyBillsVariablesBuilder(dataConnect, );
  }
  
  
  PayBillVariablesBuilder payBill ({required String billId, required double amountPaid, required String paymentMethod, required String transactionId, }) {
    return PayBillVariablesBuilder(dataConnect, billId: billId,amountPaid: amountPaid,paymentMethod: paymentMethod,transactionId: transactionId,);
  }
  
  
  ListAllUsersVariablesBuilder listAllUsers () {
    return ListAllUsersVariablesBuilder(dataConnect, );
  }
  

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-central1',
    'example',
    'smartpay-billing-system',
  );

  ExampleConnector({required this.dataConnect});
  static ExampleConnector get instance {
    return ExampleConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}
