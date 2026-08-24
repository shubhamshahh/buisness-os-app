import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/company_provider.dart';
import 'dart:convert';

class ShellLayout extends StatelessWidget {
  final Widget child;
  const ShellLayout({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/products')) return 1;
    if (location.startsWith('/invoices')) return 2;
    if (location.startsWith('/ai-assistant')) return 3;
    return 0; // default to dashboard
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/products');
        break;
      case 2:
        context.go('/invoices');
        break;
      case 3:
        context.go('/ai-assistant');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyProvider = Provider.of<CompanyProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final selectedIndex = _calculateSelectedIndex(context);

    final user = authProvider.user;
    final String userEmail = user?.email ?? '';
    final String userFirstName = user?.userMetadata?['first_name'] ?? '';
    final String userLastName = user?.userMetadata?['last_name'] ?? '';
    final String userFullName = '$userFirstName $userLastName'.trim();
    final String displayName = userFullName.isNotEmpty ? userFullName : 'User Account';
    final String? userLogo = (user?.userMetadata?['logo_url'] as String?) ??
        (companyProvider.logoUrl.isNotEmpty ? companyProvider.logoUrl : null);
    
    // Check screen width for responsiveness
    final double width = MediaQuery.of(context).size.width;
    final bool isWide = width >= 768; // Tablet & Desktop threshold

    final drawerHeader = DrawerHeader(
      decoration: const BoxDecoration(color: Color(0xFF0F172A)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              _buildLogoWidget(userLogo, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyProvider.companyName.isNotEmpty
                          ? companyProvider.companyName
                          : 'BusinessOS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'BusinessOS Platform',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final String location = GoRouterState.of(context).uri.toString();

    final drawerItems = [
      _buildSidebarTile(
        icon: Icons.dashboard_outlined,
        title: 'Dashboard',
        selected: location == '/',
        onTap: () {
          if (!isWide) Navigator.of(context).pop();
          context.go('/');
        },
      ),
      _buildSidebarTile(
        icon: Icons.inventory_2_outlined,
        title: 'Products',
        selected: location.startsWith('/products'),
        onTap: () {
          if (!isWide) Navigator.of(context).pop();
          context.go('/products');
        },
      ),
      _buildSidebarTile(
        icon: Icons.shopping_bag_outlined,
        title: 'Orders',
        selected: location.startsWith('/orders'),
        onTap: () {
          if (!isWide) Navigator.of(context).pop();
          context.go('/orders');
        },
      ),
      _buildSidebarTile(
        icon: Icons.receipt_outlined,
        title: 'Invoices',
        selected: location.startsWith('/invoices'),
        onTap: () {
          if (!isWide) Navigator.of(context).pop();
          context.go('/invoices');
        },
      ),
      _buildSidebarTile(
        icon: Icons.description_outlined,
        title: 'Quotations',
        selected: location.startsWith('/quotations'),
        onTap: () {
          if (!isWide) Navigator.of(context).pop();
          context.go('/quotations');
        },
      ),
      _buildSidebarTile(
        icon: Icons.people_alt_outlined,
        title: 'Customers',
        selected: location.startsWith('/customers'),
        onTap: () {
          if (!isWide) Navigator.of(context).pop();
          context.go('/customers');
        },
      ),
      if (companyProvider.role == 'owner') ...[
        _buildSidebarTile(
          icon: Icons.trending_up_outlined,
          title: 'Sales',
          selected: location.startsWith('/sales'),
          onTap: () {
            if (!isWide) Navigator.of(context).pop();
            context.go('/sales');
          },
        ),
        _buildSidebarTile(
          icon: Icons.bar_chart_outlined,
          title: 'Reports',
          selected: location.startsWith('/reports'),
          onTap: () {
            if (!isWide) Navigator.of(context).pop();
            context.go('/reports');
          },
        ),
        _buildSidebarTile(
          icon: Icons.history_outlined,
          title: 'Stock Ledger',
          selected: location.startsWith('/stock-ledger'),
          onTap: () {
            if (!isWide) Navigator.of(context).pop();
            context.go('/stock-ledger');
          },
        ),
      ],
      _buildSidebarTile(
        icon: Icons.shopping_cart_outlined,
        title: 'Purchases',
        selected: location.startsWith('/purchases'),
        onTap: () {
          if (!isWide) Navigator.of(context).pop();
          context.go('/purchases');
        },
      ),
      _buildSidebarTile(
        icon: Icons.credit_card_outlined,
        title: 'Expenses',
        selected: location.startsWith('/expenses'),
        onTap: () {
          if (!isWide) Navigator.of(context).pop();
          context.go('/expenses');
        },
      ),
      _buildSidebarTile(
        icon: Icons.chat_bubble_outline,
        title: 'AI Assistant',
        selected: location.startsWith('/ai-assistant'),
        onTap: () {
          if (!isWide) Navigator.of(context).pop();
          context.go('/ai-assistant');
        },
      ),
    ];

    if (isWide) {
      // Tablet/Desktop Horizontal layout with Sidebar
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 260,
              color: const Color(0xFF0F172A),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        drawerHeader,
                        ...drawerItems,
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF1E293B)),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2563EB),
                      radius: 16,
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      userEmail,
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.more_vert, color: Colors.grey, size: 16),
                    onTap: () {
                      _showAccountMenu(context, authProvider);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const VerticalDivider(width: 1, color: Color(0xFF1E293B)),
            Expanded(child: child),
          ],
        ),
      );
    }

    // Mobile Portrait layout with AppBar, Drawer, and BottomNavigationBar
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          companyProvider.companyName.isNotEmpty
              ? companyProvider.companyName
              : 'BusinessOS',
        ),
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.go('/ai-assistant'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            color: const Color(0xFF1E293B),
            onSelected: (value) async {
              if (value == 'settings') {
                context.go('/settings');
              } else if (value == 'privacy') {
                _showLegalDialog(context, 'Privacy Policy', _getPrivacyPolicyText());
              } else if (value == 'terms') {
                _showLegalDialog(context, 'Terms & Conditions', _getTermsText());
              } else if (value == 'logout') {
                await authProvider.logout();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const Divider(color: Color(0xFF334155)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, color: Colors.white70, size: 18),
                    SizedBox(width: 8),
                    Text('Settings', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'privacy',
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, color: Colors.white70, size: 18),
                    SizedBox(width: 8),
                    Text('Privacy Policy', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'terms',
                child: Row(
                  children: [
                    Icon(Icons.gavel_outlined, color: Colors.white70, size: 18),
                    SizedBox(width: 8),
                    Text('Terms & Conditions', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: ListView(
          children: [
            drawerHeader,
            ...drawerItems,
          ],
        ),
      ),
      body: child,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E293B)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_navItems.length, (index) {
            final isSelected = selectedIndex == index;
            final item = _navItems[index];
            return GestureDetector(
              onTap: () => _onItemTapped(index, context),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected ? const Color(0xFF3B82F6) : Colors.grey,
                      size: 20,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: isSelected
                          ? Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                item.label,
                                style: const TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLogoWidget(String? logoSource, {double size = 40}) {
    Widget content;
    if (logoSource != null && logoSource.isNotEmpty) {
      try {
        if (logoSource.startsWith('data:image')) {
          final base64String = logoSource.split(',').last;
          final bytes = base64.decode(base64String);
          content = Image.memory(
            bytes,
            fit: BoxFit.contain,
          );
        } else if (logoSource.startsWith('http')) {
          content = Image.network(
            logoSource,
            fit: BoxFit.contain,
          );
        } else {
          content = Image.asset('assets/company_logo.png', fit: BoxFit.contain);
        }
      } catch (e) {
        content = Image.asset('assets/company_logo.png', fit: BoxFit.contain);
      }
    } else {
      content = Image.asset('assets/company_logo.png', fit: BoxFit.contain);
    }

    return Container(
      height: size,
      width: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B), width: 1),
      ),
      child: Center(child: content),
    );
  }

  Widget _buildSidebarTile({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2563EB).withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          color: selected ? const Color(0xFF3B82F6) : Colors.grey,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13.5,
          ),
        ),
        trailing: selected
            ? Container(
                width: 3.5,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            : null,
      ),
    );
  }

  void _showAccountMenu(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Colors.white70),
              title: const Text('Settings', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                context.go('/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
              title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showLegalDialog(context, 'Privacy Policy', _getPrivacyPolicyText());
              },
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined, color: Colors.white70),
              title: const Text('Terms & Conditions', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showLegalDialog(context, 'Terms & Conditions', _getTermsText());
              },
            ),
            const Divider(color: Color(0xFF334155)),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                await authProvider.logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLegalDialog(BuildContext context, String title, String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  String _getPrivacyPolicyText() {
    return 'Privacy Policy\n\n'
        '1. Information Collection\n'
        'We collect business data, transaction lists, invoice contents, product inventory metadata, and customer details that you store in our services to facilitate billing operations.\n\n'
        '2. Data Security\n'
        'All data is securely synced and protected via Supabase database encryption and industry-standard security policies.\n\n'
        '3. Cookies and Analytics\n'
        'We may collect diagnostic logs to improve user interface experience and platform scalability.';
  }

  String _getTermsText() {
    return 'Terms & Conditions\n\n'
        '1. Scope of Use\n'
        'By using BusinessOS, you agree to govern your business inventory and sales invoice generation in accordance with local regulations.\n\n'
        '2. Account Responsibility\n'
        'You are solely responsible for keeping your login credentials secure and for all billing actions initiated under your company space.\n\n'
        '3. Limitations of Liability\n'
        'BusinessOS provides real-time billing tools and local analytics and is not liable for taxation filing omissions or ledger discrepancy hazards.';
  }
}

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavItem({required this.icon, required this.activeIcon, required this.label});
}

const _navItems = [
  NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
  NavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Products'),
  NavItem(icon: Icons.receipt_outlined, activeIcon: Icons.receipt, label: 'Invoices'),
  NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'AI Chat'),
];
