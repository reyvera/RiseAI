import 'package:flutter/material.dart';

class TopBar extends StatelessWidget {
  final VoidCallback onLogout;

  const TopBar({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Dashboard",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          ElevatedButton.icon(
            onPressed: onLogout,
            icon: Icon(Icons.logout, size: 18),
            label: Text("Logout"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5562EA),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: TextStyle(fontWeight: FontWeight.w500),
            ),
          )
        ],
      ),
    );
  }
}
