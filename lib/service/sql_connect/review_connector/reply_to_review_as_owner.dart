part of 'review.dart';

class ReplyToReviewAsOwnerVariablesBuilder {
  String id;
  String reply;

  final FirebaseDataConnect _dataConnect;
  ReplyToReviewAsOwnerVariablesBuilder(this._dataConnect, {required  this.id,required  this.reply,});
  Deserializer<ReplyToReviewAsOwnerData> dataDeserializer = (dynamic json)  => ReplyToReviewAsOwnerData.fromJson(jsonDecode(json));
  Serializer<ReplyToReviewAsOwnerVariables> varsSerializer = (ReplyToReviewAsOwnerVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<ReplyToReviewAsOwnerData, ReplyToReviewAsOwnerVariables>> execute() {
    return ref().execute();
  }

  MutationRef<ReplyToReviewAsOwnerData, ReplyToReviewAsOwnerVariables> ref() {
    ReplyToReviewAsOwnerVariables vars= ReplyToReviewAsOwnerVariables(id: id,reply: reply,);
    return _dataConnect.mutation("ReplyToReviewAsOwner", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class ReplyToReviewAsOwnerReviewUpdate {
  final String id;
  ReplyToReviewAsOwnerReviewUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ReplyToReviewAsOwnerReviewUpdate otherTyped = other as ReplyToReviewAsOwnerReviewUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  ReplyToReviewAsOwnerReviewUpdate({
    required this.id,
  });
}

@immutable
class ReplyToReviewAsOwnerData {
  final ReplyToReviewAsOwnerReviewUpdate? review_update;
  ReplyToReviewAsOwnerData.fromJson(dynamic json):
  
  review_update = json['review_update'] == null ? null : ReplyToReviewAsOwnerReviewUpdate.fromJson(json['review_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ReplyToReviewAsOwnerData otherTyped = other as ReplyToReviewAsOwnerData;
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

  ReplyToReviewAsOwnerData({
    this.review_update,
  });
}

@immutable
class ReplyToReviewAsOwnerVariables {
  final String id;
  final String reply;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  ReplyToReviewAsOwnerVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']),
  reply = nativeFromJson<String>(json['reply']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ReplyToReviewAsOwnerVariables otherTyped = other as ReplyToReviewAsOwnerVariables;
    return id == otherTyped.id && 
    reply == otherTyped.reply;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, reply.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['reply'] = nativeToJson<String>(reply);
    return json;
  }

  ReplyToReviewAsOwnerVariables({
    required this.id,
    required this.reply,
  });
}

