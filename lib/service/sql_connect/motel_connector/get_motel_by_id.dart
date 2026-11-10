part of 'motel.dart';

class GetMotelByIdVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  GetMotelByIdVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<GetMotelByIdData> dataDeserializer = (dynamic json)  => GetMotelByIdData.fromJson(jsonDecode(json));
  Serializer<GetMotelByIdVariables> varsSerializer = (GetMotelByIdVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetMotelByIdData, GetMotelByIdVariables>> execute() {
    return ref().execute();
  }

  QueryRef<GetMotelByIdData, GetMotelByIdVariables> ref() {
    GetMotelByIdVariables vars= GetMotelByIdVariables(id: id,);
    return _dataConnect.query("GetMotelById", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class GetMotelByIdMotel {
  final String id;
  final String ownerId;
  final String name;
  final String email;
  final int roomCount;
  final String nit;
  final String address;
  final String phone;
  final String? description;
  final String? generalLocation;
  final List<String> paymentMethods;
  final List<String> imageUrls;
  final bool isAvailable;
  GetMotelByIdMotel.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']),
  ownerId = nativeFromJson<String>(json['ownerId']),
  name = nativeFromJson<String>(json['name']),
  email = nativeFromJson<String>(json['email']),
  roomCount = nativeFromJson<int>(json['roomCount']),
  nit = nativeFromJson<String>(json['nit']),
  address = nativeFromJson<String>(json['address']),
  phone = nativeFromJson<String>(json['phone']),
  description = json['description'] == null ? null : nativeFromJson<String>(json['description']),
  generalLocation = json['generalLocation'] == null ? null : nativeFromJson<String>(json['generalLocation']),
  paymentMethods = (json['paymentMethods'] as List<dynamic>)
        .map((e) => nativeFromJson<String>(e))
        .toList(),
  imageUrls = (json['imageUrls'] as List<dynamic>)
        .map((e) => nativeFromJson<String>(e))
        .toList(),
  isAvailable = nativeFromJson<bool>(json['isAvailable']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetMotelByIdMotel otherTyped = other as GetMotelByIdMotel;
    return id == otherTyped.id && 
    ownerId == otherTyped.ownerId && 
    name == otherTyped.name && 
    email == otherTyped.email && 
    roomCount == otherTyped.roomCount && 
    nit == otherTyped.nit && 
    address == otherTyped.address && 
    phone == otherTyped.phone && 
    description == otherTyped.description && 
    generalLocation == otherTyped.generalLocation && 
    paymentMethods == otherTyped.paymentMethods && 
    imageUrls == otherTyped.imageUrls && 
    isAvailable == otherTyped.isAvailable;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, ownerId.hashCode, name.hashCode, email.hashCode, roomCount.hashCode, nit.hashCode, address.hashCode, phone.hashCode, description.hashCode, generalLocation.hashCode, paymentMethods.hashCode, imageUrls.hashCode, isAvailable.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['ownerId'] = nativeToJson<String>(ownerId);
    json['name'] = nativeToJson<String>(name);
    json['email'] = nativeToJson<String>(email);
    json['roomCount'] = nativeToJson<int>(roomCount);
    json['nit'] = nativeToJson<String>(nit);
    json['address'] = nativeToJson<String>(address);
    json['phone'] = nativeToJson<String>(phone);
    if (description != null) {
      json['description'] = nativeToJson<String?>(description);
    }
    if (generalLocation != null) {
      json['generalLocation'] = nativeToJson<String?>(generalLocation);
    }
    json['paymentMethods'] = paymentMethods.map((e) => nativeToJson<String>(e)).toList();
    json['imageUrls'] = imageUrls.map((e) => nativeToJson<String>(e)).toList();
    json['isAvailable'] = nativeToJson<bool>(isAvailable);
    return json;
  }

  GetMotelByIdMotel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.email,
    required this.roomCount,
    required this.nit,
    required this.address,
    required this.phone,
    this.description,
    this.generalLocation,
    required this.paymentMethods,
    required this.imageUrls,
    required this.isAvailable,
  });
}

@immutable
class GetMotelByIdData {
  final GetMotelByIdMotel? motel;
  GetMotelByIdData.fromJson(dynamic json):
  
  motel = json['motel'] == null ? null : GetMotelByIdMotel.fromJson(json['motel']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetMotelByIdData otherTyped = other as GetMotelByIdData;
    return motel == otherTyped.motel;
    
  }
  @override
  int get hashCode => motel.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (motel != null) {
      json['motel'] = motel!.toJson();
    }
    return json;
  }

  GetMotelByIdData({
    this.motel,
  });
}

@immutable
class GetMotelByIdVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  GetMotelByIdVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetMotelByIdVariables otherTyped = other as GetMotelByIdVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  GetMotelByIdVariables({
    required this.id,
  });
}

