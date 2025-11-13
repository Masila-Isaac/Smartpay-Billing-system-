part of 'generated.dart';

class PayBillVariablesBuilder {
  String billId;
  double amountPaid;
  String paymentMethod;
  String transactionId;

  final FirebaseDataConnect _dataConnect;
  PayBillVariablesBuilder(
    this._dataConnect, {
    required this.billId,
    required this.amountPaid,
    required this.paymentMethod,
    required this.transactionId,
  });
  Deserializer<PayBillData> dataDeserializer =
      (dynamic json) => PayBillData.fromJson(jsonDecode(json));
  Serializer<PayBillVariables> varsSerializer =
      (PayBillVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<PayBillData, PayBillVariables>> execute() {
    return ref().execute();
  }

  MutationRef<PayBillData, PayBillVariables> ref() {
    PayBillVariables vars = PayBillVariables(
      billId: billId,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      transactionId: transactionId,
    );
    return _dataConnect.mutation(
        "PayBill", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class PayBillPaymentInsert {
  final String id;
  PayBillPaymentInsert.fromJson(dynamic json)
      : id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final PayBillPaymentInsert otherTyped = other as PayBillPaymentInsert;
    return id == otherTyped.id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const PayBillPaymentInsert({
    required this.id,
  });
}

@immutable
class PayBillData {
  final PayBillPaymentInsert payment_insert;
  PayBillData.fromJson(dynamic json)
      : payment_insert = PayBillPaymentInsert.fromJson(json['payment_insert']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final PayBillData otherTyped = other as PayBillData;
    return payment_insert == otherTyped.payment_insert;
  }

  @override
  int get hashCode => payment_insert.hashCode;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['payment_insert'] = payment_insert.toJson();
    return json;
  }

  const PayBillData({
    required this.payment_insert,
  });
}

@immutable
class PayBillVariables {
  final String billId;
  final double amountPaid;
  final String paymentMethod;
  final String transactionId;
  @Deprecated(
      'fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  PayBillVariables.fromJson(Map<String, dynamic> json)
      : billId = nativeFromJson<String>(json['billId']),
        amountPaid = nativeFromJson<double>(json['amountPaid']),
        paymentMethod = nativeFromJson<String>(json['paymentMethod']),
        transactionId = nativeFromJson<String>(json['transactionId']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final PayBillVariables otherTyped = other as PayBillVariables;
    return billId == otherTyped.billId &&
        amountPaid == otherTyped.amountPaid &&
        paymentMethod == otherTyped.paymentMethod &&
        transactionId == otherTyped.transactionId;
  }

  @override
  int get hashCode => Object.hashAll([
        billId.hashCode,
        amountPaid.hashCode,
        paymentMethod.hashCode,
        transactionId.hashCode
      ]);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['billId'] = nativeToJson<String>(billId);
    json['amountPaid'] = nativeToJson<double>(amountPaid);
    json['paymentMethod'] = nativeToJson<String>(paymentMethod);
    json['transactionId'] = nativeToJson<String>(transactionId);
    return json;
  }

  const PayBillVariables({
    required this.billId,
    required this.amountPaid,
    required this.paymentMethod,
    required this.transactionId,
  });
}
