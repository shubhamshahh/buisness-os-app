import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../providers/company_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  bool _loading = false;
  bool _saving = false;

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNoController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();

  int? _settingsId;
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loading = true;
    });

    try {
      // 1. Fetch Company metadata
      final companyData = await _supabaseService.client
          .from('companies')
          .select()
          .eq('id', cid)
          .maybeSingle();

      if (companyData != null) {
        _companyNameController.text = companyData['name'] ?? '';
        _gstController.text = companyData['gst_number'] ?? '';
        _addressController.text = companyData['company_address'] ?? '';
      }

      // 2. Fetch Business Settings
      final settingsData = await _supabaseService.client
          .from('business_settings')
          .select()
          .eq('company_id', cid)
          .maybeSingle();

      if (settingsData != null) {
        _settingsId = settingsData['id'] as int?;
        _bankNameController.text = settingsData['bank_name'] ?? '';
        _accountNoController.text = settingsData['account_no'] ?? '';
        _ifscController.text = settingsData['ifsc_code'] ?? '';
        _branchController.text = settingsData['branch_name'] ?? '';
        _termsController.text = settingsData['terms_and_conditions'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _saving = true;
    });

    try {
      // 1. Update Company metadata
      await _supabaseService.client.from('companies').update({
        'name': _companyNameController.text,
        'gst_number': _gstController.text,
        'company_address': _addressController.text,
      }).eq('id', cid);

      // Refresh cached name in Provider
      await companyProvider.fetchCompany(_supabaseService.currentUser!.id);

      // 2. Update or Insert Business Settings
      final settingsValues = {
        'company_id': cid,
        'bank_name': _bankNameController.text,
        'account_no': _accountNoController.text,
        'ifsc_code': _ifscController.text,
        'branch_name': _branchController.text,
        'terms_and_conditions': _termsController.text,
      };

      if (_settingsId != null) {
        await _supabaseService.client
            .from('business_settings')
            .update(settingsValues)
            .eq('id', _settingsId!);
      } else {
        await _supabaseService.client.from('business_settings').insert(settingsValues);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!')),
        );
      }
      _fetchSettings();
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving settings')),
        );
      }
    } finally {
      setState(() {
        _saving = false;
      });
    }
  }

  Future<void> _seedDemoData() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _seeding = true;
    });

    try {
      // 1. Seed sample products
      await _supabaseService.insert(table: 'products', row: {
        'company_id': cid,
        'name': 'Wireless Ergonomic Mouse',
        'sku': 'MS-001',
        'description': 'High precision Bluetooth mouse',
        'price': 1200.0,
        'selling': 1800.0,
        'stock': 45,
        'deleted': false,
      });

      await _supabaseService.insert(table: 'products', row: {
        'company_id': cid,
        'name': 'Mechanical Gaming Keyboard',
        'sku': 'KB-99',
        'description': 'RGB backlighting, blue switches',
        'price': 3000.0,
        'selling': 4500.0,
        'stock': 12,
        'deleted': false,
      });

      // 2. Seed sample customers
      final c1 = await _supabaseService.insert(table: 'customers', row: {
        'company_id': cid,
        'name': 'Ramesh Kumar',
        'mobile': '9876543210',
        'email': 'ramesh@example.com',
        'address': 'Sector 62, Noida, UP',
        'outstanding_balance': 0.0,
        'deleted': false,
      });

      await _supabaseService.insert(table: 'customers', row: {
        'company_id': cid,
        'name': 'Ananya Sharma',
        'mobile': '8877665544',
        'email': 'ananya@example.com',
        'address': 'Indiranagar, Bengaluru, KA',
        'outstanding_balance': 1500.0,
        'deleted': false,
      });

      // 3. Seed sample orders
      await _supabaseService.insert(table: 'orders', row: {
        'company_id': cid,
        'customer_name': 'Ramesh Kumar',
        'customer_phone': '9876543210',
        'city': 'Noida',
        'total': 1800.0,
        'status': 'Delivered',
      });

      await _supabaseService.insert(table: 'orders', row: {
        'company_id': cid,
        'customer_name': 'Ananya Sharma',
        'customer_phone': '8877665544',
        'city': 'Bengaluru',
        'total': 4500.0,
        'status': 'Pending',
      });

      // 4. Seed sample invoice
      final inv = await _supabaseService.insert(table: 'invoices', row: {
        'company_id': cid,
        'customer_name': 'Ramesh Kumar',
        'customer_id': c1['id'],
        'subtotal': 1525.42,
        'gst': 274.58,
        'total': 1800.0,
        'status': 'Paid',
      });

      // Seed sample invoice items
      await _supabaseService.insert(table: 'invoice_items', row: {
        'invoice_id': inv['id'],
        'product_name': 'Wireless Ergonomic Mouse',
        'qty': 1,
        'price': 1800.0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo data seeded successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error seeding demo data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seeding demo data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _seeding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save, color: Colors.blueAccent),
              onPressed: _saveSettings,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionCard(
                    title: 'Business Info',
                    icon: Icons.business,
                    children: [
                      _buildTextField(controller: _companyNameController, label: 'Business Name'),
                      _buildTextField(controller: _gstController, label: 'GST Number'),
                      _buildTextField(controller: _addressController, label: 'Company Address', maxLines: 2),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Bank & Payment Details',
                    icon: Icons.account_balance,
                    children: [
                      _buildTextField(controller: _bankNameController, label: 'Bank Name'),
                      _buildTextField(controller: _accountNoController, label: 'Account Number'),
                      _buildTextField(controller: _ifscController, label: 'IFSC Code'),
                      _buildTextField(controller: _branchController, label: 'Branch Name'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Invoice Print Settings',
                    icon: Icons.print_outlined,
                    children: [
                      _buildTextField(controller: _termsController, label: 'Terms & Conditions', maxLines: 3),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Developer Sandbox',
                    icon: Icons.science_outlined,
                    children: [
                      const Text(
                        'Seeding will inject mock products, customers, invoices, and sales transactions into your database so you can preview app dashboards with data.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      _seeding
                          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                          : OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blueAccent,
                                side: const BorderSide(color: Colors.blueAccent),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _seedDemoData,
                              icon: const Icon(Icons.playlist_add),
                              label: const Text('Seed Demo Data', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saveSettings,
                    child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }
}
