library motel_connector;
import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'create_my_motel.dart';

part 'update_my_motel.dart';

part 'set_my_motel_availability.dart';

part 'admin_create_motel.dart';

part 'admin_update_motel.dart';

part 'list_my_motels.dart';

part 'list_all_motels.dart';

part 'get_motel_by_id.dart';

part 'list_available_motels.dart';







class MotelConnector {
  
  
  CreateMyMotelVariablesBuilder createMyMotel ({required String name, required String email, required int roomCount, required String nit, required String address, required String phone, required List<String> paymentMethods, required List<String> imageUrls, }) {
    return CreateMyMotelVariablesBuilder(dataConnect, name: name,email: email,roomCount: roomCount,nit: nit,address: address,phone: phone,paymentMethods: paymentMethods,imageUrls: imageUrls,);
  }
  
  
  UpdateMyMotelVariablesBuilder updateMyMotel ({required String id, required String name, required String email, required int roomCount, required String nit, required String address, required String phone, required List<String> paymentMethods, required List<String> imageUrls, }) {
    return UpdateMyMotelVariablesBuilder(dataConnect, id: id,name: name,email: email,roomCount: roomCount,nit: nit,address: address,phone: phone,paymentMethods: paymentMethods,imageUrls: imageUrls,);
  }
  
  
  SetMyMotelAvailabilityVariablesBuilder setMyMotelAvailability ({required String id, required bool isAvailable, }) {
    return SetMyMotelAvailabilityVariablesBuilder(dataConnect, id: id,isAvailable: isAvailable,);
  }
  
  
  AdminCreateMotelVariablesBuilder adminCreateMotel ({required String ownerId, required String name, required String email, required int roomCount, required String nit, required String address, required String phone, required List<String> paymentMethods, required List<String> imageUrls, }) {
    return AdminCreateMotelVariablesBuilder(dataConnect, ownerId: ownerId,name: name,email: email,roomCount: roomCount,nit: nit,address: address,phone: phone,paymentMethods: paymentMethods,imageUrls: imageUrls,);
  }
  
  
  AdminUpdateMotelVariablesBuilder adminUpdateMotel ({required String id, required String name, required String email, required int roomCount, required String nit, required String address, required String phone, required List<String> paymentMethods, required List<String> imageUrls, required bool isAvailable, }) {
    return AdminUpdateMotelVariablesBuilder(dataConnect, id: id,name: name,email: email,roomCount: roomCount,nit: nit,address: address,phone: phone,paymentMethods: paymentMethods,imageUrls: imageUrls,isAvailable: isAvailable,);
  }
  
  
  ListMyMotelsVariablesBuilder listMyMotels () {
    return ListMyMotelsVariablesBuilder(dataConnect, );
  }
  
  
  ListAllMotelsVariablesBuilder listAllMotels () {
    return ListAllMotelsVariablesBuilder(dataConnect, );
  }
  
  
  GetMotelByIdVariablesBuilder getMotelById ({required String id, }) {
    return GetMotelByIdVariablesBuilder(dataConnect, id: id,);
  }
  
  
  ListAvailableMotelsVariablesBuilder listAvailableMotels () {
    return ListAvailableMotelsVariablesBuilder(dataConnect, );
  }
  

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-east4',
    'motel',
    'machuco-service',
  );

  MotelConnector({required this.dataConnect});
  static MotelConnector get instance {
    
    return MotelConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}
