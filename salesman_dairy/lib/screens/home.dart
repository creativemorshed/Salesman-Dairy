import 'package:flutter/material.dart';
import '../i18n.dart';

import '../state.dart';
import 'dashboard.dart';
import 'outlets.dart';
import 'progress.dart';
import 'route_screen.dart';
import 'sales.dart';

/// নিচের ৫টি ট্যাব: হোম · রুট · আউটলেট · বিক্রয় · এক নজরে
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
      builder: (context, i, _) {
        LangScope.watch(context);
        return Scaffold(
        body: IndexedStack(index: i, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => tabIndex.value = v,
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: tr('হোম')),
            NavigationDestination(
                icon: const Icon(Icons.alt_route),
                selectedIcon: const Icon(Icons.route),
                label: tr('রুট')),
            NavigationDestination(
                icon: const Icon(Icons.storefront_outlined),
                selectedIcon: const Icon(Icons.storefront),
                label: tr('আউটলেট')),
            NavigationDestination(
                icon: const Icon(Icons.sell_outlined),
                selectedIcon: const Icon(Icons.sell),
                label: tr('বিক্রয়')),
            NavigationDestination(
                icon: const Icon(Icons.trending_up),
                selectedIcon: const Icon(Icons.show_chart),
                label: tr('এক নজরে')),
          ],
        ),
      );
      },
    );
  }
}
