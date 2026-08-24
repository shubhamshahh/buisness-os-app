import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/company_provider.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  List<Map<String, dynamic>> _messages = [];
  bool _loadingHistory = false;
  bool _generatingResponse = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChatHistory();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    if (cid == null) return;

    setState(() {
      _loadingHistory = true;
    });

    try {
      final List<Map<String, dynamic>> history = await _supabaseService.getTableData(
        table: 'chat_history',
        companyId: cid,
        orderBy: 'created_at',
        ascending: true,
      );

      setState(() {
        _messages = history;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    } finally {
      setState(() {
        _loadingHistory = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cid = companyProvider.companyId;
    final uid = authProvider.user?.id;

    if (cid == null || uid == null) return;

    _inputController.clear();
    setState(() {
      _generatingResponse = true;
      _messages.add({
        'message': text,
        'sender': 'user',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    try {
      // 1. Save user message to database
      await _supabaseService.insert(table: 'chat_history', row: {
        'company_id': cid,
        'user_id': uid,
        'message': text,
        'sender': 'user',
      });

      // 2. Process query with intelligent local database analyzer
      final responseText = await _analyzeQuery(text, cid);

      // 3. Save AI response to database
      await _supabaseService.insert(table: 'chat_history', row: {
        'company_id': cid,
        'user_id': uid,
        'message': responseText,
        'sender': 'ai',
      });

      setState(() {
        _messages.add({
          'message': responseText,
          'sender': 'ai',
          'created_at': DateTime.now().toIso8601String(),
        });
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
    } finally {
      setState(() {
        _generatingResponse = false;
      });
    }
  }

  Future<String> _analyzeQuery(String text, int cid) async {
    final query = text.toLowerCase();

    // Query 1: Revenue check
    if (query.contains('revenue') || query.contains('sales') || query.contains('income')) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc().toIso8601String();

      final invoices = await _supabaseService.client
          .from('invoices')
          .select('total')
          .eq('company_id', cid)
          .gte('created_at', start)
          .lte('created_at', end);

      double sum = 0;
      for (var inv in invoices) {
        sum += double.tryParse(inv['total'].toString()) ?? 0.0;
      }
      return 'Today\'s total billing revenue is ${_currencyFormat.format(sum)} across ${invoices.length} order(s).';
    }

    // Query 2: Product check
    if (query.contains('product') || query.contains('stock') || query.contains('inventory')) {
      final products = await _supabaseService.client
          .from('products')
          .select('name, stock')
          .eq('company_id', cid)
          .eq('deleted', false);

      final List<Map<String, dynamic>> lowStock = [];
      for (var p in products) {
        final int stock = (p['stock'] as int?) ?? 0;
        if (stock < 50) {
          lowStock.add(p);
        }
      }

      if (query.contains('low') || query.contains('warning')) {
        if (lowStock.isEmpty) {
          return 'Great news! All products have healthy stock levels (above 50 units).';
        } else {
          final itemsText = lowStock.map((p) => '${p['name']} (${p['stock']} left)').join(', ');
          return 'There are ${lowStock.length} items running low: $itemsText.';
        }
      }

      return 'You currently have ${products.length} active products in your inventory catalog. Type "low stock" to see alerts.';
    }

    // Query 3: Customers check
    if (query.contains('customer') || query.contains('client')) {
      final customers = await _supabaseService.client
          .from('customers')
          .select('name, pending')
          .eq('company_id', cid)
          .eq('deleted', false);

      double totalPending = 0;
      int pendingCount = 0;
      for (var c in customers) {
        final double pending = double.tryParse(c['pending'].toString()) ?? 0.0;
        if (pending > 0) {
          totalPending += pending;
          pendingCount++;
        }
      }

      return 'You have ${customers.length} registered customers. Among them, $pendingCount customer(s) have pending payments totaling ${_currencyFormat.format(totalPending)}.';
    }

    // Default Fallback Help Response
    return 'Hi there! I am your BusinessOS Assistant. I can help analyze your business records. Try asking me:\n'
        '• "What is today\'s revenue?"\n'
        '• "Which items are low in stock?"\n'
        '• "Tell me about my customers."';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      primaryColor: const Color(0xFF2563EB),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        body: _loadingHistory
            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            : Column(
                children: [
                  // Message board
                  Expanded(
                    child: _messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.assistant_outlined, size: 64, color: Colors.blueAccent),
                                  SizedBox(height: 16),
                                  Text(
                                    'How can I help you today?',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Ask me about your today\'s revenue, inventory stock, or customer balances.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _messages.length,
                            padding: const EdgeInsets.all(16.0),
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final bool isAi = msg['sender'] == 'ai';
                              return Align(
                                alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAi ? const Color(0xFF1E293B) : const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isAi ? 2 : 16),
                                      bottomRight: Radius.circular(isAi ? 16 : 2),
                                    ),
                                  ),
                                  child: Text(
                                    msg['message'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  if (_generatingResponse)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'BusinessOS Assistant is analyzing...',
                          style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),

                  // Input row
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            style: const TextStyle(color: Colors.white),
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: 'Ask about billing, stock, sales...',
                              hintStyle: const TextStyle(color: Colors.grey),
                              fillColor: const Color(0xFF1E293B),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: const Color(0xFF2563EB),
                          radius: 24,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: _sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
