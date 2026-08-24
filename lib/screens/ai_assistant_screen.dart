import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  // Voice Recognition & Speaking states
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _voiceOutput = true;

  List<Map<String, dynamic>> _messages = [];
  bool _loadingHistory = false;
  bool _generatingResponse = false;

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
      _sendMessage();
    }
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
      // 1. Save user message to database (optional log)
      try {
        await _supabaseService.insert(table: 'chat_history', row: {
          'company_id': cid,
          'message': text,
          'sender': 'user',
        });
      } catch (e) {
        debugPrint('Could not log user message to chat_history: $e');
      }

      // 2. Process query with intelligent local database analyzer
      final responseText = await _analyzeQuery(text, cid);

      // 3. Save AI response to database (optional log)
      try {
        await _supabaseService.insert(table: 'chat_history', row: {
          'company_id': cid,
          'message': responseText,
          'sender': 'ai',
        });
      } catch (e) {
        debugPrint('Could not log AI response to chat_history: $e');
      }

      setState(() {
        _messages.add({
          'message': responseText,
          'sender': 'ai',
          'created_at': DateTime.now().toIso8601String(),
        });
      });
      _scrollToBottom();

      if (_voiceOutput) {
        await _tts.speak(responseText);
      }
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
        appBar: AppBar(
          title: const Text('BusinessOS AI Assistant'),
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
                              hintText: _isListening ? 'Listening... Speak now...' : 'Ask about billing, stock, sales...',
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
                                  color: _isListening ? Colors.redAccent : Colors.grey,
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
