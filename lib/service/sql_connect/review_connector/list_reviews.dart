part of 'review.dart';

class ListReviewsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListReviewsVariablesBuilder(this._dataConnect, );
  Deserializer<ListReviewsData> dataDeserializer = (dynamic json)  => ListReviewsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListReviewsData, void>> execute() {
    return ref().execute();
  }

  QueryRef<ListReviewsData, void> ref() {
    
    return _dataConnect.query("ListReviews", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListReviewsReviews {
  final String id;
  final String authorId;
  final String authorName;
  final String title;
  final String body;
  final int rating;
  final String motelId;
  final String? roomId;
  final int typeId;
  final String status;
  final String? reportReason;
  final String? adminReply;
  final String? ownerReply;
  final Timestamp createdAt;
  ListReviewsReviews.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']),
  authorId = nativeFromJson<String>(json['authorId']),
  authorName = nativeFromJson<String>(json['authorName']),
  title = nativeFromJson<String>(json['title']),
  body = nativeFromJson<String>(json['body']),
  rating = nativeFromJson<int>(json['rating']),
  motelId = nativeFromJson<String>(json['motelId']),
  roomId = json['roomId'] == null ? null : nativeFromJson<String>(json['roomId']),
  typeId = nativeFromJson<int>(json['typeId']),
  status = nativeFromJson<String>(json['status']),
  reportReason = json['reportReason'] == null ? null : nativeFromJson<String>(json['reportReason']),
  adminReply = json['adminReply'] == null ? null : nativeFromJson<String>(json['adminReply']),
  ownerReply = json['ownerReply'] == null ? null : nativeFromJson<String>(json['ownerReply']),
  createdAt = Timestamp.fromJson(json['createdAt']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListReviewsReviews otherTyped = other as ListReviewsReviews;
    return id == otherTyped.id && 
    authorId == otherTyped.authorId && 
    authorName == otherTyped.authorName && 
    title == otherTyped.title && 
    body == otherTyped.body && 
    rating == otherTyped.rating && 
    motelId == otherTyped.motelId && 
    roomId == otherTyped.roomId && 
    typeId == otherTyped.typeId && 
    status == otherTyped.status && 
    reportReason == otherTyped.reportReason && 
    adminReply == otherTyped.adminReply && 
    ownerReply == otherTyped.ownerReply && 
    createdAt == otherTyped.createdAt;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, authorId.hashCode, authorName.hashCode, title.hashCode, body.hashCode, rating.hashCode, motelId.hashCode, roomId.hashCode, typeId.hashCode, status.hashCode, reportReason.hashCode, adminReply.hashCode, ownerReply.hashCode, createdAt.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['authorId'] = nativeToJson<String>(authorId);
    json['authorName'] = nativeToJson<String>(authorName);
    json['title'] = nativeToJson<String>(title);
    json['body'] = nativeToJson<String>(body);
    json['rating'] = nativeToJson<int>(rating);
    json['motelId'] = nativeToJson<String>(motelId);
    if (roomId != null) {
      json['roomId'] = nativeToJson<String?>(roomId);
    }
    json['typeId'] = nativeToJson<int>(typeId);
    json['status'] = nativeToJson<String>(status);
    if (reportReason != null) {
      json['reportReason'] = nativeToJson<String?>(reportReason);
    }
    if (adminReply != null) {
      json['adminReply'] = nativeToJson<String?>(adminReply);
    }
    if (ownerReply != null) {
      json['ownerReply'] = nativeToJson<String?>(ownerReply);
    }
    json['createdAt'] = createdAt.toJson();
    return json;
  }

  ListReviewsReviews({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.body,
    required this.rating,
    required this.motelId,
    this.roomId,
    required this.typeId,
    required this.status,
    this.reportReason,
    this.adminReply,
    this.ownerReply,
    required this.createdAt,
  });
}

@immutable
class ListReviewsData {
  final List<ListReviewsReviews> reviews;
  ListReviewsData.fromJson(dynamic json):
  
  reviews = (json['reviews'] as List<dynamic>)
        .map((e) => ListReviewsReviews.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListReviewsData otherTyped = other as ListReviewsData;
    return reviews == otherTyped.reviews;
    
  }
  @override
  int get hashCode => reviews.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['reviews'] = reviews.map((e) => e.toJson()).toList();
    return json;
  }

  ListReviewsData({
    required this.reviews,
  });
}

