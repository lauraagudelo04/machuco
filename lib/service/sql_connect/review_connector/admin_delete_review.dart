part of 'review.dart';

class AdminDeleteReviewVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  AdminDeleteReviewVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<AdminDeleteReviewData> dataDeserializer = (dynamic json)  => AdminDeleteReviewData.fromJson(jsonDecode(json));
  Serializer<AdminDeleteReviewVariables> varsSerializer = (AdminDeleteReviewVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<AdminDeleteReviewData, AdminDeleteReviewVariables>> execute() {
    return ref().execute();
  }

  MutationRef<AdminDeleteReviewData, AdminDeleteReviewVariables> ref() {
    AdminDeleteReviewVariables vars= AdminDeleteReviewVariables(id: id,);
    return _dataConnect.mutation("AdminDeleteReview", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class AdminDeleteReviewReviewDelete {
  final String id;
  AdminDeleteReviewReviewDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AdminDeleteReviewReviewDelete otherTyped = other as AdminDeleteReviewReviewDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  AdminDeleteReviewReviewDelete({
    required this.id,
  });
}

@immutable
class AdminDeleteReviewData {
  final AdminDeleteReviewReviewDelete? review_delete;
  AdminDeleteReviewData.fromJson(dynamic json):
  
  review_delete = json['review_delete'] == null ? null : AdminDeleteReviewReviewDelete.fromJson(json['review_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AdminDeleteReviewData otherTyped = other as AdminDeleteReviewData;
    return review_delete == otherTyped.review_delete;
    
  }
  @override
  int get hashCode => review_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (review_delete != null) {
      json['review_delete'] = review_delete!.toJson();
    }
    return json;
  }

  AdminDeleteReviewData({
    this.review_delete,
  });
}

@immutable
class AdminDeleteReviewVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  AdminDeleteReviewVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AdminDeleteReviewVariables otherTyped = other as AdminDeleteReviewVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  AdminDeleteReviewVariables({
    required this.id,
  });
}

