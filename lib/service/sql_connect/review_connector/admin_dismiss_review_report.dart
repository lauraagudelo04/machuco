part of 'review.dart';

class AdminDismissReviewReportVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  AdminDismissReviewReportVariablesBuilder(
    this._dataConnect, {
    required this.id,
  });
  Deserializer<AdminDismissReviewReportData> dataDeserializer =
      (dynamic json) => AdminDismissReviewReportData.fromJson(jsonDecode(json));
  Serializer<AdminDismissReviewReportVariables> varsSerializer =
      (AdminDismissReviewReportVariables vars) => jsonEncode(vars.toJson());
  Future<
    OperationResult<
      AdminDismissReviewReportData,
      AdminDismissReviewReportVariables
    >
  >
  execute() {
    return ref().execute();
  }

  MutationRef<AdminDismissReviewReportData, AdminDismissReviewReportVariables>
  ref() {
    AdminDismissReviewReportVariables vars = AdminDismissReviewReportVariables(
      id: id,
    );
    return _dataConnect.mutation(
      "AdminDismissReviewReport",
      dataDeserializer,
      varsSerializer,
      vars,
    );
  }
}

@immutable
class AdminDismissReviewReportReviewUpdate {
  final String id;
  AdminDismissReviewReportReviewUpdate.fromJson(dynamic json)
    : id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final AdminDismissReviewReportReviewUpdate otherTyped =
        other as AdminDismissReviewReportReviewUpdate;
    return id == otherTyped.id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  AdminDismissReviewReportReviewUpdate({required this.id});
}

@immutable
class AdminDismissReviewReportData {
  final AdminDismissReviewReportReviewUpdate? review_update;
  AdminDismissReviewReportData.fromJson(dynamic json)
    : review_update = json['review_update'] == null
          ? null
          : AdminDismissReviewReportReviewUpdate.fromJson(
              json['review_update'],
            );
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final AdminDismissReviewReportData otherTyped =
        other as AdminDismissReviewReportData;
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

  AdminDismissReviewReportData({this.review_update});
}

@immutable
class AdminDismissReviewReportVariables {
  final String id;
  @Deprecated(
    'fromJson is deprecated for Variable classes as they are no longer required for deserialization.',
  )
  AdminDismissReviewReportVariables.fromJson(Map<String, dynamic> json)
    : id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final AdminDismissReviewReportVariables otherTyped =
        other as AdminDismissReviewReportVariables;
    return id == otherTyped.id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  AdminDismissReviewReportVariables({required this.id});
}
