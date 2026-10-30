import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/delivery_order.dart';

/// Genera el comprobante en el cliente con los datos del pedido ya consultados.
/// No necesita descargar un archivo privado de Storage para que el admin lo vea.
Future<Uint8List> createReceiptPdf(DeliveryOrder order) async {
  final document = pw.Document();
  const brandGreen = PdfColor.fromInt(0xFF238841);
  final logoBytes =
      (await rootBundle.load('assets/logo_icon-512.png')).buffer.asUint8List();
  final logo = pw.MemoryImage(logoBytes);
  final local = order.createdAt.toLocal();
  final date =
      '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}  ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  final orderReference = shortOrderId(order.id);
  document.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(34),
    build: (context) =>
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: const pw.BoxDecoration(color: brandGreen),
          child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                    width: 58,
                    height: 58,
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Image(logo, fit: pw.BoxFit.contain)),
                pw.SizedBox(width: 14),
                pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                      pw.Text('IMFFAA Delivery',
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 21,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text('COMPROBANTE DE PEDIDO',
                          style: const pw.TextStyle(
                              color: PdfColor.fromInt(0xFFE2F2E6),
                              fontSize: 9,
                              letterSpacing: 1.1)),
                    ])),
                pw.SizedBox(width: 12),
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('PEDIDO',
                          style: const pw.TextStyle(
                              color: PdfColor.fromInt(0xFFE2F2E6),
                              fontSize: 8,
                              letterSpacing: 1)),
                      pw.SizedBox(height: 4),
                      pw.Text('#$orderReference',
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold)),
                    ]),
              ])),
      pw.SizedBox(height: 22),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
              pw.Text('DETALLES DEL PEDIDO',
                  style: const pw.TextStyle(
                      fontSize: 9,
                      color: brandGreen,
                      letterSpacing: 1,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('Fecha: $date'),
              pw.Text('Estado: ${orderStatusLabel(order.status)}')
            ])),
        pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
              pw.Text('DATOS DEL CLIENTE',
                  style: const pw.TextStyle(
                      fontSize: 9,
                      color: brandGreen,
                      letterSpacing: 1,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text(order.customer),
              pw.Text(order.email),
              pw.Text(order.phone),
              pw.Text(order.address)
            ])),
      ]),
      pw.SizedBox(height: 20),
      pw.Divider(color: brandGreen, thickness: 1.2),
      pw.SizedBox(height: 6),
      pw.Text('ARTÍCULOS',
          style:
              const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      ...order.lines.map((line) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          decoration: const pw.BoxDecoration(
              border:
                  pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
          child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(line.name,
                              style: const pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 3),
                          pw.Text('Color: ${line.color} · Talla: ${line.size}',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey700))
                        ])),
                pw.Expanded(
                    child: pw.Text('x${line.quantity}',
                        textAlign: pw.TextAlign.center)),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text('L ${line.total}',
                        textAlign: pw.TextAlign.right)),
              ]))),
      pw.SizedBox(height: 18),
      pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
              width: 220,
              child: pw.Column(children: [
                _totalRow('Subtotal', order.subtotal),
                _totalRow('Envío', order.shipping),
                pw.Divider(color: brandGreen, thickness: 1.2),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL',
                          style: const pw.TextStyle(
                              fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.Text('L ${order.total}',
                          style: const pw.TextStyle(
                              fontSize: 16, fontWeight: pw.FontWeight.bold))
                    ]),
              ]))),
      pw.Spacer(),
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 8),
      pw.Text('Método de pago: ${order.paymentMethod}',
          style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 4),
      pw.Text(
          'Este comprobante confirma el registro del pedido; no representa un recibo fiscal.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    ]),
  ));
  return Uint8List.fromList(await document.save());
}

pw.Widget _totalRow(String label, int amount) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Text(label), pw.Text('L $amount')]),
    );
