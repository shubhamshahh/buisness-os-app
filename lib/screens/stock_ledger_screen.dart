import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/company_provider.dart';
import '../services/supabase_service.dart';

class StockLedgerScreen extends StatefulWidget {
  const StockLedgerScreen({super.key});

  @override
  State<StockLedgerScreen> createState() => _StockLedgerScreenState();
}

class _StockLedgerScreenState extends State<StockLedgerScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;

  List<Map<String, dynamic>> _ledgerEntries = [];
  List<Map<String, dynamic>> _products = [];
  String? _selectedProductId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLedgerAndProducts();
    });
  }

  Future<void> _loadLedgerAndProducts() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loading = true;
    });

    try {
      // 1. Fetch Products for filtering
      final prods = await _supabaseService.client
          .from('products')
          .select('id, name')
          .eq('company_id', cid)
          .eq('deleted', false);
      
      // 2. Fetch Ledger Entries
      await _fetchLedgerEntries(cid);

      setState(() {
        _products = List<Map<String, dynamic>>.from(prods);
      });
    } catch (e) {
      debugPrint('Error loading stock ledger: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchLedgerEntries(int cid) async {
    dynamic query = _supabaseService.client
        .from('stock_ledger')
        .select('*, products(name)')
        .eq('company_id', cid);

    if (_selectedProductId != null) {
      query = query.eq('product_id', int.parse(_selectedProductId!));
    }

    final data = await query.order('created_at', ascending: false);
    setState(() {
      _ledgerEntries = List<Map<String, dynamic>>.from(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final companyProvider = Provider.of<CompanyProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Stock Ledger Audit', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Panel
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedProductId,
              hint: const Text('Filter by Product (All)'),
              decoration: const InputDecoration(fillColor: Colors.white, filled: true, border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Products'),
                ),
                ..._products.map((p) {
                  return DropdownMenuItem<String>(
                    value: p['id'].toString(),
                    child: Text(p['name']),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedProductId = val;
                });
                if (companyProvider.companyId != null) {
                  _fetchLedgerEntries(companyProvider.companyId!);
                }
              },
            ),
          ),

          // Ledger Entries
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _ledgerEntries.isEmpty
                    ? const Center(child: Text('No stock movement entries recorded.'))
                    : ListView.builder(
                        itemCount: _ledgerEntries.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemBuilder: (context, index) {
                          final entry = _ledgerEntries[index];
                          final int qty = entry['qty'] as int;
                          final String type = (entry['type'] as String?) ?? 'adjustment';
                          final productsObj = entry['products'];
                          final String productName = productsObj != null ? (productsObj['name'] ?? 'Unknown Product') : 'Unknown Product';
                          final dateStr = entry['created_at'] != null
                              ? DateFormat('d MMM yyyy, hh:mm a').format(DateTime.parse(entry['created_at']))
                              : '';

                          IconData icon;
                          Color color;
                          String prefixText = '';

                          if (type == 'sale') {
                            icon = Icons.shopping_bag_outlined;
                            color = Colors.red;
                            prefixText = '-';
                          } else if (type == 'purchase') {
                            icon = Icons.add_circle_outline;
                            color = Colors.green;
                            prefixText = '+';
                          } else {
                            icon = Icons.tune;
                            color = Colors.blue;
                            prefixText = qty >= 0 ? '+' : '';
                          }

                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.1),
                                child: Icon(icon, color: color),
                              ),
                              title: Text(
                                productName,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              subtitle: Text(
                                'Type: ${type.toUpperCase()}\n$dateStr',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              isThreeLine: true,
                              trailing: Text(
                                '$prefixText$qty units',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: color,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
