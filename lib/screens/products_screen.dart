import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/company_provider.dart';
import '../services/supabase_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  List<Map<String, dynamic>> _products = [];
  String _searchQuery = '';
  bool _loading = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _stockController = TextEditingController();
  final _costController = TextEditingController();
  final _sellingController = TextEditingController();
  int? _editingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProducts();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _costController.dispose();
    _sellingController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final List<Map<String, dynamic>> data = await _supabaseService.getTableData(
        table: 'products',
        companyId: cid,
        eqColumn: 'deleted',
        eqValue: false,
        orderBy: 'name',
      );
      setState(() {
        _products = data;
      });
    } catch (e) {
      debugPrint('Error fetching products: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _openProductForm([Map<String, dynamic>? product]) {
    if (product != null) {
      _editingId = product['id'] as int?;
      _nameController.text = product['name'] ?? '';
      _stockController.text = product['stock']?.toString() ?? '0';
      _costController.text = product['cost']?.toString() ?? '0';
      _sellingController.text = product['selling']?.toString() ?? '0';
    } else {
      _editingId = null;
      _nameController.clear();
      _stockController.text = '0';
      _costController.text = '0';
      _sellingController.text = '0';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          _editingId == null ? 'Add New Product' : 'Edit Product',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  validator: (val) => val!.isEmpty ? 'Name is required' : null,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  validator: (val) => val!.isEmpty ? 'Stock is required' : null,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Stock Qty',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) => val!.isEmpty ? 'Cost price is required' : null,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Cost Price (₹)',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sellingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) => val!.isEmpty ? 'Selling price is required' : null,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Selling Price (₹)',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _saveProduct,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    Navigator.pop(context); // Close Dialog
    setState(() {
      _loading = true;
    });

    final row = {
      'name': _nameController.text.trim(),
      'stock': int.tryParse(_stockController.text) ?? 0,
      'cost': double.tryParse(_costController.text) ?? 0.0,
      'selling': double.tryParse(_sellingController.text) ?? 0.0,
      'company_id': cid,
      'deleted': false,
    };

    try {
      if (_editingId == null) {
        await _supabaseService.insert(table: 'products', row: row);
      } else {
        await _supabaseService.update(table: 'products', id: _editingId, values: row);
      }
      await _fetchProducts();
    } catch (e) {
      debugPrint('Error saving product: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _deleteProduct(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Delete Product', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this product?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _loading = true;
      });
      try {
        await _supabaseService.update(table: 'products', id: id, values: {'deleted': true});
        await _fetchProducts();
      } catch (e) {
        debugPrint('Error deleting product: $e');
      } finally {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _products
        .where((p) => (p['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Inventory Products', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openProductForm(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),

          // Product List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : filtered.isEmpty
                    ? const Center(child: Text('No products found.'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          final int stock = p['stock'] as int;
                          final double cost = double.tryParse(p['cost'].toString()) ?? 0.0;
                          final double selling = double.tryParse(p['selling'].toString()) ?? 0.0;

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
                                  CircleAvatar(
                                    backgroundColor: stock < 50 ? const Color(0xFFFEE2E2) : const Color(0xFFDBEAFE),
                                    child: Icon(
                                      Icons.inventory_2,
                                      color: stock < 50 ? Colors.red : Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              'Stock: $stock units',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: stock < 50 ? Colors.redAccent : Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Cost: ${_currencyFormat.format(cost)}',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Selling: ${_currencyFormat.format(selling)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                                        onPressed: () => _openProductForm(p),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: () => _deleteProduct(p['id']),
                                      ),
                                    ],
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
}
