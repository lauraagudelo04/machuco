import 'package:floor/floor.dart';

/// Copia local del maestro remoto, independiente de la feature Payment_Method.
@Entity(tableName: 'payment_method_catalog')
class PaymentCatalogEntry {
  const PaymentCatalogEntry({required this.id, required this.name});

  @primaryKey
  final int id;
  final String name;

  factory PaymentCatalogEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['nombre'];
    if (id is! int || id <= 0 || name is! String || name.trim().isEmpty) {
      throw const FormatException('Método de pago inválido en el maestro');
    }
    return PaymentCatalogEntry(id: id, name: name.trim());
  }
}
