import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/company_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/shell_layout.dart';
import 'screens/dashboard_screen.dart';
import 'screens/products_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/invoice_creator_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/stock_ledger_screen.dart';
import 'screens/ai_assistant_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/quotations_screen.dart';
import 'screens/purchases_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load Supabase URL and Key from environment parameters (defined using --dart-define)
  const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://goajgrsxklyxpoiicbii.supabase.co',
  );
  const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_xS7FZopRJ6oRESUQ9AkyvA_wP8tQw47',
  );

  bool supabaseInitialized = false;

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      supabaseInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize Supabase: $e');
    }
  }

  runApp(
    MyApp(
      supabaseInitialized: supabaseInitialized,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool supabaseInitialized;
  final String supabaseUrl;
  final String supabaseAnonKey;

  const MyApp({
    super.key,
    required this.supabaseInitialized,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  @override
  Widget build(BuildContext context) {
    if (!supabaseInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0F172A),
        ),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.amber),
                  const SizedBox(height: 16),
                  const Text(
                    'Configuration Required',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please initialize the app with your Supabase credentials. You can run the app with:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final GoRouter router = GoRouter(
            initialLocation: '/',
            redirect: (context, state) {
              final isLoggingIn = state.matchedLocation == '/login';
              final isSigningUp = state.matchedLocation == '/signup';

              if (!auth.isAuthenticated) {
                if (isLoggingIn || isSigningUp) return null;
                return '/login';
              }

              if (auth.isAuthenticated && (isLoggingIn || isSigningUp)) {
                return '/';
              }

              return null;
            },
            routes: [
              GoRoute(
                path: '/login',
                builder: (context, state) => const LoginScreen(),
              ),
              GoRoute(
                path: '/signup',
                builder: (context, state) => const SignupScreen(),
              ),
              ShellRoute(
                builder: (context, state, child) => ShellLayout(child: child),
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) => const DashboardScreen(),
                  ),
                  GoRoute(
                    path: '/products',
                    builder: (context, state) => const ProductsScreen(),
                  ),
                  GoRoute(
                    path: '/invoices',
                    builder: (context, state) => const InvoiceCreatorScreen(),
                  ),
                  GoRoute(
                    path: '/ai-assistant',
                    builder: (context, state) => const AiAssistantScreen(),
                  ),
                  GoRoute(
                    path: '/customers',
                    builder: (context, state) => const CustomersScreen(),
                  ),
                  GoRoute(
                    path: '/expenses',
                    builder: (context, state) => const ExpensesScreen(),
                  ),
                  GoRoute(
                    path: '/stock-ledger',
                    builder: (context, state) => const StockLedgerScreen(),
                  ),
                  GoRoute(
                    path: '/orders',
                    builder: (context, state) => const OrdersScreen(),
                  ),
                  GoRoute(
                    path: '/quotations',
                    builder: (context, state) => const QuotationsScreen(),
                  ),
                  GoRoute(
                    path: '/purchases',
                    builder: (context, state) => const PurchasesScreen(),
                  ),
                  GoRoute(
                    path: '/sales',
                    builder: (context, state) => const SalesScreen(),
                  ),
                  GoRoute(
                    path: '/reports',
                    builder: (context, state) => const ReportsScreen(),
                  ),
                  GoRoute(
                    path: '/settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          );

          return MaterialApp.router(
            title: 'BusinessOS Mobile',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2563EB),
                brightness: Brightness.light,
              ),
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
