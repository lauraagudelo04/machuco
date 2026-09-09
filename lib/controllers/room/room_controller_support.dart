import 'package:machuco/models/room/room_models.dart';

const List<String> roomIncludedServiceCatalog = [
  'Jacuzzi',
  'Smart TV',
  'Wi-Fi',
  'Minibar',
  'Parqueadero',
  'Aire acondicionado',
  'Iluminación ambiental',
  'Room service',
];

String formatPricePerHour(int amount) => '\$${_formatAmount(amount)}/h';

String roomAdministrativeLabel(bool isActive) =>
    isActive ? 'Activa' : 'Inactiva';

String roomServiceSummary(RoomVisualData room) {
  if (room.includedServices.isEmpty) {
    return 'Sin servicios incluidos';
  }
  if (room.includedServices.length <= 3) {
    return room.includedServices.join(' · ');
  }
  return '${room.includedServices.take(3).join(' · ')} +${room.includedServices.length - 3}';
}

String _formatAmount(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final position = digits.length - index;
    buffer.write(digits[index]);
    if (position > 1 && position % 3 == 1) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}
