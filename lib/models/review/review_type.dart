enum ReviewType {
  room,
  motel;

  static ReviewType fromString(String value) {
    return ReviewType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => ReviewType.motel,
    );
  }
}