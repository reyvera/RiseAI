import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final Function(String) onNavigate;
  final String currentRoute;

  const Sidebar({
    required this.onNavigate,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(child: Text('RiseAI', style: TextStyle(fontSize: 24))),
          _buildNavItem('Calendar', 'calendar'),
          _buildNavItem('Chat Assistant', 'chat'),
        ],
      ),
    );
  }

  Widget _buildNavItem(String label, String route) {
    return ListTile(
      title: Text(label),
      selected: currentRoute == route,
      onTap: () => onNavigate(route),
    );
  }
}
