/// Estimated response date for a PQRS request.
///
/// Adds [businessDays] working days (Monday to Friday) to [start]. Holidays
/// are not considered. The time of day of [start] is kept.
DateTime addBusinessDays(DateTime start, int businessDays) {
  var result = start;
  var remaining = businessDays;
  while (remaining > 0) {
    result = result.add(const Duration(days: 1));
    if (result.weekday != DateTime.saturday &&
        result.weekday != DateTime.sunday) {
      remaining--;
    }
  }
  return result;
}
