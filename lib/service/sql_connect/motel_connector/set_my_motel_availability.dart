part of 'motel.dart';

class SetMyMotelAvailabilityVariablesBuilder {
  String id;
  bool isAvailable;

  final FirebaseDataConnect _dataConnect;
  SetMyMotelAvailabilityVariablesBuilder(this._dataConnect, {required  this.id,required  this.isAvailable,});
  Deserializer<SetMyMotelAvailabilityData> dataDeserializer = (dynamic json)  => SetMyMotelAvailabilityData.fromJson(jsonDecode(json));
  Serializer<SetMyMotelAvailabilityVariables> varsSerializer = (SetMyMotelAvailabilityVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<SetMyMotelAvailabilityData, SetMyMotelAvailabilityVariables>> execute() {
    return ref().execute();
  }

  MutationRef<SetMyMotelAvailabilityData, SetMyMotelAvailabilityVariables> ref() {
    SetMyMotelAvailabilityVariables vars= SetMyMotelAvailabilityVariables(id: id,isAvailable: isAvailable,);
    return _dataConnect.mutation("SetMyMotelAvailability", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class SetMyMotelAvailabilityData {
  final int motel_updateMany;
  SetMyMotelAvailabilityData.fromJson(dynamic json):
  
  motel_updateMany = nativeFromJson<int>(json['motel_updateMany']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final SetMyMotelAvailabilityData otherTyped = other as SetMyMotelAvailabilityData;
    return motel_updateMany == otherTyped.motel_updateMany;
    
  }
  @override
  int get hashCode => motel_updateMany.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['motel_updateMany'] = nativeToJson<int>(motel_updateMany);
    return json;
  }

  SetMyMotelAvailabilityData({
    required this.motel_updateMany,
  });
}

@immutable
class SetMyMotelAvailabilityVariables {
  final String id;
  final bool isAvailable;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  SetMyMotelAvailabilityVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']),
  isAvailable = nativeFromJson<bool>(json['isAvailable']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final SetMyMotelAvailabilityVariables otherTyped = other as SetMyMotelAvailabilityVariables;
    return id == otherTyped.id && 
    isAvailable == otherTyped.isAvailable;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, isAvailable.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['isAvailable'] = nativeToJson<bool>(isAvailable);
    return json;
  }

  SetMyMotelAvailabilityVariables({
    required this.id,
    required this.isAvailable,
  });
}

