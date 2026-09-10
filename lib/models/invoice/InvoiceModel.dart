class InvoiceModel {
  final String commerce;
  final String amount;
  final String transferNumber;
  final String dateTime;
  final String reservationNumber;
  final String ownerName;
  final String document;
  final String description;
  final String startDate;
  final String endDate;

  const InvoiceModel({
    required this.commerce,
    required this.amount,
    required this.transferNumber,
    required this.dateTime,
    required this.reservationNumber,
    required this.ownerName,
    required this.document,
    required this.description,
    required this.startDate,
    required this.endDate,
  });
}