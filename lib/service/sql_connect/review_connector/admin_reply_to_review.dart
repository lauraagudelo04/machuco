part of 'review.dart';

class AdminReplyToReviewVariablesBuilder {
  String id;
  String reply;

  final FirebaseDataConnect _dataConnect;
  AdminReplyToReviewVariablesBuilder(
    this._dataConnect, {
    required this.id,
    required this.reply,
  });
  Deserializer<AdminReplyToReviewData> dataDeserializer = (dynamic json) =>
      AdminReplyToReviewData.fromJson(jsonDecode(json));
  Serializer<AdminReplyToReviewVariables> varsSerializer =
      (AdminReplyToReviewVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<AdminReplyToReviewData, AdminReplyToReviewVariables>>
  execute() {
    return ref().execute();
  }

  MutationRef<AdminReplyToReviewData, AdminReplyToReviewVariables> ref() {
    AdminReplyToReviewVariables vars = AdminReplyToReviewVariables(
      id: id,
      reply: reply,
    );
    return _dataConnect.mutation(
      "AdminReplyToReview",
      dataDeserializer,
      varsSerializer,
      vars,
    );
  }
}

@immutable
class AdminReplyToReviewReviewUpdate {
  final String id;
  AdminReplyToReviewReviewUpdate.fromJson(dynamic json)
    : id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final AdminReplyToReviewReviewUpdate otherTyped =
        other as AdminReplyToReviewReviewUpdate;
    return id == otherTyped.id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  AdminReplyToReviewReviewUpdate({required this.id});
}

@immutable
class AdminReplyToReviewData {
  final AdminReplyToReviewReviewUpdate? review_update;
  AdminReplyToReviewData.fromJson(dynamic json)
    : review_update = json['review_update'] == null
          ? null
          : AdminReplyToReviewReviewUpdate.fromJson(json['review_update']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final AdminReplyToReviewData otherTyped = other as AdminReplyToReviewData;
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

  AdminReplyToReviewData({this.review_update});
}

@immutable
class AdminReplyToReviewVariables {
  final String id;
  final String reply;
  @Deprecated(
    'fromJson is deprecated for Variable classes as they are no longer required for deserialization.',
  )
  AdminReplyToReviewVariables.fromJson(Map<String, dynamic> json)
    : id = nativeFromJson<String>(json['id']),
      reply = nativeFromJson<String>(json['reply']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final AdminReplyToReviewVariables otherTyped =
        other as AdminReplyToReviewVariables;
    return id == otherTyped.id && reply == otherTyped.reply;
  }

  @override
  int get hashCode => Object.hashAll([id.hashCode, reply.hashCode]);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['reply'] = nativeToJson<String>(reply);
    return json;
  }

  AdminReplyToReviewVariables({required this.id, required this.reply});
}
