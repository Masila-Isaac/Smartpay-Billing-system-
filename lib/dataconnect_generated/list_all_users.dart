part of 'generated.dart';

class ListAllUsersVariablesBuilder {
  final FirebaseDataConnect _dataConnect;
  ListAllUsersVariablesBuilder(
    this._dataConnect,
  );
  Deserializer<ListAllUsersData> dataDeserializer =
      (dynamic json) => ListAllUsersData.fromJson(jsonDecode(json));

  Future<QueryResult<ListAllUsersData, void>> execute() {
    return ref().execute();
  }

  QueryRef<ListAllUsersData, void> ref() {
    return _dataConnect.query(
        "ListAllUsers", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListAllUsersUsers {
  final String id;
  final String username;
  final String email;
  ListAllUsersUsers.fromJson(dynamic json)
      : id = nativeFromJson<String>(json['id']),
        username = nativeFromJson<String>(json['username']),
        email = nativeFromJson<String>(json['email']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final ListAllUsersUsers otherTyped = other as ListAllUsersUsers;
    return id == otherTyped.id &&
        username == otherTyped.username &&
        email == otherTyped.email;
  }

  @override
  int get hashCode =>
      Object.hashAll([id.hashCode, username.hashCode, email.hashCode]);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['username'] = nativeToJson<String>(username);
    json['email'] = nativeToJson<String>(email);
    return json;
  }

  const ListAllUsersUsers({
    required this.id,
    required this.username,
    required this.email,
  });
}

@immutable
class ListAllUsersData {
  final List<ListAllUsersUsers> users;
  ListAllUsersData.fromJson(dynamic json)
      : users = (json['users'] as List<dynamic>)
            .map((e) => ListAllUsersUsers.fromJson(e))
            .toList();
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final ListAllUsersData otherTyped = other as ListAllUsersData;
    return users == otherTyped.users;
  }

  @override
  int get hashCode => users.hashCode;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['users'] = users.map((e) => e.toJson()).toList();
    return json;
  }

  const ListAllUsersData({
    required this.users,
  });
}
