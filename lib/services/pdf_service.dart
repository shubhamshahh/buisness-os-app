import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  static Future<Uint8List> generateInvoicePdf({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> business,
    Map<String, dynamic>? customer,
  }) async {
    final pdf = pw.Document();

    final bool isGstInvoice = (double.tryParse(invoice['gst']?.toString() ?? '0') ?? 0.0) > 0;
    final String invoiceLabel = invoice['invoice_no']?.toString() ??
        'INV-${invoice['id'].toString().padLeft(3, '0')}';
    final String docTypeTitle = isGstInvoice ? "TAX INVOICE" : "ESTIMATE / BILL";

    final String bizName = business['name']?.toString() ?? 'Mk Polymers';
    final String bizAddr = business['address']?.toString() ??
        'c/168, Mk Polymers, New Post Office Road, Modhera GIDC, Mahesana - 384002';
    final String bizGst = business['gst']?.toString() ?? 'kkbk00020551584';
    final String signatory = business['signatory']?.toString() ?? 'M.A. SHAH';

    final String custName = customer?['name']?.toString() ??
        invoice['customer_name']?.toString() ??
        'Walk-in Customer';
    final String custAddr = customer?['address']?.toString() ?? '';
    final String custPhone = customer?['mobile']?.toString() ?? customer?['phone']?.toString() ?? '';
    final String custGst = customer?['gst_number']?.toString() ?? '';

    // Load logo watermark bytes (company logo if available, else assets/logo.png)
    pw.ImageProvider? logoImage;
    try {
      final logoUrl = business['logo_url']?.toString() ?? business['logo']?.toString() ?? '';
      if (logoUrl.startsWith('http')) {
        logoImage = await networkImage(logoUrl);
      } else {
        final ByteData logoData = await rootBundle.load('assets/logo.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      }
    } catch (_) {
      try {
        final ByteData logoData = await rootBundle.load('assets/logo.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // 1. Watermark Logo
              if (logoImage != null)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.06,
                      child: pw.Image(logoImage, width: 280, height: 280),
                    ),
                  ),
                ),

              // Main Document Content
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // 2. Header Row
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left: Business Info
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            bizName,
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF0F172A),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            width: 240,
                            child: pw.Text(
                              bizAddr,
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColor.fromInt(0xFF475569),
                              ),
                            ),
                          ),
                          if (isGstInvoice && bizGst.isNotEmpty) ...[
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'GSTIN: $bizGst',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF2563EB),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Right: Meta Box
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            docTypeTitle,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF0F172A),
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            invoiceLabel,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF2563EB),
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Date: ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(invoice['created_at']?.toString() ?? '') ?? DateTime.now())}',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColor.fromInt(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 12),
                  pw.Divider(color: const PdfColor.fromInt(0xFFE2E8F0), thickness: 1),
                  pw.SizedBox(height: 10),

                  // 3. Billed To Card
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFF8FAFC),
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BILLED TO:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF475569),
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          custName,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF0F172A),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          [
                            if (custAddr.isNotEmpty) custAddr,
                            if (custPhone.isNotEmpty) 'Phone: $custPhone',
                            if (isGstInvoice && custGst.isNotEmpty) 'GSTIN: $custGst',
                          ].join('  |  ').ifEmpty('Cash Customer'),
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColor.fromInt(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 16),

                  // 4. Products Table
                  pw.TableHelper.fromTextArray(
                    border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
                    headerStyle: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF0F172A),
                    ),
                    rowDecoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFFFFFF),
                    ),
                    cellStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF1E293B)),
                    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    headers: ['#', 'Product Description', 'Qty', 'Price', 'Total Amount'],
                    data: items.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final item = entry.value;
                      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                      final qty = int.tryParse(item['qty']?.toString() ?? '0') ?? 0;
                      final total = double.tryParse(item['total']?.toString() ?? '') ?? (price * qty);

                      return [
                        '$idx',
                        item['product_name']?.toString() ?? 'Item',
                        '$qty',
                        _currencyFormat.format(price),
                        _currencyFormat.format(total),
                      ];
                    }).toList(),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(25),
                      1: const pw.FlexColumnWidth(3),
                      2: const pw.FixedColumnWidth(40),
                      3: const pw.FixedColumnWidth(70),
                      4: const pw.FixedColumnWidth(80),
                    },
                  ),

                  pw.SizedBox(height: 14),

                  // 5. Totals & Signature Section
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left Notes
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Payment Terms: Immediate / Cash',
                            style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF64748B)),
                          ),
                        ],
                      ),

                      // Right Summary Card
                      pw.Container(
                        width: 210,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            _buildSummaryRow('Subtotal:', _currencyFormat.format(double.tryParse(invoice['subtotal']?.toString() ?? '0') ?? 0.0)),
                            if (isGstInvoice) ...[
                              pw.SizedBox(height: 4),
                              _buildSummaryRow('CGST (9%):', _currencyFormat.format((double.tryParse(invoice['gst']?.toString() ?? '0') ?? 0.0) / 2)),
                              pw.SizedBox(height: 4),
                              _buildSummaryRow('SGST (9%):', _currencyFormat.format((double.tryParse(invoice['gst']?.toString() ?? '0') ?? 0.0) / 2)),
                            ],
                            pw.SizedBox(height: 6),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: pw.BoxDecoration(
                                color: const PdfColor.fromInt(0xFF0F172A),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    'Grand Total:',
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                                  ),
                                  pw.Text(
                                    _currencyFormat.format(double.tryParse(invoice['total']?.toString() ?? '0') ?? 0.0),
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.Spacer(),

                  // 6. Signature Block
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'For $bizName',
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A)),
                          ),
                          pw.SizedBox(height: 24),
                          pw.Container(
                            width: 140,
                            height: 0.8,
                            color: const PdfColor.fromInt(0xFFCBD5E1),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            signatory,
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A)),
                          ),
                          pw.Text(
                            'Authorized Signatory',
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 12),
                  pw.Divider(color: const PdfColor.fromInt(0xFFF1F5F9)),
                  pw.SizedBox(height: 4),

                  // 7. Footer
                  pw.Center(
                    child: pw.Text(
                      'Thank you for your business!  •  This is a computer generated document.',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF475569))),
        pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A))),
      ],
    );
  }

  static Future<void> shareOrPrintInvoice({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> business,
    Map<String, dynamic>? customer,
  }) async {
    final pdfBytes = await generateInvoicePdf(
      invoice: invoice,
      items: items,
      business: business,
      customer: customer,
    );

    final String label = invoice['invoice_no']?.toString() ?? 'INV-${invoice['id']}';
    await Printing.sharePdf(bytes: pdfBytes, filename: '$label.pdf');
  }
}

extension _StringExt on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}