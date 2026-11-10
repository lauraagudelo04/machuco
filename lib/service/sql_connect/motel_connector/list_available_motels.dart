part of 'motel.dart';

class ListAvailableMotelsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListAvailableMotelsVariablesBuilder(this._dataConnect, );
  Deserializer<ListAvailableMotelsData> dataDeserializer = (dynamic json)  => ListAvailableMotelsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListAvailableMotelsData, void>> execute() {
    return ref().execute();
  }

  QueryRef<ListAvailableMotelsData, void> ref() {
    
    return _dataConnect.query("ListAvailableMotels", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListAvailableMotelsMotels {
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
  ListAvailableMotelsMotels.fromJson(dynamic json):
  
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

    final ListAvailableMotelsMotels otherTyped = other as ListAvailableMotelsMotels;
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

  ListAvailableMotelsMotels({
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
class ListAvailableMotelsData {
  final List<ListAvailableMotelsMotels> motels;
  ListAvailableMotelsData.fromJson(dynamic json):
  
  motels = (json['motels'] as List<dynamic>)
        .map((e) => ListAvailableMotelsMotels.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListAvailableMotelsData otherTyped = other as ListAvailableMotelsData;
    return motels == otherTyped.motels;
    
  }
  @override
  int get hashCode => motels.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['motels'] = motels.map((e) => e.toJson()).toList();
    return json;
  }

  ListAvailableMotelsData({
    required this.motels,
  });
}

