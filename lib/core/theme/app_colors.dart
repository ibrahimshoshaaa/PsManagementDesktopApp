import 'package:flutter/material.dart';

/// ألوان التطبيق — منقولة زي ما هي من نسخة Flet (نفس الأكواد اللونية)
/// عشان الشكل يفضل مطابق للنسخة القديمة اللي المستخدمين متعودين عليها.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0B0E14); // page.bgcolor
  static const Color sidebar = Color(0xFF0D1117);
  static const Color sidebarSelected = Color(0xFF1C2128);
  static const Color card = Color(0xFF13181F);
  static const Color card2 = Color(0xFF1C2128);

  static const Color accent = Color(0xFF38BDF8); // لون الحدود/الاختيار في الـ sidebar
  static const Color orange = Color(0xFFF97316); // C_ORG / لون المصروفات
  static const Color amber = Color(0xFFFBBF24);
  static const Color red = Color(0xFFF87171);
  static const Color redDark = Color(0xFFB91C1C);
  static const Color green = Color(0xFF4ADE80);
  static const Color greenDark = Color(0xFF15803D);

  static const Color textWhite60 = Colors.white60;
  static const Color textWhite38 = Colors.white38;
  static const Color divider = Color(0x1FFFFFFF); // white12
}
