# Basic Usage

```dart
ReviewConnector.instance.CreateMyReview(createMyReviewVariables).execute();
ReviewConnector.instance.ListReviews().execute();
ReviewConnector.instance.ListReviewsByMotel(listReviewsByMotelVariables).execute();

```

## Optional Fields

Some operations may have optional fields. In these cases, the Flutter SDK exposes a builder method, and will have to be set separately.

Optional fields can be discovered based on classes that have `Optional` object types.

This is an example of a mutation with an optional field:

```dart
await ReviewConnector.instance.CreateMyReview({ ... })
.roomId(...)
.execute();
```

Note: the above example is a mutation, but the same logic applies to query operations as well. Additionally, `createMovie` is an example, and may not be available to the user.

