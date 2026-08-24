import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/company_provider.dart';
import '../services/supabase_service.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  List<Map<String, dynamic>> _customers = [];
  String _searchQuery = '';
  bool _loading = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _gstController = TextEditingController();
  final _pendingController = TextEditingController();
  int? _editingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCustomers();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _gstController.dispose();
    _pendingController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final List<Map<String, dynamic>> data = await _supabaseService.getTableData(
        table: 'customers',
        companyId: cid,
        eqColumn: 'deleted',
        eqValue: false,
        orderBy: 'name',
      );
      setState(() {
        _customers = data;
      });
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _openCustomerForm([Map<String, dynamic>? customer]) {
    if (customer != null) {
      _editingId = customer['id'] as int?;
      _nameController.text = customer['name'] ?? '';
      _mobileController.text = customer['mobile'] ?? '';
      _emailController.text = customer['email'] ?? '';
      _addressController.text = customer['address'] ?? '';
      _cityController.text = customer['city'] ?? '';
      _gstController.text = customer['gst_number'] ?? '';
      _pendingController.text = customer['pending']?.toString() ?? '0';
    } else {
      _editingId = null;
      _nameController.clear();
      _mobileController.clear();
      _emailController.clear();
      _addressController.clear();
      _cityController.clear();
      _gstController.clear();
      _pendingController.text = '0';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          _editingId == null ? 'Add New Customer' : 'Edit Customer',
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
                    labelText: 'Customer Name',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  validator: (val) => val!.isEmpty ? 'Mobile is required' : null,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'City',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gstController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'GST Number',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pendingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) => val!.isEmpty ? 'Pending balance is required' : null,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Pending Balance (₹)',
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
            onPressed: _saveCustomer,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _saveCustomer() async {
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
      'mobile': _mobileController.text.trim(),
      'email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'gst_number': _gstController.text.trim().toUpperCase(),
      'pending': double.tryParse(_pendingController.text) ?? 0.0,
      'company_id': cid,
      'deleted': false,
    };

    try {
      if (_editingId == null) {
        await _supabaseService.insert(table: 'customers', row: row);
      } else {
        await _supabaseService.update(table: 'customers', id: _editingId, values: row);
      }
      await _fetchCustomers();
    } catch (e) {
      debugPrint('Error saving customer: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _deleteCustomer(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Delete Customer', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this customer?', style: TextStyle(color: Colors.grey)),
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
        await _supabaseService.update(table: 'customers', id: id, values: {'deleted': true});
        await _fetchCustomers();
      } catch (e) {
        debugPrint('Error deleting customer: $e');
      } finally {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _customers
        .where((c) => (c['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Customers CRM', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCustomerForm(),
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.person_add, color: Colors.white),
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
                hintText: 'Search customers by name...',
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

          // Customer List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : filtered.isEmpty
                    ? const Center(child: Text('No customers found.'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          final double pending = double.tryParse(c['pending'].toString()) ?? 0.0;

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
                                    backgroundColor: pending > 0 ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                                    child: Icon(
                                      Icons.person,
                                      color: pending > 0 ? Colors.orange : Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c['name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Mobile: ${c['mobile']}',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        if (c['email'] != null && (c['email'] as String).isNotEmpty)
                                          Text(
                                            'Email: ${c['email']}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        if (c['gst_number'] != null && (c['gst_number'] as String).isNotEmpty)
                                          Text(
                                            'GST: ${c['gst_number']}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Pending Balance: ${_currencyFormat.format(pending)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: pending > 0 ? Colors.orange[800] : Colors.green[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                                        onPressed: () => _openCustomerForm(c),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: () => _deleteCustomer(c['id']),
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
