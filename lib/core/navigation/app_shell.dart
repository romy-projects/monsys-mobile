import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:monsys_mobile/core/navigation/marketplace_nav_bar.dart';

/// Persistent 5-tab shell:
/// Home · Orders · Stock · Reports · Account.
///
/// Built with `StatefulNavigationShell` (indexed stack) so each tab keeps its
/// scroll position and in-flight data when switching tabs.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const destinations = <MarketplaceDestination>[
    MarketplaceDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    MarketplaceDestination(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Orders',
    ),
    MarketplaceDestination(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: 'Stock',
    ),
    MarketplaceDestination(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Reports',
    ),
    MarketplaceDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Account',
    ),
  ];

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active tab returns it to its initial location (standard
      // marketplace behaviour) instead of rebuilding the branch.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: MarketplaceNavBar(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: destinations,
      ),
    );
  }
}
