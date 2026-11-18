part of 'review.dart';

class ReportReviewAsOwnerVariablesBuilder {
  String id;
  String reason;

  final FirebaseDataConnect _dataConnect;
  ReportReviewAsOwnerVariablesBuilder(
    this._dataConnect, {
    required this.id,
    required this.reason,
  });
  Deserializer<ReportReviewAsOwnerData> dataDeserializer = (dynamic json) =>
      ReportReviewAsOwnerData.fromJson(jsonDecode(json));
  Serializer<ReportReviewAsOwnerVariables> varsSerializer =
      (ReportReviewAsOwnerVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<ReportReviewAsOwnerData, ReportReviewAsOwnerVariables>>
  execute() {
    return ref().execute();
  }

  MutationRef<ReportReviewAsOwnerData, ReportReviewAsOwnerVariables> ref() {
    ReportReviewAsOwnerVariables vars = ReportReviewAsOwnerVariables(
      id: id,
      reason: reason,
    );
    return _dataConnect.mutation(
      "ReportReviewAsOwner",
      dataDeserializer,
      varsSerializer,
      vars,
    );
  }
}

@immutable
class ReportReviewAsOwnerReviewUpdate {
  final String id;
  ReportReviewAsOwnerReviewUpdate.fromJson(dynamic json)
    : id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final ReportReviewAsOwnerReviewUpdate otherTyped =
        other as ReportReviewAsOwnerReviewUpdate;
    return id == otherTyped.id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  ReportReviewAsOwnerReviewUpdate({required this.id});
}

@immutable
class ReportReviewAsOwnerData {
  final ReportReviewAsOwnerReviewUpdate? review_update;
  ReportReviewAsOwnerData.fromJson(dynamic json)
    : review_update = json['review_update'] == null
          ? null
          : ReportReviewAsOwnerReviewUpdate.fromJson(json['review_update']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final ReportReviewAsOwnerData otherTyped = other as ReportReviewAsOwnerData;
    return review_update == otherTyped.review_update;
  }

  @override
  int get hashCode => review_update.hashCode;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (review_update != null) {
      json['review_update'] = review_update!.toJson();
    }
    return json;
  }

  ReportReviewAsOwnerData({this.review_update});
}

@immutable
class ReportReviewAsOwnerVariables {
  final String id;
  final String reason;
  @Deprecated(
    'fromJson is deprecated for Variable classes as they are no longer required for deserialization.',
  )
  ReportReviewAsOwnerVariables.fromJson(Map<String, dynamic> json)
    : id = nativeFromJson<String>(json['id']),
      reason = nativeFromJson<String>(json['reason']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final ReportReviewAsOwnerVariables otherTyped =
        other as ReportReviewAsOwnerVariables;
    return id == otherTyped.id && reason == otherTyped.reason;
  }

  @override
  int get hashCode => Object.hashAll([id.hashCode, reason.hashCode]);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['reason'] = nativeToJson<String>(reason);
    return json;
  }

  ReportReviewAsOwnerVariables({required this.id, required this.reason});
}
