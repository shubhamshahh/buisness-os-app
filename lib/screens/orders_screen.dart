import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../providers/company_provider.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  bool _loading = false;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final data = await _supabaseService.getTableData(
        table: 'orders',
        companyId: cid,
        orderBy: 'created_at',
        ascending: false,
      );
      setState(() {
        _orders = data;
      });
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _addOrder() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final cityController = TextEditingController();
    final totalController = TextEditingController();
    String status = 'Pending';

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
              'Create New Order',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Customer Phone',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cityController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'City',
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
                labelText: 'Total Amount (₹)',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF1E293B),
              initialValue: status,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Status',
                labelStyle: TextStyle(color: Colors.grey),
              ),
              items: const [
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(value: 'Shipped', child: Text('Shipped')),
                DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
              ],
              onChanged: (val) {
                if (val != null) status = val;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final double? totalVal = double.tryParse(totalController.text);
                if (nameController.text.isNotEmpty && totalVal != null) {
                  await _supabaseService.insert(
                    table: 'orders',
                    row: {
                      'company_id': cid,
                      'customer_name': nameController.text,
                      'customer_phone': phoneController.text,
                      'city': cityController.text,
                      'total': totalVal,
                      'status': status,
                    },
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    _fetchOrders();
                  }
                }
              },
              child: const Text('Save Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(int id, String currentStatus) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: ['Pending', 'Shipped', 'Delivered'].map((status) {
          return ListTile(
            title: Text(status, style: const TextStyle(color: Colors.white)),
            trailing: currentStatus == status ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () async {
              await _supabaseService.update(
                table: 'orders',
                id: id,
                values: {'status': status},
              );
              if (context.mounted) {
                Navigator.pop(context);
                _fetchOrders();
              }
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Orders', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrders,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _orders.isEmpty
              ? const Center(child: Text('No orders found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    final double total = double.tryParse(order['total'].toString()) ?? 0.0;
                    final dateStr = order['created_at'] != null
                        ? DateFormat('d MMM yyyy').format(DateTime.parse(order['created_at']))
                        : '';
                    final status = order['status'] ?? 'Pending';
                    
                    Color statusColor = Colors.orange;
                    if (status == 'Shipped') statusColor = Colors.blue;
                    if (status == 'Delivered') statusColor = Colors.green;

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        title: Text(order['customer_name'] ?? 'Walk-in Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Date: $dateStr'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_currencyFormat.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _updateStatus(order['id'], status),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      status,
                                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(Icons.arrow_drop_down, color: statusColor, size: 12),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addOrder,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
