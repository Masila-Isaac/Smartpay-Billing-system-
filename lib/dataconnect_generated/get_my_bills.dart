part of 'generated.dart';

class GetMyBillsVariablesBuilder {
  final FirebaseDataConnect _dataConnect;
  GetMyBillsVariablesBuilder(
    this._dataConnect,
  );
  Deserializer<GetMyBillsData> dataDeserializer =
      (dynamic json) => GetMyBillsData.fromJson(jsonDecode(json));

  Future<QueryResult<GetMyBillsData, void>> execute() {
    return ref().execute();
  }

  QueryRef<GetMyBillsData, void> ref() {
    return _dataConnect.query(
        "GetMyBills", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class GetMyBillsBills {
  final String id;
  final double amountDue;
  final DateTime dueDate;
  final String status;
  GetMyBillsBills.fromJson(dynamic json)
      : id = nativeFromJson<String>(json['id']),
        amountDue = nativeFromJson<double>(json['amountDue']),
        dueDate = nativeFromJson<DateTime>(json['dueDate']),
        status = nativeFromJson<String>(json['status']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final GetMyBillsBills otherTyped = other as GetMyBillsBills;
    return id == otherTyped.id &&
        amountDue == otherTyped.amountDue &&
        dueDate == otherTyped.dueDate &&
        status == otherTyped.status;
  }

  @override
  int get hashCode => Object.hashAll(
      [id.hashCode, amountDue.hashCode, dueDate.hashCode, status.hashCode]);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['amountDue'] = nativeToJson<double>(amountDue);
    json['dueDate'] = nativeToJson<DateTime>(dueDate);
    json['status'] = nativeToJson<String>(status);
    return json;
  }

  const GetMyBillsBills({
    required this.id,
    required this.amountDue,
    required this.dueDate,
    required this.status,
  });
}

@immutable
class GetMyBillsData {
  final List<GetMyBillsBills> bills;
  GetMyBillsData.fromJson(dynamic json)
      : bills = (json['bills'] as List<dynamic>)
            .map((e) => GetMyBillsBills.fromJson(e))
            .toList();
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final GetMyBillsData otherTyped = other as GetMyBillsData;
    return bills == otherTyped.bills;
  }

  @override
  int get hashCode => bills.hashCode;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['bills'] = bills.map((e) => e.toJson()).toList();
    return json;
  }

  const GetMyBillsData({
    required this.bills,
  });
}
