library review_connector;
import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'create_my_review.dart';

part 'reply_to_review_as_owner.dart';

part 'admin_set_review_status.dart';

part 'admin_dismiss_review_report.dart';

part 'admin_reply_to_review.dart';

part 'admin_delete_review.dart';

part 'report_review_as_owner.dart';

part 'list_reviews.dart';

part 'list_reviews_by_motel.dart';







class ReviewConnector {
  
  
  CreateMyReviewVariablesBuilder createMyReview ({required String authorName, required String title, required String body, required int rating, required String motelId, required int typeId, }) {
    return CreateMyReviewVariablesBuilder(dataConnect, authorName: authorName,title: title,body: body,rating: rating,motelId: motelId,typeId: typeId,);
  }
  
  
  ReplyToReviewAsOwnerVariablesBuilder replyToReviewAsOwner ({required String id, required String reply, }) {
    return ReplyToReviewAsOwnerVariablesBuilder(dataConnect, id: id,reply: reply,);
  }
  
  
  AdminSetReviewStatusVariablesBuilder adminSetReviewStatus ({required String id, required String status, }) {
    return AdminSetReviewStatusVariablesBuilder(dataConnect, id: id,status: status,);
  }
  
  
  AdminDismissReviewReportVariablesBuilder adminDismissReviewReport ({required String id, }) {
    return AdminDismissReviewReportVariablesBuilder(dataConnect, id: id,);
  }
  
  
  AdminReplyToReviewVariablesBuilder adminReplyToReview ({required String id, required String reply, }) {
    return AdminReplyToReviewVariablesBuilder(dataConnect, id: id,reply: reply,);
  }
  
  
  AdminDeleteReviewVariablesBuilder adminDeleteReview ({required String id, }) {
    return AdminDeleteReviewVariablesBuilder(dataConnect, id: id,);
  }
  
  
  ReportReviewAsOwnerVariablesBuilder reportReviewAsOwner ({required String id, required String reason, }) {
    return ReportReviewAsOwnerVariablesBuilder(dataConnect, id: id,reason: reason,);
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
