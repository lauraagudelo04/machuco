part of 'motel.dart';

class UpdateMyMotelVariablesBuilder {
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

  final FirebaseDataConnect _dataConnect;  UpdateMyMotelVariablesBuilder description(String? t) {
   _description.value = t;
   return this;
  }
  UpdateMyMotelVariablesBuilder generalLocation(String? t) {
   _generalLocation.value = t;
   return this;
  }

  UpdateMyMotelVariablesBuilder(this._dataConnect, {required  this.id,required  this.name,required  this.email,required  this.roomCount,required  this.nit,required  this.address,required  this.phone,required  this.paymentMethods,required  this.imageUrls,});
  Deserializer<UpdateMyMotelData> dataDeserializer = (dynamic json)  => UpdateMyMotelData.fromJson(jsonDecode(json));
  Serializer<UpdateMyMotelVariables> varsSerializer = (UpdateMyMotelVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateMyMotelData, UpdateMyMotelVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateMyMotelData, UpdateMyMotelVariables> ref() {
    UpdateMyMotelVariables vars= UpdateMyMotelVariables(id: id,name: name,email: email,roomCount: roomCount,nit: nit,address: address,phone: phone,description: _description,generalLocation: _generalLocation,paymentMethods: paymentMethods,imageUrls: imageUrls,);
    return _dataConnect.mutation("UpdateMyMotel", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateMyMotelData {
  final int motel_updateMany;
  UpdateMyMotelData.fromJson(dynamic json):
  
  motel_updateMany = nativeFromJson<int>(json['motel_updateMany']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateMyMotelData otherTyped = other as UpdateMyMotelData;
    return motel_updateMany == otherTyped.motel_updateMany;
    
  }
  @override
  int get hashCode => motel_updateMany.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['motel_updateMany'] = nativeToJson<int>(motel_updateMany);
    return json;
  }

  UpdateMyMotelData({
    required this.motel_updateMany,
  });
}

@immutable
class UpdateMyMotelVariables {
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
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateMyMotelVariables.fromJson(Map<String, dynamic> json):
  
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
        .toList() {
  
  
  
  
  
  
  
  
  
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

    final UpdateMyMotelVariables otherTyped = other as UpdateMyMotelVariables;
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
    imageUrls == otherTyped.imageUrls;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, name.hashCode, email.hashCode, roomCount.hashCode, nit.hashCode, address.hashCode, phone.hashCode, description.hashCode, generalLocation.hashCode, paymentMethods.hashCode, imageUrls.hashCode]);
  

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
    return json;
  }

  UpdateMyMotelVariables({
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
  });
}

