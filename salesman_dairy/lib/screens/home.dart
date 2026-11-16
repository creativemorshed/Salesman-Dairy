import 'package:flutter/material.dart';

import '../state.dart';
import 'dashboard.dart';
import 'outlets.dart';
import 'progress.dart';
import 'route_screen.dart';
import 'sales.dart';

/// নিচের ৫টি ট্যাব: হোম · আজকের রুট · আউটলেট · বিক্রি · এক নজরে
class Home extends StatelessWidget {
  const Home({super.key});

  static const _pages = <Widget>[
    DashboardScreen(),
    RouteScreen(),
    OutletsScreen(),
    SalesScreen(),
    ProgressScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tabIndex,
      builder: (context, i, _) => Scaffold(
        body: IndexedStack(index: i, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => tabIndex.value = v,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'হোম'),
            NavigationDestination(
                icon: Icon(Icons.alt_route),
                selectedIcon: Icon(Icons.route),
                label: 'আজকের রুট'),
            NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: 'আউটলেট'),
            NavigationDestination(
                icon: Icon(Icons.sell_outlined),
                selectedIcon: Icon(Icons.sell),
                label: 'বিক্রি'),
            NavigationDestination(
                icon: Icon(Icons.trending_up),
                selectedIcon: Icon(Icons.show_chart),
                label: 'এক নজরে'),
          ],
        ),
      ),
    );
  }
}
