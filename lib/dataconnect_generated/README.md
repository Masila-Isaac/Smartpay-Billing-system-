# dataconnect_generated SDK

## Installation
```sh
flutter pub get firebase_data_connect
flutterfire configure
```
For more information, see [Flutter for Firebase installation documentation](https://firebase.google.com/docs/data-connect/flutter-sdk#use-core).

## Data Connect instance
Each connector creates a static class, with an instance of the `DataConnect` class that can be used to connect to your Data Connect backend and call operations.

### Connecting to the emulator

```dart
String host = 'localhost'; // or your host name
int port = 9399; // or your port number
ExampleConnector.instance.dataConnect.useDataConnectEmulator(host, port);
```

You can also call queries and mutations by using the connector class.
## Queries

### GetMyBills
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.getMyBills().execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetMyBillsData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getMyBills();
GetMyBillsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.getMyBills().ref();
ref.execute();

ref.subscribe(...);
```


### ListAllUsers
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listAllUsers().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListAllUsersData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listAllUsers();
ListAllUsersData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listAllUsers().ref();
ref.execute();

ref.subscribe(...);
```

## Mutations

### CreateUser
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.createUser().execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateUserData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createUser();
CreateUserData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.createUser().ref();
ref.execute();
```


### PayBill
#### Required Arguments
```dart
String billId = ...;
double amountPaid = ...;
String paymentMethod = ...;
String transactionId = ...;
ExampleConnector.instance.payBill(
  billId: billId,
  amountPaid: amountPaid,
  paymentMethod: paymentMethod,
  transactionId: transactionId,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<PayBillData, PayBillVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.payBill(
  billId: billId,
  amountPaid: amountPaid,
  paymentMethod: paymentMethod,
  transactionId: transactionId,
);
PayBillData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String billId = ...;
double amountPaid = ...;
String paymentMethod = ...;
String transactionId = ...;

final ref = ExampleConnector.instance.payBill(
  billId: billId,
  amountPaid: amountPaid,
  paymentMethod: paymentMethod,
  transactionId: transactionId,
).ref();
ref.execute();
```

