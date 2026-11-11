part of 'review.dart';

class CreateMyReviewVariablesBuilder {
  String authorName;
  String title;
  String body;
  int rating;
  String motelId;
  Optional<String> _roomId = Optional.optional(nativeFromJson, nativeToJson);
  int typeId;

  final FirebaseDataConnect _dataConnect;  CreateMyReviewVariablesBuilder roomId(String? t) {
   _roomId.value = t;
   return this;
  }

  CreateMyReviewVariablesBuilder(this._dataConnect, {required  this.authorName,required  this.title,required  this.body,required  this.rating,required  this.motelId,required  this.typeId,});
  Deserializer<CreateMyReviewData> dataDeserializer = (dynamic json)  => CreateMyReviewData.fromJson(jsonDecode(json));
  Serializer<CreateMyReviewVariables> varsSerializer = (CreateMyReviewVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateMyReviewData, CreateMyReviewVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateMyReviewData, CreateMyReviewVariables> ref() {
    CreateMyReviewVariables vars= CreateMyReviewVariables(authorName: authorName,title: title,body: body,rating: rating,motelId: motelId,roomId: _roomId,typeId: typeId,);
    return _dataConnect.mutation("CreateMyReview", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateMyReviewReviewInsert {
  final String id;
  CreateMyReviewReviewInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateMyReviewReviewInsert otherTyped = other as CreateMyReviewReviewInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateMyReviewReviewInsert({
    required this.id,
  });
}

@immutable
class CreateMyReviewData {
  final CreateMyReviewReviewInsert review_insert;
  CreateMyReviewData.fromJson(dynamic json):
  
  review_insert = CreateMyReviewReviewInsert.fromJson(json['review_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateMyReviewData otherTyped = other as CreateMyReviewData;
    return review_insert == otherTyped.review_insert;
    
  }
  @override
  int get hashCode => review_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['review_insert'] = review_insert.toJson();
    return json;
  }

  CreateMyReviewData({
    required this.review_insert,
  });
}

@immutable
class CreateMyReviewVariables {
  final String authorName;
  final String title;
  final String body;
  final int rating;
  final String motelId;
  late final Optional<String>roomId;
  final int typeId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateMyReviewVariables.fromJson(Map<String, dynamic> json):
  
  authorName = nativeFromJson<String>(json['authorName']),
  title = nativeFromJson<String>(json['title']),
  body = nativeFromJson<String>(json['body']),
  rating = nativeFromJson<int>(json['rating']),
  motelId = nativeFromJson<String>(json['motelId']),
  typeId = nativeFromJson<int>(json['typeId']) {
  
  
  
  
  
  
  
    roomId = Optional.optional(nativeFromJson, nativeToJson);
    roomId.value = json['roomId'] == null ? null : nativeFromJson<String>(json['roomId']);
  
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateMyReviewVariables otherTyped = other as CreateMyReviewVariables;
    return authorName == otherTyped.authorName && 
    title == otherTyped.title && 
    body == otherTyped.body && 
    rating == otherTyped.rating && 
    motelId == otherTyped.motelId && 
    roomId == otherTyped.roomId && 
    typeId == otherTyped.typeId;
    
  }
  @override
  int get hashCode => Object.hashAll([authorName.hashCode, title.hashCode, body.hashCode, rating.hashCode, motelId.hashCode, roomId.hashCode, typeId.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['authorName'] = nativeToJson<String>(authorName);
    json['title'] = nativeToJson<String>(title);
    json['body'] = nativeToJson<String>(body);
    json['rating'] = nativeToJson<int>(rating);
    json['motelId'] = nativeToJson<String>(motelId);
    if(roomId.state == OptionalState.set) {
      json['roomId'] = roomId.toJson();
    }
    json['typeId'] = nativeToJson<int>(typeId);
    return json;
  }

  CreateMyReviewVariables({
    required this.authorName,
    required this.title,
    required this.body,
    required this.rating,
    required this.motelId,
    required this.roomId,
    required this.typeId,
  });
}

