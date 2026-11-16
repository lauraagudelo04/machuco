library review_connector;
import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'create_my_review.dart';

part 'list_reviews.dart';

part 'list_reviews_by_motel.dart';







class ReviewConnector {
  
  
  CreateMyReviewVariablesBuilder createMyReview ({required String authorName, required String title, required String body, required int rating, required String motelId, required int typeId, }) {
    return CreateMyReviewVariablesBuilder(dataConnect, authorName: authorName,title: title,body: body,rating: rating,motelId: motelId,typeId: typeId,);
  }
  
  
  ListReviewsVariablesBuilder listReviews () {
    return ListReviewsVariablesBuilder(dataConnect, );
  }
  
  
  ListReviewsByMotelVariablesBuilder listReviewsByMotel ({required String motelId, }) {
    return ListReviewsByMotelVariablesBuilder(dataConnect, motelId: motelId,);
  }
  

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-east4',
    'review',
    'machuco-service',
  );

  ReviewConnector({required this.dataConnect});
  static ReviewConnector get instance {
    
    return ReviewConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}
