# review_connector SDK

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
ReviewConnector.instance.dataConnect.useDataConnectEmulator(host, port);
```

You can also call queries and mutations by using the connector class.
## Queries

### ListReviews
#### Required Arguments
```dart
// No required arguments
ReviewConnector.instance.listReviews().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListReviewsData, void>`
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

final result = await ReviewConnector.instance.listReviews();
ListReviewsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ReviewConnector.instance.listReviews().ref();
ref.execute();

ref.subscribe(...);
```


### ListReviewsByMotel
#### Required Arguments
```dart
String motelId = ...;
ReviewConnector.instance.listReviewsByMotel(
  motelId: motelId,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListReviewsByMotelData, ListReviewsByMotelVariables>`
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

final result = await ReviewConnector.instance.listReviewsByMotel(
  motelId: motelId,
);
ListReviewsByMotelData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String motelId = ...;

final ref = ReviewConnector.instance.listReviewsByMotel(
  motelId: motelId,
).ref();
ref.execute();

ref.subscribe(...);
```

## Mutations

### CreateMyReview
#### Required Arguments
```dart
String authorName = ...;
String title = ...;
String body = ...;
int rating = ...;
String motelId = ...;
int typeId = ...;
ReviewConnector.instance.createMyReview(
  authorName: authorName,
  title: title,
  body: body,
  rating: rating,
  motelId: motelId,
  typeId: typeId,
).execute();
```

#### Optional Arguments
We return a builder for each query. For CreateMyReview, we created `CreateMyReviewBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class CreateMyReviewVariablesBuilder {
  ...
   CreateMyReviewVariablesBuilder roomId(String? t) {
   _roomId.value = t;
   return this;
  }

  ...
}
ReviewConnector.instance.createMyReview(
  authorName: authorName,
  title: title,
  body: body,
  rating: rating,
  motelId: motelId,
  typeId: typeId,
)
.roomId(roomId)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<CreateMyReviewData, CreateMyReviewVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ReviewConnector.instance.createMyReview(
  authorName: authorName,
  title: title,
  body: body,
  rating: rating,
  motelId: motelId,
  typeId: typeId,
);
CreateMyReviewData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String authorName = ...;
String title = ...;
String body = ...;
int rating = ...;
String motelId = ...;
int typeId = ...;

final ref = ReviewConnector.instance.createMyReview(
  authorName: authorName,
  title: title,
  body: body,
  rating: rating,
  motelId: motelId,
  typeId: typeId,
).ref();
ref.execute();
```

