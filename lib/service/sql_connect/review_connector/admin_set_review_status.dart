part of 'review.dart';

class AdminSetReviewStatusVariablesBuilder {
  String id;
  String status;

  final FirebaseDataConnect _dataConnect;
  AdminSetReviewStatusVariablesBuilder(this._dataConnect, {required  this.id,required  this.status,});
  Deserializer<AdminSetReviewStatusData> dataDeserializer = (dynamic json)  => AdminSetReviewStatusData.fromJson(jsonDecode(json));
  Serializer<AdminSetReviewStatusVariables> varsSerializer = (AdminSetReviewStatusVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<AdminSetReviewStatusData, AdminSetReviewStatusVariables>> execute() {
    return ref().execute();
  }

  MutationRef<AdminSetReviewStatusData, AdminSetReviewStatusVariables> ref() {
    AdminSetReviewStatusVariables vars= AdminSetReviewStatusVariables(id: id,status: status,);
    return _dataConnect.mutation("AdminSetReviewStatus", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class AdminSetReviewStatusReviewUpdate {
  final String id;
  AdminSetReviewStatusReviewUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AdminSetReviewStatusReviewUpdate otherTyped = other as AdminSetReviewStatusReviewUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  AdminSetReviewStatusReviewUpdate({
    required this.id,
  });
}

@immutable
class AdminSetReviewStatusData {
  final AdminSetReviewStatusReviewUpdate? review_update;
  AdminSetReviewStatusData.fromJson(dynamic json):
  
  review_update = json['review_update'] == null ? null : AdminSetReviewStatusReviewUpdate.fromJson(json['review_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AdminSetReviewStatusData otherTyped = other as AdminSetReviewStatusData;
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

  AdminSetReviewStatusData({
    this.review_update,
  });
}

@immutable
class AdminSetReviewStatusVariables {
  final String id;
  final String status;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  AdminSetReviewStatusVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']),
  status = nativeFromJson<String>(json['status']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AdminSetReviewStatusVariables otherTyped = other as AdminSetReviewStatusVariables;
    return id == otherTyped.id && 
    status == otherTyped.status;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, status.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['status'] = nativeToJson<String>(status);
    return json;
  }

  AdminSetReviewStatusVariables({
    required this.id,
    required this.status,
  });
}

