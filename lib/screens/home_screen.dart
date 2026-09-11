import 'package:flutter/material.dart';
import 'discussions_screen.dart';
import 'moments_screen.dart';
import 'wallet_screen.dart';
import 'services_screen.dart';
import 'profile_screen.dart';
import 'package:chatme/widgets/offline_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: _buildTabBody(_selectedIndex)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: isDark ? 0 : 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Discussions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feed_outlined),
            activeIcon: Icon(Icons.feed),
            label: 'Moments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Portefeuille',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_on_outlined),
            activeIcon: Icon(Icons.grid_on),
            label: 'Services',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody(int index) {
    switch (index) {
      case 0:
        return const DiscussionsScreen();
      case 1:
        return const MomentsScreen();
      case 2:
        return const WalletScreen();
      case 3:
        return const ServicesScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const DiscussionsScreen();
    }
  }
}
