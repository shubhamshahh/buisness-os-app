import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../providers/company_provider.dart';

class QuotationsScreen extends StatefulWidget {
  const QuotationsScreen({super.key});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  bool _loading = false;
  List<Map<String, dynamic>> _quotations = [];
  List<Map<String, dynamic>> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final quots = await _supabaseService.client
          .from('quotations')
          .select('*, customers(name)')
          .eq('company_id', cid)
          .order('created_at', ascending: false);

      final custs = await _supabaseService.getTableData(
        table: 'customers',
        companyId: cid,
        eqColumn: 'deleted',
        eqValue: false,
      );

      setState(() {
        _quotations = List<Map<String, dynamic>>.from(quots);
        _customers = custs;
      });
    } catch (e) {
      debugPrint('Error loading quotations data: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _addQuotation() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    int? selectedCustomerId;
    final totalController = TextEditingController();

    if (_customers.isNotEmpty) {
      selectedCustomerId = _customers.first['id'] as int;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Draft Quotation',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_customers.isEmpty)
                const Text(
                  'No customers found. Please add a customer first.',
                  style: TextStyle(color: Colors.redAccent),
                )
              else
                DropdownButtonFormField<int>(
                  dropdownColor: const Color(0xFF1E293B),
                  initialValue: selectedCustomerId,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Select Customer',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  items: _customers.map((c) {
                    return DropdownMenuItem<int>(
                      value: c['id'] as int,
                      child: Text(c['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        selectedCustomerId = val;
                      });
                    }
                  },
                ),
              const SizedBox(height: 12),
              TextField(
                controller: totalController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Subtotal Amount (₹)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final double? subtotalVal = double.tryParse(totalController.text);
                  if (selectedCustomerId != null && subtotalVal != null) {
                    final gstVal = subtotalVal * 0.18;
                    final totalVal = subtotalVal + gstVal;

                    await _supabaseService.insert(
                      table: 'quotations',
                      row: {
                        'company_id': cid,
                        'customer_id': selectedCustomerId,
                        'subtotal': subtotalVal,
                        'gst': gstVal,
                        'total': totalVal,
                        'status': 'Pending',
                      },
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadData();
                    }
                  }
                },
                child: const Text('Save Quotation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _convertToInvoice(Map<String, dynamic> quotation) async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final customerName = quotation['customers'] != null
          ? quotation['customers']['name']
          : 'Walk-in Customer';

      // 1. Create Invoice
      final newInvoiceList = await _supabaseService.client.from('invoices').insert({
        'company_id': cid,
        'customer_name': customerName,
        'customer_id': quotation['customer_id'],
        'subtotal': quotation['subtotal'],
        'gst': quotation['gst'],
        'total': quotation['total'],
        'status': 'Pending',
        'payment_mode': 'Cash',
      }).select('id');

      if (newInvoiceList.isNotEmpty) {
        final invoiceId = newInvoiceList.first['id'];

        // 2. Add sample/placeholder invoice item
        await _supabaseService.client.from('invoice_items').insert({
          'invoice_id': invoiceId,
          'product_name': 'Quotation #${quotation['id']} Service Block',
          'price': quotation['subtotal'],
          'qty': 1,
        });

        // 3. Update Quotation Status
        await _supabaseService.update(
          table: 'quotations',
          id: quotation['id'],
          values: {'status': 'Converted'},
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quotation converted to Invoice successfully!')),
          );
        }
      }
      _loadData();
    } catch (e) {
      debugPrint('Error converting quotation: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Quotations', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _quotations.isEmpty
              ? const Center(child: Text('No quotations found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _quotations.length,
                  itemBuilder: (context, index) {
                    final quotation = _quotations[index];
                    final double total = double.tryParse(quotation['total'].toString()) ?? 0.0;
                    final customerName = quotation['customers'] != null
                        ? quotation['customers']['name']
                        : 'Walk-in Customer';
                    final dateStr = quotation['created_at'] != null
                        ? DateFormat('d MMM yyyy').format(DateTime.parse(quotation['created_at']))
                        : '';
                    final status = quotation['status'] ?? 'Pending';

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('Quotation #${quotation['id']} • $dateStr', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: status == 'Converted' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: status == 'Converted' ? Colors.green : Colors.orange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_currencyFormat.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 12),
                                if (status == 'Pending')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => _convertToInvoice(quotation),
                                    child: const Text('Convert to Invoice', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addQuotation,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
