import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../providers/company_provider.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  bool _loading = false;

  double _totalRevenue = 0.0;
  double _todayRevenue = 0.0;
  double _monthRevenue = 0.0;
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _fetchSales();
  }

  Future<void> _fetchSales() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final data = await _supabaseService.getTableData(
        table: 'invoices',
        companyId: cid,
        orderBy: 'created_at',
        ascending: false,
      );

      final List<Map<String, dynamic>> invoicesList = List<Map<String, dynamic>>.from(data);
      
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final monthStr = DateFormat('yyyy-MM').format(now);

      double total = 0.0;
      double today = 0.0;
      double month = 0.0;

      for (var inv in invoicesList) {
        final double amount = double.tryParse(inv['total'].toString()) ?? 0.0;
        total += amount;

        if (inv['created_at'] != null) {
          final date = DateTime.parse(inv['created_at']);
          final dateFormatted = DateFormat('yyyy-MM-dd').format(date);
          final monthFormatted = DateFormat('yyyy-MM').format(date);

          if (dateFormatted == todayStr) {
            today += amount;
          }
          if (monthFormatted == monthStr) {
            month += amount;
          }
        }
      }

      setState(() {
        _invoices = invoicesList;
        _totalRevenue = total;
        _todayRevenue = today;
        _monthRevenue = month;
      });
    } catch (e) {
      debugPrint('Error fetching sales data: $e');
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
        title: const Text('Sales Overview', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSales,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : Column(
              children: [
                // Metrics grid
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF0F172A),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricBlock(
                              title: 'TODAY',
                              amount: _todayRevenue,
                              color: Colors.greenAccent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildMetricBlock(
                              title: 'THIS MONTH',
                              amount: _monthRevenue,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMetricBlock(
                        title: 'TOTAL REVENUE',
                        amount: _totalRevenue,
                        color: Colors.white,
                        isLarge: true,
                      ),
                    ],
                  ),
                ),
                // Invoices list
                Expanded(
                  child: _invoices.isEmpty
                      ? const Center(child: Text('No sales records found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _invoices.length,
                          itemBuilder: (context, index) {
                            final inv = _invoices[index];
                            final double total = double.tryParse(inv['total'].toString()) ?? 0.0;
                            final dateStr = inv['created_at'] != null
                                ? DateFormat('d MMM yyyy, hh:mm a').format(DateTime.parse(inv['created_at']))
                                : '';
                            final isPaid = inv['status'] == 'Paid';

                            return Card(
                              color: Colors.white,
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              child: ListTile(
                                title: Text(inv['customer_name'] ?? 'Walk-in Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Date: $dateStr'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_currencyFormat.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        inv['status'] ?? 'Pending',
                                        style: TextStyle(
                                          color: isPaid ? const Color(0xFF166534) : const Color(0xFF92400E),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
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

  Widget _buildMetricBlock({
    required String title,
    required double amount,
    required Color color,
    bool isLarge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            _currencyFormat.format(amount),
            style: TextStyle(
              color: color,
              fontSize: isLarge ? 22 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
