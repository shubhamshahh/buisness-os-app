import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/company_provider.dart';
import '../services/supabase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  bool _loadingData = false;
  double _revenue = 0;
  double _profit = 0;
  int _orders = 0;
  int _lowStockCount = 0;
  double _yesterdayRevenue = 0;

  List<Map<String, dynamic>> _todayInvoices = [];
  List<Map<String, dynamic>> _lowStockProducts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboard();
    });
  }

  Future<void> _loadDashboard() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final int? cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loadingData = true;
    });

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc().toIso8601String();

      // 1. Fetch Today's Invoices
      final invoices = await _supabaseService.client
          .from('invoices')
          .select()
          .eq('company_id', cid)
          .gte('created_at', todayStart)
          .lte('created_at', todayEnd);

      final List<Map<String, dynamic>> invoicesList = List<Map<String, dynamic>>.from(invoices);
      
      double todayRevenue = 0;
      for (var inv in invoicesList) {
        todayRevenue += double.tryParse(inv['total'].toString()) ?? 0.0;
      }

      // 2. Fetch Low Stock Items
      final lowStock = await _supabaseService.client
          .from('products')
          .select()
          .eq('company_id', cid)
          .eq('deleted', false)
          .lt('stock', 50);
      final List<Map<String, dynamic>> lowStockList = List<Map<String, dynamic>>.from(lowStock);

      // 3. Fetch Yesterday's Revenue
      final yesterday = now.subtract(const Duration(days: 1));
      final yStart = DateTime(yesterday.year, yesterday.month, yesterday.day).toUtc().toIso8601String();
      final yEnd = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59, 999).toUtc().toIso8601String();

      final yesterdayInvoices = await _supabaseService.client
          .from('invoices')
          .select('total')
          .eq('company_id', cid)
          .gte('created_at', yStart)
          .lte('created_at', yEnd);

      double yRevenue = 0;
      for (var inv in yesterdayInvoices) {
        yRevenue += double.tryParse(inv['total'].toString()) ?? 0.0;
      }

      // 4. Calculate profits (requires cost data)
      double totalProfit = 0;
      if (invoicesList.isNotEmpty) {
        final invoiceIds = invoicesList.map((inv) => inv['id']).toList();
        final items = await _supabaseService.client
            .from('invoice_items')
            .select('invoice_id, product_id, qty, price')
            .filter('invoice_id', 'in', invoiceIds);

        final List<Map<String, dynamic>> itemsList = List<Map<String, dynamic>>.from(items);
        if (itemsList.isNotEmpty) {
          final productIds = itemsList.map((i) => i['product_id']).toSet().toList();
          final products = await _supabaseService.client
              .from('products')
              .select('id, cost')
              .filter('id', 'in', productIds)
              .eq('company_id', cid);

          final List<Map<String, dynamic>> productsList = List<Map<String, dynamic>>.from(products);
          final costMap = {for (var p in productsList) p['id']: double.tryParse(p['cost'].toString()) ?? 0.0};

          for (var item in itemsList) {
            final double cost = costMap[item['product_id']] ?? 0.0;
            final double price = double.tryParse(item['price'].toString()) ?? 0.0;
            final int qty = int.tryParse(item['qty'].toString()) ?? 0;
            totalProfit += (price - cost) * qty;
          }
        }
      }

      setState(() {
        _revenue = todayRevenue;
        _profit = totalProfit;
        _orders = invoicesList.length;
        _lowStockCount = lowStockList.length;
        _todayInvoices = invoicesList;
        _lowStockProducts = lowStockList;
        _yesterdayRevenue = yRevenue;
      });
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    } finally {
      setState(() {
        _loadingData = false;
      });
    }
  }

  void _showRevenueBreakdown() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Today\'s Invoices',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _todayInvoices.isEmpty
                    ? const Center(
                        child: Text(
                          'No invoices recorded today.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _todayInvoices.length,
                        itemBuilder: (context, index) {
                          final inv = _todayInvoices[index];
                          final double total = double.tryParse(inv['total'].toString()) ?? 0.0;
                          return Card(
                            color: const Color(0xFF1E293B),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              title: Text(
                                inv['customer_name'] ?? 'Walk-in Customer',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              subtitle: Text(
                                'Status: ${inv['status']} • Payment: ${inv['payment_mode'] ?? 'Cash'}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              trailing: Text(
                                _currencyFormat.format(total),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLowStock() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Low Stock Items',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _lowStockProducts.isEmpty
                    ? const Center(
                        child: Text(
                          'All items have healthy stock levels.',
                          style: TextStyle(color: Colors.greenAccent),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _lowStockProducts.length,
                        itemBuilder: (context, index) {
                          final prod = _lowStockProducts[index];
                          return Card(
                            color: const Color(0xFF1E293B),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF451A03),
                                child: Icon(Icons.warning_amber_rounded, color: Colors.amber),
                              ),
                              title: Text(
                                prod['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              subtitle: Text(
                                'Stock Left: ${prod['stock']} units',
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                              ),
                              trailing: Text(
                                'Selling: ${_currencyFormat.format(prod['selling'])}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyProvider = Provider.of<CompanyProvider>(context);
    final formattedDate = DateFormat('EEE, d MMM yyyy').format(DateTime.now());

    if (companyProvider.isLoading || _loadingData) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    String pulseRevenueText = '';
    if (_revenue > _yesterdayRevenue) {
      pulseRevenueText = 'Today\'s revenue (${_currencyFormat.format(_revenue)}) is higher than yesterday (${_currencyFormat.format(_yesterdayRevenue)}).';
    } else if (_revenue < _yesterdayRevenue) {
      pulseRevenueText = 'Today\'s revenue (${_currencyFormat.format(_revenue)}) is lower than yesterday (${_currencyFormat.format(_yesterdayRevenue)}).';
    } else {
      pulseRevenueText = 'Today\'s revenue matches yesterday\'s (${_currencyFormat.format(_revenue)}).';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate-50 background for content
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            companyProvider.companyName.isNotEmpty ? companyProvider.companyName : 'Mk Polymers',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Cloud Sync Active',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('hh:mm a').format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // KPI Cards Grid
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.25,
                children: [
                  _buildMetricCard(
                    title: 'Today\'s Revenue',
                    value: _currencyFormat.format(_revenue),
                    icon: Icons.currency_rupee,
                    color: Colors.blue,
                    onTap: _showRevenueBreakdown,
                  ),
                  _buildMetricCard(
                    title: 'Today\'s Profit',
                    value: _currencyFormat.format(_profit),
                    icon: Icons.trending_up,
                    color: Colors.green,
                    onTap: _showRevenueBreakdown, // Reuse breakdown
                  ),
                  _buildMetricCard(
                    title: 'Orders',
                    value: '$_orders',
                    icon: Icons.shopping_bag_outlined,
                    color: Colors.purple,
                    onTap: _showRevenueBreakdown,
                  ),
                  _buildMetricCard(
                    title: 'Low Stock',
                    value: '$_lowStockCount',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red,
                    onTap: _showLowStock,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Business Pulse
              const Text(
                'Business Pulse',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.insights, color: Colors.blueAccent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Revenue Trend',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pulseRevenueText,
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: Colors.amber),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Inventory Health',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _lowStockCount > 0
                                      ? '$_lowStockCount product${_lowStockCount > 1 ? "s are" : " is"} running low on stock.'
                                      : 'All products have healthy stock levels.',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color == Colors.red ? Colors.redAccent : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Details →',
                    style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
