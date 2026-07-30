import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const PlaceholderScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 20, color: Colors.white38)),
          const SizedBox(height: 8),
          const Text('قيد الإنشاء — المرحلة الجاية 🚧', style: TextStyle(color: Colors.white24)),
        ],
      ),
    );
  }
}
