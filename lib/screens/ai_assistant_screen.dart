import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
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
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  // Gemini API Key
  static const String _geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyCXb-03Fj_c16tW42T9H3iQ_1z2j-Lg_10',
  );

  // Voice Recognition & Speaking states
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _voiceOutput = true;

  List<Map<String, dynamic>> _messages = [];
  bool _loadingHistory = false;
  bool _generatingResponse = false;

  final List<String> _quickChips = [
    'Pending Payments',
    "Today's Sales",
    'Low Stock',
    'Top Customer',
    'Create Invoice',
    'Create Quote',
    'Record Expense',
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChatHistory();
    });
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (val) => debugPrint('Speech onError: $val'),
        onStatus: (val) {
          debugPrint('Speech onStatus: $val');
          if (val == 'done' || val == 'notListening') {
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      setState(() {});
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  void _initTts() async {
    try {
      await _tts.setLanguage("en-IN");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  void _startListening() async {
    if (!_speechEnabled) {
      _initSpeech();
      return;
    }
    setState(() {
      _isListening = true;
    });
    try {
      await _speech.listen(
        onResult: (val) {
          setState(() {
            _inputController.text = val.recognizedWords;
          });
        },
      );
    } catch (e) {
      debugPrint('Speech listen error: $e');
    }
  }

  void _stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Speech stop error: $e');
    }
    setState(() {
      _isListening = false;
    });
    if (_inputController.text.trim().isNotEmpty) {
      _sendMessage(_inputController.text.trim());
    }
  }

  Future<void> _loadChatHistory() async {
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final cid = companyProvider.companyId ?? 1;

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

  void _sendMessage([String? customText]) async {
    final text = (customText ?? _inputController.text).trim();
    if (text.isEmpty) return;

    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cid = companyProvider.companyId ?? 1;
    final uid = authProvider.user?.id;

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
      // Log user message to database
      if (uid != null) {
        try {
          await _supabaseService.insert(table: 'chat_history', row: {
            'company_id': cid,
            'message': text,
            'sender': 'user',
          });
        } catch (e) {
          debugPrint('Could not log user message: $e');
        }
      }

      // Process query with live Supabase database & Gemini AI engine
      final aiResult = await _processAiQuery(text, cid);
      final responseText = aiResult['reply'] as String;
      final redirectUrl = aiResult['redirect'] as String?;
      final whatsappUrl = aiResult['whatsappUrl'] as String?;

      // Auto-launch WhatsApp if URL returned
      if (whatsappUrl != null && whatsappUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(whatsappUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          debugPrint('Could not launch WhatsApp: $e');
        }
      }

      // Log AI response
      if (uid != null) {
        try {
          await _supabaseService.insert(table: 'chat_history', row: {
            'company_id': cid,
            'message': responseText,
            'sender': 'ai',
          });
        } catch (e) {
          debugPrint('Could not log AI response: $e');
        }
      }

      setState(() {
        _messages.add({
          'message': responseText,
          'sender': 'ai',
          'redirect': redirectUrl,
          'whatsappUrl': whatsappUrl,
          'created_at': DateTime.now().toIso8601String(),
        });
      });
      _scrollToBottom();

      if (_voiceOutput) {
        await _tts.speak(responseText);
      }
    } catch (e) {
      debugPrint('Error processing AI query: $e');
    } finally {
      setState(() {
        _generatingResponse = false;
      });
    }
  }

  // Multilingual query normalization
  String _normalizeSearch(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'પ્રિયા|प्रिया'), 'priya')
        .replaceAll(RegExp(r'રાજેશ|राजेश'), 'rajesh')
        .replaceAll(RegExp(r'મિક્સર|मिक्सर'), 'mixer')
        .replaceAll(RegExp(r'બિલ|ઇન્વોઇસ|ઇનવોઇસ|બતાવો|ખોલો|ખોલ|જોવું|દેખાડો|દિખાઓ|दिखाओ|खोलें|bill|billing'), 'invoice')
        .replaceAll(RegExp(r'સ્ટોક|स्टॉक|માલ|કેટલો|કિતના'), 'stock')
        .replaceAll(RegExp(r'ખર્ચ|ખર્ચા|खर्चा|खर्च'), 'expense')
        .replaceAll(RegExp(r'ગ્રાહક|ग्राहक'), 'customer')
        .replaceAll(RegExp(r'બાકી|પેન્ડિંગ|बाकी|baki|baaki'), 'pending')
        .replaceAll(RegExp(r'આજ|आज'), 'today')
        .replaceAll(RegExp(r'વેચાણ|બિક્રી|बिक्री|सेल'), 'sale')
        .replaceAll(RegExp(r'મોકલો|ભેજો|भेजो'), 'send')
        .replaceAll(RegExp(r'કેટલા|કિતને|kitne|kitna|how many'), 'count');
  }

  Future<Map<String, dynamic>> _processAiQuery(String text, int cid) async {
    // 1. Fetch live database context
    final customersData = await _supabaseService.client
        .from('customers')
        .select('id, name, mobile, pending')
        .eq('company_id', cid)
        .eq('deleted', false)
        .limit(50);
    final customersList = List<Map<String, dynamic>>.from(customersData);

    final productsData = await _supabaseService.client
        .from('products')
        .select('id, name, stock, selling, cost, deleted')
        .eq('company_id', cid)
        .limit(50);
    final productsList = List<Map<String, dynamic>>.from(productsData);

    final invoicesData = await _supabaseService.client
        .from('invoices')
        .select('id, invoice_no, customer_name, customer_id, total, status, created_at')
        .eq('company_id', cid)
        .order('id', ascending: false)
        .limit(30);
    final recentInvoices = List<Map<String, dynamic>>.from(invoicesData);

    final quotationsData = await _supabaseService.client
        .from('quotations')
        .select('id')
        .eq('company_id', cid);
    final int quotesCount = quotationsData.length;

    // Real-time metric computations
    final pendingInvoices = recentInvoices.where((inv) => inv['status'] == 'Pending').toList();
    double totalPendingAmount = 0;
    for (var inv in pendingInvoices) {
      totalPendingAmount += double.tryParse(inv['total'].toString()) ?? 0.0;
    }
    final topPendingDebtors = pendingInvoices
        .map((inv) => '${inv['customer_name']} (₹${(double.tryParse(inv['total'].toString()) ?? 0.0).toStringAsFixed(0)})')
        .toSet()
        .take(3)
        .join(', ');

    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final todayInvoices = recentInvoices.where((inv) => (inv['created_at']?.toString() ?? '').startsWith(todayStr)).toList();
    double todaySalesTotal = 0;
    for (var inv in todayInvoices) {
      todaySalesTotal += double.tryParse(inv['total'].toString()) ?? 0.0;
    }

    final lowStockItems = productsList.where((p) => ((p['stock'] as int?) ?? 0) <= 5).toList();

    // 2. Try Gemini 3.6 Flash API
    if (_geminiApiKey.isNotEmpty) {
      try {
        final systemPrompt = '''You are Jarvis, the BusinessOS AI Assistant for this company.
Live Data:
- Invoices: ${recentInvoices.length}, Customers: ${customersList.length}, Products: ${productsList.length}, Quotes: $quotesCount
- Pending Summary: ${pendingInvoices.length} unpaid invoices totaling ₹${totalPendingAmount.toStringAsFixed(2)}. Top: $topPendingDebtors
- Today's Sales: ${todayInvoices.length} invoices totaling ₹${todaySalesTotal.toStringAsFixed(2)}
- Low Stock: ${lowStockItems.map((p) => '${p['name']} (${p['stock']} left)').join(', ')}
- Invoices List: ${jsonEncode(recentInvoices)}
- Customers List: ${jsonEncode(customersList)}
- Products List: ${jsonEncode(productsList)}

Rules:
1. Pending Payments: State unpaid total and top debtors. Set 'redirect' to "/invoices?status=Pending".
2. Today's Sales: State today's count & revenue. Set 'redirect' to "/invoices".
3. WhatsApp Share: Lookup phone & format whatsappUrl ("https://api.whatsapp.com/send?text=...&phone=...").
4. Create invoice: Set redirect to "/invoices".
5. Stock Check: State stock count & price. Set redirect to "/products".
6. Reply strictly in JSON: {"reply": "...", "redirect": "/...", "whatsappUrl": "..."}''';

        final response = await http.post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$_geminiApiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': systemPrompt},
                  {'text': 'User Message: "$text"'}
                ]
              }
            ],
            'generationConfig': {'responseMimeType': 'application/json'}
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          String? textResp = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (textResp != null) {
            textResp = textResp.replaceAll('```json', '').replaceAll('```', '').trim();
            final parsed = jsonDecode(textResp);
            return {
              'reply': parsed['reply'] ?? 'Processing your request.',
              'redirect': parsed['redirect'],
              'whatsappUrl': parsed['whatsappUrl'],
            };
          }
        }
      } catch (e) {
        debugPrint('Gemini API call failed, using intelligent business analyzer fallback: $e');
      }
    }

    // 3. Fallback: Intelligent Multilingual Business Analyzer
    final msgLower = text.toLowerCase().trim();
    final msgNormalized = _normalizeSearch(text);

    final matchedCustomer = customersList.firstWhere(
      (c) => msgNormalized.contains((c['name']?.toString() ?? '').toLowerCase()) || msgLower.contains((c['name']?.toString() ?? '').toLowerCase()),
      orElse: () => {},
    );

    final matchedProduct = productsList.firstWhere(
      (p) => msgNormalized.contains((p['name']?.toString() ?? '').toLowerCase()) || msgLower.contains((p['name']?.toString() ?? '').toLowerCase()),
      orElse: () => {},
    );

    final matchedInvoice = matchedCustomer.isNotEmpty
        ? recentInvoices.firstWhere(
            (inv) => (inv['customer_name']?.toString() ?? '').toLowerCase().contains((matchedCustomer['name']?.toString() ?? '').toLowerCase()) || inv['customer_id'] == matchedCustomer['id'],
            orElse: () => {},
          )
        : recentInvoices.firstWhere(
            (inv) => msgNormalized.contains((inv['customer_name']?.toString() ?? '').toLowerCase()) || msgNormalized.contains(inv['id'].toString()) || msgLower.contains(inv['id'].toString()),
            orElse: () => {},
          );

    // 1. Pending Payments
    if (msgNormalized.contains('pending') || msgNormalized.contains('unpaid') || msgNormalized.contains('due') || msgNormalized.contains('baaki') || msgNormalized.contains('baki') || msgLower == 'pending payments') {
      return {
        'reply': 'You currently have ${pendingInvoices.length} pending invoice(s) totaling ${_currencyFormat.format(totalPendingAmount)}${topPendingDebtors.isNotEmpty ? '. Unpaid bills include: $topPendingDebtors' : ''}.',
        'redirect': '/invoices',
      };
    }

    // 2. Today's Sales
    if (msgNormalized.contains('today') && (msgNormalized.contains('sale') || msgNormalized.contains('revenue') || msgNormalized.contains('invoice'))) {
      return {
        'reply': 'Today\'s sales recorded: ${todayInvoices.length} invoice(s) totaling ${_currencyFormat.format(todaySalesTotal)}.',
        'redirect': '/invoices',
      };
    }

    // 3. Low Stock
    if (msgNormalized.contains('low stock') || msgNormalized.contains('kam stock')) {
      return {
        'reply': lowStockItems.isNotEmpty
            ? 'You have ${lowStockItems.length} item(s) running low on stock: ${lowStockItems.map((p) => '${p['name']} (${p['stock']} left)').join(', ')}.'
            : 'Great news! All items have healthy stock levels in your inventory catalog.',
        'redirect': '/products',
      };
    }

    // 4. Top Customer
    if (msgNormalized.contains('top customer')) {
      final topCusts = recentInvoices.map((i) => i['customer_name']?.toString() ?? '').toSet().take(3).join(', ');
      return {
        'reply': 'Top active customers include: ${topCusts.isNotEmpty ? topCusts : 'Walk-in Customers'}.',
        'redirect': '/customers',
      };
    }

    // 5. Create Invoice
    if (msgNormalized.contains('create invoice') || msgNormalized.contains('new invoice') || msgNormalized.contains('bill')) {
      final cust = matchedCustomer['name']?.toString() ?? '';
      final prod = matchedProduct['name']?.toString() ?? '';
      return {
        'reply': 'Opening invoice builder ${cust.isNotEmpty ? 'for $cust' : ''} ${prod.isNotEmpty ? 'with $prod' : ''}.',
        'redirect': '/invoices',
      };
    }

    // 6. Create Quotation
    if (msgNormalized.contains('create quote') || msgNormalized.contains('new quote') || msgNormalized.contains('quotation')) {
      final cust = matchedCustomer['name']?.toString() ?? '';
      return {
        'reply': 'Opening quotation builder ${cust.isNotEmpty ? 'for $cust' : ''}.',
        'redirect': '/quotations',
      };
    }

    // 7. Record Expense
    if (msgNormalized.contains('expense')) {
      final amountMatch = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(text);
      final amount = amountMatch != null ? amountMatch.group(1) : '';
      return {
        'reply': 'Opening expense recorder ${amount != null && amount.isNotEmpty ? 'for ₹$amount' : ''}.',
        'redirect': '/expenses',
      };
    }

    // 8. WhatsApp Sharing
    if (msgNormalized.contains('whatsapp') || msgNormalized.contains('share') || msgNormalized.contains('send')) {
      if (matchedInvoice.isNotEmpty) {
        final custName = matchedInvoice['customer_name'] ?? (matchedCustomer['name'] ?? 'Customer');
        final mobile = matchedCustomer['mobile']?.toString() ?? '';
        final phone = mobile.isNotEmpty ? '&phone=91${mobile.replaceAll(RegExp(r'\D'), '').substring(mobile.length >= 10 ? mobile.length - 10 : 0)}' : '';
        final shareText = Uri.encodeComponent('Hello $custName, here is your invoice #${matchedInvoice['id']} amounting to Rs.${matchedInvoice['total']}. Thank you for your business!');
        final url = 'https://api.whatsapp.com/send?text=$shareText$phone';
        return {
          'reply': 'I have generated the WhatsApp link to share $custName\'s invoice (#${matchedInvoice['id']} for ₹${matchedInvoice['total']}).',
          'whatsappUrl': url,
          'redirect': '/invoices',
        };
      } else {
        return {
          'reply': 'You have ${recentInvoices.length} invoice(s). Opening the invoices page where you can share via WhatsApp.',
          'redirect': '/invoices',
        };
      }
    }

    // 9. Stock Inquiry
    if (msgNormalized.contains('stock') && matchedProduct.isNotEmpty) {
      final stock = matchedProduct['stock'] ?? 0;
      final price = matchedProduct['selling'] ?? 0;
      return {
        'reply': 'You have $stock units of ${matchedProduct['name']} in stock, priced at ₹$price.',
        'redirect': '/products',
      };
    }

    // 10. Specific Invoice Search
    if (matchedInvoice.isNotEmpty || (matchedCustomer.isNotEmpty && msgNormalized.contains('invoice'))) {
      final custName = matchedInvoice['customer_name'] ?? matchedCustomer['name'] ?? 'Customer';
      final total = matchedInvoice['total'] != null ? 'for ₹${matchedInvoice['total']}' : '';
      return {
        'reply': 'Here is the invoice for $custName $total. Opening it for you.',
        'redirect': '/invoices',
      };
    }

    // 11. General Counts & Navigations
    if (msgNormalized.contains('invoice') || (msgNormalized.contains('count') && msgNormalized.contains('bill'))) {
      return {
        'reply': 'You currently have ${recentInvoices.length} invoice(s) recorded in your system.',
        'redirect': '/invoices',
      };
    } else if (msgNormalized.contains('product') || msgNormalized.contains('inventory')) {
      return {
        'reply': 'You currently have ${productsList.length} product(s) in your catalog.',
        'redirect': '/products',
      };
    } else if (msgNormalized.contains('customer') || msgNormalized.contains('client')) {
      return {
        'reply': 'You have ${customersList.length} customer(s) registered in your system.',
        'redirect': '/customers',
      };
    } else if (msgNormalized.contains('quote') || msgNormalized.contains('quotation')) {
      return {
        'reply': 'You have $quotesCount quotation(s) active in your system.',
        'redirect': '/quotations',
      };
    }

    // Default Overview
    return {
      'reply': 'Hello! I am Jarvis, your BusinessOS Assistant. Currently, you have ${customersList.length} customer(s), ${productsList.length} product(s), ${recentInvoices.length} invoice(s), and $quotesCount quotation(s) recorded in your system.',
    };
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
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 22),
              SizedBox(width: 8),
              Text('Jarvis AI Assistant', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          actions: [
            Row(
              children: [
                Icon(
                  _voiceOutput ? Icons.volume_up : Icons.volume_off,
                  color: _voiceOutput ? Colors.blueAccent : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _voiceOutput,
                  activeThumbColor: Colors.blueAccent,
                  onChanged: (val) {
                    setState(() {
                      _voiceOutput = val;
                    });
                    if (!val) {
                      _tts.stop();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        body: _loadingHistory
            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            : Column(
                children: [
                  // Quick Action Chips
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _quickChips.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final chip = _quickChips[index];
                        return ActionChip(
                          label: Text(chip, style: const TextStyle(fontSize: 12, color: Colors.white)),
                          backgroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFF334155)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          onPressed: () => _sendMessage(chip),
                        );
                      },
                    ),
                  ),

                  const Divider(color: Color(0xFF1E293B), height: 1),

                  // Message board
                  Expanded(
                    child: _messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.auto_awesome, size: 56, color: Colors.blueAccent),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'How can I help you today?',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Speak or type commands like "Pending Payments", "Priya invoice", or "Share on WhatsApp".',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
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
                              final String? redirect = msg['redirect'];
                              final String? whatsappUrl = msg['whatsappUrl'];

                              return Align(
                                alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.85,
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg['message'] ?? '',
                                        style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35),
                                      ),
                                      if (isAi && (redirect != null || whatsappUrl != null))
                                        Padding(
                                          padding: const EdgeInsets.only(top: 10.0),
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              if (whatsappUrl != null)
                                                ElevatedButton.icon(
                                                  icon: const Icon(Icons.share, size: 16, color: Colors.white),
                                                  label: const Text('Open WhatsApp', style: TextStyle(fontSize: 12, color: Colors.white)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF25D366),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                  onPressed: () async {
                                                    final uri = Uri.parse(whatsappUrl);
                                                    if (await canLaunchUrl(uri)) {
                                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                    }
                                                  },
                                                ),
                                              if (redirect != null)
                                                ElevatedButton.icon(
                                                  icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                                                  label: const Text('Open Screen', style: TextStyle(fontSize: 12, color: Colors.white)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF3B82F6),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                  onPressed: () {
                                                    final path = redirect.split('?')[0];
                                                    context.go(path);
                                                  },
                                                ),
                                            ],
                                          ),
                                        ),
                                    ],
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
                        child: Row(
                          children: [
                            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)),
                            SizedBox(width: 8),
                            Text(
                              'Jarvis is analyzing your live business data...',
                              style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ],
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
                              hintText: _isListening ? 'Listening... Speak now...' : 'Ask about billing, pending, stock...',
                              hintStyle: const TextStyle(color: Colors.grey),
                              fillColor: const Color(0xFF1E293B),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isListening ? Icons.mic_off : Icons.mic,
                                  color: _isListening ? Colors.redAccent : Colors.blueAccent,
                                ),
                                onPressed: _toggleListening,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: const Color(0xFF2563EB),
                          radius: 24,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: () => _sendMessage(),
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
