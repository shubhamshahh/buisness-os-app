import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../providers/company_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  bool _loading = false;

  double _totalRevenue = 0.0;
  double _totalGST = 0.0;
  int _totalInvoicesCount = 0;

  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _customerLeaderboard = [];

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loading = true;
    });

    try {
      // 1. Fetch Invoices
      final invoices = await _supabaseService.client
          .from('invoices')
          .select('id, subtotal, gst, total, customer_name, customer_id')
          .eq('company_id', cid);

      final List<Map<String, dynamic>> invoicesList = List<Map<String, dynamic>>.from(invoices);

      double revenue = 0.0;
      double gstVal = 0.0;
      
      for (var inv in invoicesList) {
        revenue += double.tryParse(inv['total'].toString()) ?? 0.0;
        gstVal += double.tryParse(inv['gst'].toString()) ?? 0.0;
      }

      // 2. Fetch Invoice Items for Top Products
      List<Map<String, dynamic>> sortedProducts = [];
      if (invoicesList.isNotEmpty) {
        final invoiceIds = invoicesList.map((inv) => inv['id']).toList();
        final items = await _supabaseService.client
            .from('invoice_items')
            .select('product_name, qty, price')
            .filter('invoice_id', 'in', invoiceIds);

        final List<Map<String, dynamic>> itemsList = List<Map<String, dynamic>>.from(items);

        final Map<String, Map<String, dynamic>> productMap = {};
        for (var item in itemsList) {
          final String name = item['product_name'] ?? 'Unknown Product';
          final int qty = int.tryParse(item['qty'].toString()) ?? 0;
          final double price = double.tryParse(item['price'].toString()) ?? 0.0;
          final double totalItemVal = qty * price;

          if (productMap.containsKey(name)) {
            productMap[name]!['qty'] = (productMap[name]!['qty'] as int) + qty;
            productMap[name]!['revenue'] = (productMap[name]!['revenue'] as double) + totalItemVal;
          } else {
            productMap[name] = {
              'name': name,
              'qty': qty,
              'revenue': totalItemVal,
            };
          }
        }

        sortedProducts = productMap.values.toList();
        sortedProducts.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      }

      // 3. Customer Leaderboard
      final Map<String, double> customerSpentMap = {};
      for (var inv in invoicesList) {
        final name = inv['customer_name'] ?? 'Walk-in Customer';
        final total = double.tryParse(inv['total'].toString()) ?? 0.0;
        customerSpentMap[name] = (customerSpentMap[name] ?? 0.0) + total;
      }

      final leaderboard = customerSpentMap.entries.map((e) => {
        'name': e.key,
        'spent': e.value,
      }).toList();
      leaderboard.sort((a, b) => (b['spent'] as double).compareTo(a['spent'] as double));

      setState(() {
        _totalRevenue = revenue;
        _totalGST = gstVal;
        _totalInvoicesCount = invoicesList.length;
        _topProducts = sortedProducts.take(10).toList();
        _customerLeaderboard = leaderboard.take(10).toList();
      });
    } catch (e) {
      debugPrint('Error generating report data: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          bottom: const TabBar(
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blueAccent,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Products'),
              Tab(text: 'Customers'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            : TabBarView(
                children: [
                  _buildOverviewTab(),
                  _buildProductsTab(),
                  _buildCustomersTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOTAL PLATFORM REVENUE', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_currencyFormat.format(_totalRevenue), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const Divider(height: 24, color: Colors.grey),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('GST Collected', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(_currencyFormat.format(_totalGST), style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Invoices Count', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text('$_totalInvoicesCount bills', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTab() {
    return _topProducts.isEmpty
        ? const Center(child: Text('No product sales records found.'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _topProducts.length,
            itemBuilder: (context, index) {
              final prod = _topProducts[index];
              final double revenue = prod['revenue'] as double;
              final int qty = prod['qty'] as int;

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
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                    child: Text('${index + 1}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(prod['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Quantity Sold: $qty units'),
                  trailing: Text(_currencyFormat.format(revenue), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              );
            },
          );
  }

  Widget _buildCustomersTab() {
    return _customerLeaderboard.isEmpty
        ? const Center(child: Text('No customer invoices found.'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _customerLeaderboard.length,
            itemBuilder: (context, index) {
              final cust = _customerLeaderboard[index];
              final double spent = cust['spent'] as double;

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
                    backgroundColor: Colors.purpleAccent.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: Colors.purpleAccent),
                  ),
                  title: Text(cust['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Top Customer Account'),
                  trailing: Text(_currencyFormat.format(spent), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ),
              );
            },
          );
  }
}
