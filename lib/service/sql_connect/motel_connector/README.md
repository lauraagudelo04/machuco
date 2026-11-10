# motel_connector SDK

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
MotelConnector.instance.dataConnect.useDataConnectEmulator(host, port);
```

You can also call queries and mutations by using the connector class.
## Queries

### ListMyMotels
#### Required Arguments
```dart
// No required arguments
MotelConnector.instance.listMyMotels().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListMyMotelsData, void>`
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

final result = await MotelConnector.instance.listMyMotels();
ListMyMotelsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = MotelConnector.instance.listMyMotels().ref();
ref.execute();

ref.subscribe(...);
```


### ListAllMotels
#### Required Arguments
```dart
// No required arguments
MotelConnector.instance.listAllMotels().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListAllMotelsData, void>`
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

final result = await MotelConnector.instance.listAllMotels();
ListAllMotelsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = MotelConnector.instance.listAllMotels().ref();
ref.execute();

ref.subscribe(...);
```


### GetMotelById
#### Required Arguments
```dart
String id = ...;
MotelConnector.instance.getMotelById(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetMotelByIdData, GetMotelByIdVariables>`
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

final result = await MotelConnector.instance.getMotelById(
  id: id,
);
GetMotelByIdData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = MotelConnector.instance.getMotelById(
  id: id,
).ref();
ref.execute();

ref.subscribe(...);
```


### ListAvailableMotels
#### Required Arguments
```dart
// No required arguments
MotelConnector.instance.listAvailableMotels().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListAvailableMotelsData, void>`
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

final result = await MotelConnector.instance.listAvailableMotels();
ListAvailableMotelsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = MotelConnector.instance.listAvailableMotels().ref();
ref.execute();

ref.subscribe(...);
```

## Mutations

### CreateMyMotel
#### Required Arguments
```dart
String name = ...;
String email = ...;
int roomCount = ...;
String nit = ...;
String address = ...;
String phone = ...;
String paymentMethods = ...;
String imageUrls = ...;
MotelConnector.instance.createMyMotel(
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
).execute();
```

#### Optional Arguments
We return a builder for each query. For CreateMyMotel, we created `CreateMyMotelBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class CreateMyMotelVariablesBuilder {
  ...
   CreateMyMotelVariablesBuilder description(String? t) {
   _description.value = t;
   return this;
  }
  CreateMyMotelVariablesBuilder generalLocation(String? t) {
   _generalLocation.value = t;
   return this;
  }

  ...
}
MotelConnector.instance.createMyMotel(
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
)
.description(description)
.generalLocation(generalLocation)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<CreateMyMotelData, CreateMyMotelVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await MotelConnector.instance.createMyMotel(
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
);
CreateMyMotelData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String name = ...;
String email = ...;
int roomCount = ...;
String nit = ...;
String address = ...;
String phone = ...;
String paymentMethods = ...;
String imageUrls = ...;

final ref = MotelConnector.instance.createMyMotel(
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
).ref();
ref.execute();
```


### UpdateMyMotel
#### Required Arguments
```dart
String id = ...;
String name = ...;
String email = ...;
int roomCount = ...;
String nit = ...;
String address = ...;
String phone = ...;
String paymentMethods = ...;
String imageUrls = ...;
MotelConnector.instance.updateMyMotel(
  id: id,
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
).execute();
```

#### Optional Arguments
We return a builder for each query. For UpdateMyMotel, we created `UpdateMyMotelBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class UpdateMyMotelVariablesBuilder {
  ...
   UpdateMyMotelVariablesBuilder description(String? t) {
   _description.value = t;
   return this;
  }
  UpdateMyMotelVariablesBuilder generalLocation(String? t) {
   _generalLocation.value = t;
   return this;
  }

  ...
}
MotelConnector.instance.updateMyMotel(
  id: id,
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
)
.description(description)
.generalLocation(generalLocation)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<UpdateMyMotelData, UpdateMyMotelVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await MotelConnector.instance.updateMyMotel(
  id: id,
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
);
UpdateMyMotelData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;
String name = ...;
String email = ...;
int roomCount = ...;
String nit = ...;
String address = ...;
String phone = ...;
String paymentMethods = ...;
String imageUrls = ...;

final ref = MotelConnector.instance.updateMyMotel(
  id: id,
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
).ref();
ref.execute();
```


### SetMyMotelAvailability
#### Required Arguments
```dart
String id = ...;
bool isAvailable = ...;
MotelConnector.instance.setMyMotelAvailability(
  id: id,
  isAvailable: isAvailable,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<SetMyMotelAvailabilityData, SetMyMotelAvailabilityVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await MotelConnector.instance.setMyMotelAvailability(
  id: id,
  isAvailable: isAvailable,
);
SetMyMotelAvailabilityData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;
bool isAvailable = ...;

final ref = MotelConnector.instance.setMyMotelAvailability(
  id: id,
  isAvailable: isAvailable,
).ref();
ref.execute();
```


### AdminCreateMotel
#### Required Arguments
```dart
String ownerId = ...;
String name = ...;
String email = ...;
int roomCount = ...;
String nit = ...;
String address = ...;
String phone = ...;
String paymentMethods = ...;
String imageUrls = ...;
MotelConnector.instance.adminCreateMotel(
  ownerId: ownerId,
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
).execute();
```

#### Optional Arguments
We return a builder for each query. For AdminCreateMotel, we created `AdminCreateMotelBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class AdminCreateMotelVariablesBuilder {
  ...
   AdminCreateMotelVariablesBuilder description(String? t) {
   _description.value = t;
   return this;
  }
  AdminCreateMotelVariablesBuilder generalLocation(String? t) {
   _generalLocation.value = t;
   return this;
  }

  ...
}
MotelConnector.instance.adminCreateMotel(
  ownerId: ownerId,
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
)
.description(description)
.generalLocation(generalLocation)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<AdminCreateMotelData, AdminCreateMotelVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await MotelConnector.instance.adminCreateMotel(
  ownerId: ownerId,
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
);
AdminCreateMotelData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String ownerId = ...;
String name = ...;
String email = ...;
int roomCount = ...;
String nit = ...;
String address = ...;
String phone = ...;
String paymentMethods = ...;
String imageUrls = ...;

final ref = MotelConnector.instance.adminCreateMotel(
  ownerId: ownerId,
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
).ref();
ref.execute();
```


### AdminUpdateMotel
#### Required Arguments
```dart
String id = ...;
String name = ...;
String email = ...;
int roomCount = ...;
String nit = ...;
String address = ...;
String phone = ...;
String paymentMethods = ...;
String imageUrls = ...;
bool isAvailable = ...;
MotelConnector.instance.adminUpdateMotel(
  id: id,
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
  isAvailable: isAvailable,
).execute();
```

#### Optional Arguments
We return a builder for each query. For AdminUpdateMotel, we created `AdminUpdateMotelBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class AdminUpdateMotelVariablesBuilder {
  ...
   AdminUpdateMotelVariablesBuilder description(String? t) {
   _description.value = t;
   return this;
  }
  AdminUpdateMotelVariablesBuilder generalLocation(String? t) {
   _generalLocation.value = t;
   return this;
  }

  ...
}
MotelConnector.instance.adminUpdateMotel(
  id: id,
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
  isAvailable: isAvailable,
)
.description(description)
.generalLocation(generalLocation)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<AdminUpdateMotelData, AdminUpdateMotelVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await MotelConnector.instance.adminUpdateMotel(
  id: id,
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
  isAvailable: isAvailable,
);
AdminUpdateMotelData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;
String name = ...;
String email = ...;
int roomCount = ...;
String nit = ...;
String address = ...;
String phone = ...;
String paymentMethods = ...;
String imageUrls = ...;
bool isAvailable = ...;

final ref = MotelConnector.instance.adminUpdateMotel(
  id: id,
  name: name,
  email: email,
  roomCount: roomCount,
  nit: nit,
  address: address,
  phone: phone,
  paymentMethods: paymentMethods,
  imageUrls: imageUrls,
  isAvailable: isAvailable,
).ref();
ref.execute();
```

