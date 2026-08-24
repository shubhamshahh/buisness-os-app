import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../providers/company_provider.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  bool _loading = false;
  List<Map<String, dynamic>> _purchases = [];

  @override
  void initState() {
    super.initState();
    _fetchPurchases();
  }

  Future<void> _fetchPurchases() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final data = await _supabaseService.getTableData(
        table: 'purchases',
        companyId: cid,
        orderBy: 'created_at',
        ascending: false,
      );
      setState(() {
        _purchases = data;
      });
    } catch (e) {
      debugPrint('Error fetching purchases: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _addPurchase() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    final supplierController = TextEditingController();
    final totalController = TextEditingController();
    final billNoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      builder: (context) => Padding(
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
              'Add Purchase Bill',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: billNoController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Purchase / Invoice Number',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: supplierController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Supplier Name',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: totalController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Total Bill Amount (₹)',
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
                final double? totalVal = double.tryParse(totalController.text);
                if (supplierController.text.isNotEmpty && totalVal != null) {
                  final double subtotal = totalVal / 1.18;
                  final double gst = totalVal - subtotal;

                  await _supabaseService.insert(
                    table: 'purchases',
                    row: {
                      'company_id': cid,
                      'purchase_no': billNoController.text.isNotEmpty ? billNoController.text : 'PUR-${DateTime.now().millisecondsSinceEpoch}',
                      'supplier_name': supplierController.text,
                      'subtotal': subtotal,
                      'gst': gst,
                      'total': totalVal,
                      'status': 'Received',
                    },
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    _fetchPurchases();
                  }
                }
              },
              child: const Text('Save Purchase', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Purchases', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPurchases,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _purchases.isEmpty
              ? const Center(child: Text('No purchases found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _purchases.length,
                  itemBuilder: (context, index) {
                    final purchase = _purchases[index];
                    final double total = double.tryParse(purchase['total'].toString()) ?? 0.0;
                    final dateStr = purchase['created_at'] != null
                        ? DateFormat('d MMM yyyy').format(DateTime.parse(purchase['created_at']))
                        : '';
                    final status = purchase['status'] ?? 'Received';

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEFF6FF),
                          child: Icon(Icons.shopping_cart, color: Colors.blue),
                        ),
                        title: Text(purchase['supplier_name'] ?? 'Supplier', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Bill: ${purchase['purchase_no']} • $dateStr'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_currencyFormat.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(color: Colors.teal, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPurchase,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
