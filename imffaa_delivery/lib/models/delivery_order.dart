import 'dart:typed_data';

enum DeliveryOrderStatus { preparing, shipped, delivered }

String orderStatusLabel(DeliveryOrderStatus status) {
  switch (status) {
    case DeliveryOrderStatus.preparing:
      return 'Preparando';
    case DeliveryOrderStatus.shipped:
      return 'Enviado';
    case DeliveryOrderStatus.delivered:
      return 'Entregado';
  }
}

String shortOrderId(String id) {
  final normalized = id.replaceAll('-', '').toUpperCase();
  return normalized.length > 8 ? normalized.substring(0, 8) : normalized;
}

class DeliveryOrderLine {
  const DeliveryOrderLine({required this.productId, required this.name, required this.price, required this.quantity, required this.color, required this.size});
  final int productId;
  final String name;
  final int price;
  final int quantity;
  final String color;
  final String size;
  int get total => price * quantity;
}

class DeliveryOrder {
  const DeliveryOrder({required this.id, required this.customer, required this.email, required this.phone, required this.address, required this.paymentMethod, required this.lines, required this.subtotal, required this.shipping, required this.total, required this.createdAt, required this.status, this.receiptBytes});
  final String id;
  final String customer;
  final String email;
  final String phone;
  final String address;
  final String paymentMethod;
  final List<DeliveryOrderLine> lines;
  final int subtotal;
  final int shipping;
  final int total;
  final DateTime createdAt;
  final DeliveryOrderStatus status;
  final Uint8List? receiptBytes;

  DeliveryOrder copyWith({DeliveryOrderStatus? status, Uint8List? receiptBytes}) => DeliveryOrder(
    id: id, customer: customer, email: email, phone: phone, address: address,
    paymentMethod: paymentMethod, lines: lines, subtotal: subtotal, shipping: shipping,
    total: total, createdAt: createdAt, status: status ?? this.status,
    receiptBytes: receiptBytes ?? this.receiptBytes,
  );
}
