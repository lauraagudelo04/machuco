part of 'motel.dart';

class AdminUpdateMotelVariablesBuilder {
  String id;
  String name;
  String email;
  int roomCount;
  String nit;
  String address;
  String phone;
  Optional<String> _description = Optional.optional(nativeFromJson, nativeToJson);
  Optional<String> _generalLocation = Optional.optional(nativeFromJson, nativeToJson);
  List<String> paymentMethods;
  List<String> imageUrls;
  bool isAvailable;

  final FirebaseDataConnect _dataConnect;  AdminUpdateMotelVariablesBuilder description(String? t) {
   _description.value = t;
   return this;
  }
  AdminUpdateMotelVariablesBuilder generalLocation(String? t) {
   _generalLocation.value = t;
   return this;
  }

  AdminUpdateMotelVariablesBuilder(this._dataConnect, {required  this.id,required  this.name,required  this.email,required  this.roomCount,required  this.nit,required  this.address,required  this.phone,required  this.paymentMethods,required  this.imageUrls,required  this.isAvailable,});
  Deserializer<AdminUpdateMotelData> dataDeserializer = (dynamic json)  => AdminUpdateMotelData.fromJson(jsonDecode(json));
  Serializer<AdminUpdateMotelVariables> varsSerializer = (AdminUpdateMotelVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<AdminUpdateMotelData, AdminUpdateMotelVariables>> execute() {
    return ref().execute();
  }

  MutationRef<AdminUpdateMotelData, AdminUpdateMotelVariables> ref() {
    AdminUpdateMotelVariables vars= AdminUpdateMotelVariables(id: id,name: name,email: email,roomCount: roomCount,nit: nit,address: address,phone: phone,description: _description,generalLocation: _generalLocation,paymentMethods: paymentMethods,imageUrls: imageUrls,isAvailable: isAvailable,);
    return _dataConnect.mutation("AdminUpdateMotel", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class AdminUpdateMotelMotelUpdate {
  final String id;
  AdminUpdateMotelMotelUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AdminUpdateMotelMotelUpdate otherTyped = other as AdminUpdateMotelMotelUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  AdminUpdateMotelMotelUpdate({
    required this.id,
  });
}

@immutable
class AdminUpdateMotelData {
  final AdminUpdateMotelMotelUpdate? motel_update;
  AdminUpdateMotelData.fromJson(dynamic json):
  
  motel_update = json['motel_update'] == null ? null : AdminUpdateMotelMotelUpdate.fromJson(json['motel_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AdminUpdateMotelData otherTyped = other as AdminUpdateMotelData;
    return motel_update == otherTyped.motel_update;
    
  }
  @override
  int get hashCode => motel_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (motel_update != null) {
      json['motel_update'] = motel_update!.toJson();
    }
    return json;
  }

  AdminUpdateMotelData({
    this.motel_update,
  });
}

@immutable
class AdminUpdateMotelVariables {
  final String id;
  final String name;
  final String email;
  final int roomCount;
  final String nit;
  final String address;
  final String phone;
  late final Optional<String>description;
  late final Optional<String>generalLocation;
  final List<String> paymentMethods;
  final List<String> imageUrls;
  final bool isAvailable;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  AdminUpdateMotelVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']),
  name = nativeFromJson<String>(json['name']),
  email = nativeFromJson<String>(json['email']),
  roomCount = nativeFromJson<int>(json['roomCount']),
  nit = nativeFromJson<String>(json['nit']),
  address = nativeFromJson<String>(json['address']),
  phone = nativeFromJson<String>(json['phone']),
  paymentMethods = (json['paymentMethods'] as List<dynamic>)
        .map((e) => nativeFromJson<String>(e))
        .toList(),
  imageUrls = (json['imageUrls'] as List<dynamic>)
        .map((e) => nativeFromJson<String>(e))
        .toList(),
  isAvailable = nativeFromJson<bool>(json['isAvailable']) {
  
  
  
  
  
  
  
  
  
    description = Optional.optional(nativeFromJson, nativeToJson);
    description.value = json['description'] == null ? null : nativeFromJson<String>(json['description']);
  
  
    generalLocation = Optional.optional(nativeFromJson, nativeToJson);
    generalLocation.value = json['generalLocation'] == null ? null : nativeFromJson<String>(json['generalLocation']);
  
  
  
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AdminUpdateMotelVariables otherTyped = other as AdminUpdateMotelVariables;
    return id == otherTyped.id && 
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
  int get hashCode => Object.hashAll([id.hashCode, name.hashCode, email.hashCode, roomCount.hashCode, nit.hashCode, address.hashCode, phone.hashCode, description.hashCode, generalLocation.hashCode, paymentMethods.hashCode, imageUrls.hashCode, isAvailable.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['name'] = nativeToJson<String>(name);
    json['email'] = nativeToJson<String>(email);
    json['roomCount'] = nativeToJson<int>(roomCount);
    json['nit'] = nativeToJson<String>(nit);
    json['address'] = nativeToJson<String>(address);
    json['phone'] = nativeToJson<String>(phone);
    if(description.state == OptionalState.set) {
      json['description'] = description.toJson();
    }
    if(generalLocation.state == OptionalState.set) {
      json['generalLocation'] = generalLocation.toJson();
    }
    json['paymentMethods'] = paymentMethods.map((e) => nativeToJson<String>(e)).toList();
    json['imageUrls'] = imageUrls.map((e) => nativeToJson<String>(e)).toList();
    json['isAvailable'] = nativeToJson<bool>(isAvailable);
    return json;
  }

  AdminUpdateMotelVariables({
    required this.id,
    required this.name,
    required this.email,
    required this.roomCount,
    required this.nit,
    required this.address,
    required this.phone,
    required this.description,
    required this.generalLocation,
    required this.paymentMethods,
    required this.imageUrls,
    required this.isAvailable,
  });
}

