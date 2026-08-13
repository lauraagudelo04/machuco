import 'package:flutter/material.dart';

@immutable
class AppNavigationDestination {
  const AppNavigationDestination({required this.icon, required this.selectedIcon, required this.label});
  final IconData icon; final IconData selectedIcon; final String label;
}

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({super.key, required this.destinations, required this.selectedIndex, required this.onDestinationSelected});
  final List<AppNavigationDestination> destinations; final int selectedIndex; final ValueChanged<int> onDestinationSelected;
  @override Widget build(BuildContext context) {
    assert(destinations.length >= 3 && destinations.length <= 5, 'La navegación debe tener entre 3 y 5 destinos.');
    return SafeArea(top: false, child: NavigationBar(selectedIndex: selectedIndex, onDestinationSelected: onDestinationSelected, destinations: [for (final item in destinations) NavigationDestination(icon: Icon(item.icon), selectedIcon: Icon(item.selectedIcon), label: item.label)]));
  }
}
