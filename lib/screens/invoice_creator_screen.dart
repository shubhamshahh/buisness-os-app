import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/company_provider.dart';
import '../services/supabase_service.dart';

class InvoiceCreatorScreen extends StatefulWidget {
  const InvoiceCreatorScreen({super.key});

  @override
  State<InvoiceCreatorScreen> createState() => _InvoiceCreatorScreenState();
}

class _InvoiceCreatorScreenState extends State<InvoiceCreatorScreen> with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  late TabController _tabController;
  
  // Tab 1: List
  List<Map<String, dynamic>> _invoices = [];
  bool _loadingList = false;

  // Tab 2: Create
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _products = [];
  bool _loadingForm = false;

  String? _selectedCustomerId;
  final _customerNameController = TextEditingController();
  
  // Billing Session mode
  bool _isGstInvoice = true;

  // Invoice items state
  final List<Map<String, dynamic>> _invoiceItems = []; // { product_id, product_name, price, qty, total }
  
  // Selector state for item addition
  Map<String, dynamic>? _selectedProduct;
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController();

  double get _subtotal {
    double sum = 0;
    for (var item in _invoiceItems) {
      sum += (item['price'] as double) * (item['qty'] as int);
    }
    return sum;
  }

  double get _gst => _isGstInvoice ? (_subtotal * 0.18) : 0.0;
  double get _total => _subtotal + _gst;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        _fetchInvoices();
      } else {
        _fetchFormData();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInvoices();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customerNameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _fetchInvoices() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loadingList = true;
    });

    try {
      final List<Map<String, dynamic>> data = await _supabaseService.getTableData(
        table: 'invoices',
        companyId: cid,
        orderBy: 'id',
        ascending: false,
      );
      setState(() {
        _invoices = data;
      });
    } catch (e) {
      debugPrint('Error fetching invoices: $e');
    } finally {
      setState(() {
        _loadingList = false;
      });
    }
  }

  Future<void> _fetchFormData() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loadingForm = true;
    });

    try {
      final custData = await _supabaseService.getTableData(
        table: 'customers',
        companyId: cid,
        eqColumn: 'deleted',
        eqValue: false,
        orderBy: 'name',
      );
      final prodData = await _supabaseService.getTableData(
        table: 'products',
        companyId: cid,
        eqColumn: 'deleted',
        eqValue: false,
        orderBy: 'name',
      );

      setState(() {
        _customers = custData;
        _products = prodData;
      });
    } catch (e) {
      debugPrint('Error fetching form data: $e');
    } finally {
      setState(() {
        _loadingForm = false;
      });
    }
  }

  void _addInvoiceItem() {
    if (_selectedProduct == null) return;
    final double price = double.tryParse(_priceController.text) ?? 0.0;
    final int qty = int.tryParse(_qtyController.text) ?? 1;
    if (price <= 0 || qty <= 0) return;

    setState(() {
      _invoiceItems.add({
        'product_id': _selectedProduct!['id'],
        'product_name': _selectedProduct!['name'],
        'price': price,
        'qty': qty,
        'total': price * qty,
      });

      _selectedProduct = null;
      _priceController.clear();
      _qtyController.clear();
    });
  }

  void _submitInvoice() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    if (_invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item to the invoice.')),
      );
      return;
    }

    setState(() {
      _loadingForm = true;
    });

    try {
      final String finalCustName = _customerNameController.text.trim().isNotEmpty
          ? _customerNameController.text.trim()
          : 'Walk-in Customer';

      // 1. Create Invoice
      final invoiceRow = {
        'company_id': cid,
        'customer_name': finalCustName,
        'customer_id': _selectedCustomerId,
        'subtotal': _subtotal,
        'gst': _gst,
        'total': _total,
        'status': 'Pending',
        'payment_mode': 'Cash',
      };

      final invoice = await _supabaseService.insert(table: 'invoices', row: invoiceRow);
      final invoiceId = invoice['id'];

      // 2. Insert Invoice Items
      final itemsRows = _invoiceItems.map((item) => {
        'invoice_id': invoiceId,
        'product_id': item['product_id'],
        'product_name': item['product_name'],
        'price': item['price'],
        'qty': item['qty'],
      }).toList();

      await _supabaseService.insertBatch(table: 'invoice_items', rows: itemsRows);

      // 3. Deduct Stock of Products
      for (var item in _invoiceItems) {
        final prodId = item['product_id'];
        final int qty = item['qty'];

        // Get current stock
        final prod = _products.firstWhere((p) => p['id'] == prodId);
        final int currentStock = (prod['stock'] as int?) ?? 0;
        await _supabaseService.update(
          table: 'products',
          id: prodId,
          values: {'stock': currentStock - qty},
        );
      }

      // Success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice created successfully!')),
      );

      // Clear Form & Switch to List
      setState(() {
        _customerNameController.clear();
        _selectedCustomerId = null;
        _invoiceItems.clear();
      });
      _tabController.animateTo(0);
    } catch (e) {
      debugPrint('Error creating invoice: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create invoice: $e')),
      );
    } finally {
      setState(() {
        _loadingForm = false;
      });
    }
  }

  void _showInvoiceDetails(Map<String, dynamic> invoice) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FutureBuilder<List<dynamic>>(
              future: _supabaseService.client.from('invoice_items').select().eq('invoice_id', invoice['id']),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                final double total = double.tryParse(invoice['total'].toString()) ?? 0.0;
                final bool isPaid = invoice['status'] == 'Paid';

                return DraggableScrollableSheet(
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
                            Text(
                              'Invoice #${invoice['id']}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Customer: ${invoice['customer_name']}',
                          style: const TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                        Text(
                          'Date: ${DateFormat('d MMM yyyy, hh:mm a').format(DateTime.parse(invoice['created_at']))}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const Divider(height: 24, color: Colors.grey),
                        Expanded(
                          child: snapshot.connectionState == ConnectionState.waiting
                              ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                              : items.isEmpty
                                  ? const Center(child: Text('No items in this invoice.'))
                                  : ListView.builder(
                                      controller: scrollController,
                                      itemCount: items.length,
                                      itemBuilder: (context, index) {
                                        final item = items[index];
                                        final double price = double.tryParse(item['price'].toString()) ?? 0.0;
                                        final int qty = item['qty'] as int;
                                        return ListTile(
                                          title: Text(item['product_name'] ?? '', style: const TextStyle(color: Colors.white)),
                                          subtitle: Text('$qty x ${_currencyFormat.format(price)}', style: const TextStyle(color: Colors.grey)),
                                          trailing: Text(_currencyFormat.format(price * qty), style: const TextStyle(color: Colors.white)),
                                        );
                                      },
                                    ),
                        ),
                        const Divider(color: Colors.grey),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              Text(_currencyFormat.format(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!isPaid)
                          ElevatedButton(
                            onPressed: () async {
                              await _supabaseService.update(table: 'invoices', id: invoice['id'], values: {'status': 'Paid'});
                              if (context.mounted) {
                                Navigator.pop(context);
                                _fetchInvoices();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Mark as Paid', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Text('PAID', textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Invoices Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2563EB),
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'History'),
            Tab(icon: Icon(Icons.add_box_outlined), text: 'Create Invoice'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: LIST VIEW
          _loadingList
              ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
              : _invoices.isEmpty
                  ? const Center(child: Text('No invoices recorded.'))
                  : ListView.builder(
                      itemCount: _invoices.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final inv = _invoices[index];
                        final double total = double.tryParse(inv['total'].toString()) ?? 0.0;
                        final bool isPaid = inv['status'] == 'Paid';

                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: ListTile(
                            onTap: () => _showInvoiceDetails(inv),
                            title: Text(inv['customer_name'] ?? 'Walk-in Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Invoice #${inv['id']} • ${inv['payment_mode'] ?? "Cash"}',
                              style: const TextStyle(fontSize: 12),
                            ),
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

          // TAB 2: CREATE INVOICE VIEW
          _loadingForm
              ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Billing Mode Segmented Buttons
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isGstInvoice = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _isGstInvoice ? const Color(0xFF2563EB) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '🏢 GST Bill (18%)',
                                      style: TextStyle(
                                        color: _isGstInvoice ? Colors.white : const Color(0xFF475569),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isGstInvoice = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !_isGstInvoice ? const Color(0xFF059669) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '📜 Non-GST (Cash)',
                                      style: TextStyle(
                                        color: !_isGstInvoice ? Colors.white : const Color(0xFF475569),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Customer Picker
                      const Text('1. Customer Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCustomerId,
                        hint: const Text('Select Registered Customer'),
                        decoration: const InputDecoration(fillColor: Colors.white, filled: true, border: OutlineInputBorder()),
                        items: _customers.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['id'].toString(),
                            child: Text(c['name']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCustomerId = val;
                            if (val != null) {
                              final match = _customers.firstWhere((c) => c['id'].toString() == val);
                              _customerNameController.text = match['name'];
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _customerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name (or Manual Input for Walk-in)',
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Add Item Panel
                      const Text('2. Add Line Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<Map<String, dynamic>>(
                                initialValue: _selectedProduct,
                                hint: const Text('Choose Product'),
                                decoration: const InputDecoration(border: OutlineInputBorder()),
                                items: _products.map((p) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: p,
                                    child: Text(p['name']),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedProduct = val;
                                    if (val != null) {
                                      _priceController.text = val['selling']?.toString() ?? '0';
                                      _qtyController.text = '1';
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _priceController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder()),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _qtyController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _addInvoiceItem,
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                                child: const Text('Add to List', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Items Table List
                      const Text('Line Items List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 6),
                      if (_invoiceItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(child: Text('No items added yet.', style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _invoiceItems.length,
                          itemBuilder: (context, index) {
                            final item = _invoiceItems[index];
                            return Card(
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(item['product_name']),
                                subtitle: Text('${item['qty']} x ${_currencyFormat.format(item['price'])}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_currencyFormat.format(item['total']), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                      onPressed: () {
                                        setState(() {
                                          _invoiceItems.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 20),

                      // Math calculations
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:'),
                          Text(_currencyFormat.format(_subtotal)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('GST (18%):'),
                          Text(_currencyFormat.format(_gst)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(_currencyFormat.format(_total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Submit
                      ElevatedButton(
                        onPressed: _submitInvoice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Complete & Save Invoice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
