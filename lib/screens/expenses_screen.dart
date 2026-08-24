import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/company_provider.dart';
import '../services/supabase_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  List<Map<String, dynamic>> _expenses = [];
  List<String> _categories = [];
  bool _loading = false;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchExpensesAndCategories();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchExpensesAndCategories() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final expData = await _supabaseService.getTableData(
        table: 'expenses',
        companyId: cid,
        orderBy: 'created_at',
        ascending: false,
      );

      final catData = await _supabaseService.getTableData(
        table: 'expense_categories',
        companyId: cid,
        orderBy: 'name',
      );

      setState(() {
        _expenses = expData;
        _categories = catData.map((c) => (c['name'] as String)).toList();
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
      });
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _openExpenseForm() {
    if (_categories.isEmpty) {
      // Setup default fallback categories if none exist in the database
      _categories = ['Rent', 'Salary', 'Utilities', 'Inventory Purchase', 'Marketing', 'Other'];
      _selectedCategory = 'Rent';
    }

    _amountController.clear();
    _descriptionController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Record New Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Expense Category', labelStyle: TextStyle(color: Colors.grey)),
                items: _categories.map((c) {
                  return DropdownMenuItem<String>(
                    value: c,
                    child: Text(c),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) => val!.isEmpty ? 'Amount is required' : null,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Description / Note',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _saveExpense,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Record', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    Navigator.pop(context);
    setState(() {
      _loading = true;
    });

    final row = {
      'category': _selectedCategory,
      'amount': double.tryParse(_amountController.text) ?? 0.0,
      'description': _descriptionController.text.trim(),
      'company_id': cid,
    };

    try {
      await _supabaseService.insert(table: 'expenses', row: row);
      await _fetchExpensesAndCategories();
    } catch (e) {
      debugPrint('Error saving expense: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalSpend = 0;
    for (var exp in _expenses) {
      totalSpend += double.tryParse(exp['amount'].toString()) ?? 0.0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Expenses Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openExpenseForm,
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Spend Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF0F172A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL EXPENSES RECORDED',
                  style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                Text(
                  _currencyFormat.format(totalSpend),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Expenses List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _expenses.isEmpty
                    ? const Center(child: Text('No expenses recorded.'))
                    : ListView.builder(
                        itemCount: _expenses.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final exp = _expenses[index];
                          final double amount = double.tryParse(exp['amount'].toString()) ?? 0.0;
                          final dateStr = exp['created_at'] != null
                              ? DateFormat('d MMM yyyy').format(DateTime.parse(exp['created_at']))
                              : '';

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
                                backgroundColor: Color(0xFFFEE2E2),
                                child: Icon(Icons.payment, color: Colors.red),
                              ),
                              title: Text(
                                exp['category'] ?? 'General',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${exp['description'] ?? ""}\n$dateStr',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              isThreeLine: true,
                              trailing: Text(
                                _currencyFormat.format(amount),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
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
